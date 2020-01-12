module _none;

import mar.from;
import mar.passfail;

import audio.log;
static import audio.global;
static import audio.backend;
import audio.renderformat;
import audio.render;

void setupGlobalDefaults()
{
    //audio.global.channelCount = 1;
    audio.global.channelCount = 2;
    //audio.global.sampleFramesPerSec = 44100;
    audio.global.sampleFramesPerSec = 48000;
    logDebug("default set to ", audio.global.channelCount, " channels at ", audio.global.sampleFramesPerSec, " Hz");

    audio.global.bufferSampleFrameCount = 0; // set to 0 to mean it's not set yet

    version (Windows)
    {
        //audio.global.backend = audio.backend.AudioBackend.waveout;
        audio.global.backend = audio.backend.AudioBackend.wasapi;
    }
}
// After backend has been setup, finishing setting globals if backend did not set them
void finishGlobals()
{
    if (audio.global.bufferSampleFrameCount != 0)
    {
        log("audio backend set a buffer size for us to ", audio.global.bufferSampleFrameCount);
        return;
    }
    log("audio backend did not set a buffer size");
    //const inputDelayMillis = 2;
    //const inputDelayMillis = 9;
    //const inputDelayMillis = 10;
    //const inputDelayMillis = 20;
    //const inputDelayMillis = 30;
    const inputDelayMillis = 50;
    //const inputDelayMillis = 100;
    audio.global.bufferSampleFrameCount = audio.global.sampleFramesPerSec * inputDelayMillis / 1000;
    log("bufferSampleFrameCount=", audio.global.bufferSampleFrameCount, " inputDelay=", inputDelayMillis, " ms");
}

extern (C) int main(string[] args)
{
    //{import audio.midi : unittest1; unittest1(); }

    // This should always be done first thing
    from!"audio.timer".timerInit().enforce();
    renderPlatformInit().enforce();
    from!"audio.pckeyboard".pckeyboardInit().enforce();

    setupGlobalDefaults();
    // Now setup the backend, it may change some global settings
    audio.backend.setup().enforce("failed to setup the audio backend");
    finishGlobals();

    return go();
}

version = UseMidiInstrument;
version = UsePCKeyboard;
//version = PCKeyboardStartWithC4;

//version = SinWave;
//version = SawWave;
version = GrandPiano;

//version = ValhallaReverb;

int go()
{
    import mar.arraybuilder;
    import audio.dag;

    // Load project file
    {
        //import mar.json;

    }

    ArrayBuilder!MidiAudioGenerator instruments;
    version (SinWave)
    {
        MidiAudioGenerator sinWave = createMidiAudioGenerator!SinOscillatorMidiInstrument();
        sinWave.initialize(OscillatorInstrumentData(.4));
        instruments.tryPut(sinWave.asBase).enforce();
    }
    version (SawWave)
    {
        MidiAudioGenerator sawWave = createMidiAudioGenerator!SawOscillatorMidiInstrument();
        sawWave.initialize(OscillatorInstrumentData(.1));
        instruments.tryPut(sawWave.asBase).enforce();
    }
    version (GrandPiano)
    {
        MidiAudioGenerator grandPiano;
        if (loadGrandPiano(&grandPiano, 3.0).failed)
            return 1; // fail
        instruments.tryPut(grandPiano.asBase).enforce();
    }

    version (ValhallaReverb)
    {
        auto valhallaEffect = tryLoadValhalla();
        if (valhallaEffect is null)
        {
            logError("failed to load valhalla plugin");
            return 1; // fail
        }
        auto valhallaEffectNode = from!"audio.vstnodes".VstEffect();
        valhallaEffectNode.initialize(valhallaEffect);
        foreach (instrument; instruments.data)
        {
            valhallaEffectNode.inputs.tryPut(instrument.asBase).enforce();
        }
        addRootAudioGenerator(valhallaEffectNode.asBase).enforce();
    }
    else
    {
        foreach (instrument; instruments.data)
        {
            addRootAudioGenerator(instrument.asBase).enforce();
        }
    }

    version (UsePCKeyboard)
    {
        auto pcKeyboardInput = from!"audio.pckeyboard".PCKeyboardInputNode();
        pcKeyboardInput.initialize();
        foreach (i; 0 .. instruments.length)
        {
            instruments[i].tryAddInputNode(pcKeyboardInput.asBase)
                .enforce("failed to add pc keyboard midi input mode");
        }
        pcKeyboardInput.startMidiDeviceInput().enforce();
        version (PCKeyboardStartWithC4)
        {
            import audio.midi : MidiEvent, MidiNote;
            const addEventResult = pcKeyboardInput.tryAddMidiEvent(MidiEvent.makeNoteOn(0, MidiNote.c4, 67));
            if (addEventResult.failed)
            {
                logError("failed to add MIDI ON event: ", addEventResult);
                return 1; // fail
            }
        }
    }
    version (UseMidiInstrument)
    {
        auto midiInput = from!"audio.windowsmidi".WindowsMidiGenerator();
        midiInput.initialize();
        foreach (i; 0 .. instruments.length)
        {
            instruments[i].tryAddInputNode(midiInput.asBase)
                .enforce("failed to add midi device input node");
        }
        midiInput.startMidiDeviceInput(0).enforce(); // just hardcode MIDI device 0 for now
    }

    {
        import mar.thread;
        import audio.render : renderThread;
        const result = startThread(&renderThread);
        if (result.failed)
        {
            logError("failed to start audio thread: ", result);
            return 1; // fail
        }
    }

    {
        import audio.pckeyboard : startInputThread, joinInputThread;
        startInputThread();
        //log("Press ESC or Enter to quit");
        log("Press ESC to quit");
        flushLog();
        joinInputThread();
    }

    version (UseMidiInstrument)
        midiInput.stopMidiDeviceInput();
    return 0;
}

struct SampleRange
{
    import audio.midi : MidiNote;

    MidiNote startNote;
    MidiNote sampleNote;
    string softSampleFilename;
    string mediumSampleFilename;
}

version = UseMPSamples;
passfail loadGrandPiano(from!"audio.dag".SamplerMidiInstrument* instrument, float volumeScale)
{
    import mar.enforce : enforce;
    import mar.array : zero, StaticArray, StaticImmutableArray, fixedArrayBuilder, tryMallocArray;
    import mar.mem : malloc, free;
    import audio.dag : MidiControlledSample, SamplerInstrumentData;
    import audio.midi : MidiNote, defaultFreq, stdFreq;

    // Can't use an array literal because of -betterC
    const ranges = fixedArrayBuilder!(SampleRange, 21)
        .put(SampleRange(MidiNote.a0     , MidiNote.e1     , "MP-e1.aif"     , "MF-e1.aif"     ))
        .put(SampleRange(MidiNote.f1     , MidiNote.b1     , "MP-b1.aif"     , "MF-b1.aif"     ))
        .put(SampleRange(MidiNote.c2     , MidiNote.d2     , "MP-d2.aif"     , "MF-d2.aif"     ))
        .put(SampleRange(MidiNote.f2     , MidiNote.g2     , "MP-g2.aif"     , "MF-g2.aif"     ))
        .put(SampleRange(MidiNote.a2     , MidiNote.c3     , "MP-c3.aif"     , "MF-c3.aif"     ))
        .put(SampleRange(MidiNote.d3     , MidiNote.e3     , "MP-e3.aif"     , "MF-e3.aif"     ))
        .put(SampleRange(MidiNote.fsharp3, MidiNote.g3     , "MP-g3.aif"     , "MF-g3.aif"     ))
        .put(SampleRange(MidiNote.asharp3, MidiNote.b3     , "MP-b3.aif"     , "MF-b3.aif"     ))
        .put(SampleRange(MidiNote.d4     , MidiNote.dsharp4, "MP-dsharp4.aif", "MF-dsharp4.aif"))
        .put(SampleRange(MidiNote.fsharp4, MidiNote.g4     , "MP-g4.aif"     , "MF-g4.aif"     ))
        .put(SampleRange(MidiNote.asharp4, MidiNote.b4     , "MP-b4.aif"     , "MF-b4.aif"     ))
        .put(SampleRange(MidiNote.d5     , MidiNote.dsharp5, "MP-dsharp5.aif", "MF-dsharp5.aif"))
        .put(SampleRange(MidiNote.fsharp5, MidiNote.g5     , "MP-g5.aif"     , "MF-g5.aif"     ))
        .put(SampleRange(MidiNote.a5     , MidiNote.b5     , "MP-b5.aif"     , "MF-b5.aif"     ))
        .put(SampleRange(MidiNote.csharp6, MidiNote.d6     , "MP-d6.aif"     , "MF-d6.aif"     ))
        .put(SampleRange(MidiNote.e6     , MidiNote.f6     , "MP-f6.aif"     , "MF-f6.aif"     ))
        .put(SampleRange(MidiNote.gsharp6, MidiNote.a6     , "MP-a6.aif"     , "MF-a6.aif"     ))
        .put(SampleRange(MidiNote.c7     , MidiNote.csharp7, "MP-csharp7.aif", "MF-csharp7.aif"))
        .put(SampleRange(MidiNote.f7     , MidiNote.fsharp7, "MP-fsharp7.aif", "MF-fsharp7.aif"))
        .put(SampleRange(MidiNote.a7     , MidiNote.asharp7, "MP-asharp7.aif", "MF-asharp7.aif"))
        .put(SampleRange(MidiNote.csharp8, MidiNote.none   , null            , null            ))
        .finish;

    auto samplesByNote = tryMallocArray!(MidiControlledSample[])(MidiNote.max + 1).enforce;
    zero(samplesByNote);
    ubyte sharedChannelCount = 0;
    passfail checkNewChannelCount(ubyte newChannelCount)
    {
        if (sharedChannelCount == 0)
            sharedChannelCount = newChannelCount;
        else
        {
            if (newChannelCount != sharedChannelCount)
            {
                logError("channel count mismatch ", newChannelCount, " != ", sharedChannelCount);
                return passfail.fail;
            }
        }
        return passfail.pass;
    }
    for (size_t i = 0;; i++)
    {
        import mar.print : sprintMallocSentinel;
        import audio.fileformat.aiff : loadAiffSample;

        auto range = ranges[i];
        if (range.sampleNote == MidiNote.none)
            break;

        version (UseMPSamples)
        {
            auto softSampleFilename = sprintMallocSentinel(r"D:\GrandPiano\", range.softSampleFilename);
            scope (exit) free(softSampleFilename.ptr.raw);
            logDebug("loading '", softSampleFilename, "'...");
            auto softSampleResult = loadAiffSample(softSampleFilename.ptr);
            if (softSampleResult.failed)
            {
                logError("failed to load '", softSampleFilename, "': ", softSampleResult);
                return passfail.fail;
            }
            checkNewChannelCount(softSampleResult.val.channelCount).enforce;
        }
        auto mediumSampleFilename = sprintMallocSentinel(r"D:\GrandPiano\", range.mediumSampleFilename);
        scope (exit) free(mediumSampleFilename.ptr.raw);
        logDebug("loading '", mediumSampleFilename, "'...");
        auto mediumSampleResult = loadAiffSample(mediumSampleFilename.ptr);
        if (mediumSampleResult.failed)
        {
            logError("failed to load '", mediumSampleFilename, "': ", mediumSampleResult);
            return passfail.fail;
        }
        checkNewChannelCount(mediumSampleResult.val.channelCount).enforce;

        auto rangeLength = ranges[i + 1].startNote - range.startNote;
        foreach (note; range.startNote .. ranges[i + 1].startNote + 1)
        {
            const skew = (note == range.sampleNote && defaultFreq.ptr == stdFreq.ptr) ? float.nan :
                defaultFreq[note] / stdFreq[range.sampleNote];
            version (UseMPSamples)
            {
                auto velocitySortedSamples = tryMallocArray!MidiControlledSample(2).enforce;
                velocitySortedSamples[0] = MidiControlledSample(softSampleResult.val.points, skew, 72);
                velocitySortedSamples[1] = MidiControlledSample(mediumSampleResult.val.points, skew, 0);
            }
            else
            {
                auto velocitySortedSamples = tryMallocArray!MidiControlledSample(1).enforce;
                velocitySortedSamples[0] = MidiControlledSample(mediumSampleResult.val.points, skew, 0);
            }
            samplesByNote[note] = velocitySortedSamples;
        }
    }
    if (sharedChannelCount > audio.global.channelCount)
    {
        logError("the GrandPiano samples have ", sharedChannelCount,
            " channels but the output only has ", audio.global.channelCount);
        return passfail.fail;
    }
    instrument.initialize(SamplerInstrumentData(samplesByNote, volumeScale, sharedChannelCount));
    return passfail.pass;
}

auto tryLoadValhalla()
{
    import mar.sentinel : lit;
    import audio.vst : AudioOpcode, AEffect, loadPlugin, kEffectMagic, eff, effCanDo;

    static extern (C) uint vstHostCallback(AEffect *effect,
        AudioOpcode opcode, uint index, uint value, void *ptr, float opt)
    {
        import audio.vst;
        //logDebug("vstHostCallback opcode=", opcode, " index=", index ," value=", value,);
        if (opcode == AudioOpcode.MasterVersion)
        {
            logDebug("vstHostCallback MasterVersion");
            return 2400;
        }
        logDebug("vstHostCallback unknown opcode ", opcode, " (index=", index, ", value=", value, ")");
        return 0;
    }

    auto aeffect = loadPlugin(lit!"D:\\vst\\ValhallaVintageVerb.dll".ptr, &vstHostCallback);
    logDebug("loadPlugin returned ", cast(void*)aeffect);

    if (aeffect is null)
    {
        logError("loadPlugin failed");
        // TODO: any cleanup?
        return null;
    }

    if (aeffect.magic != kEffectMagic)
    {
        logError("expected vst plugin magic ", kEffectMagic, " but got ", aeffect.magic);
        // TODO: any cleanup?
        return null;
    }

    logDebug("VST: setting sample rate to ", audio.global.sampleFramesPerSec);
    aeffect.dispatcher(aeffect, eff.setSampleRate, 0, 0, null, audio.global.sampleFramesPerSec);
    logDebug("VST: setting block size to ", audio.global.bufferSampleFrameCount);
    aeffect.dispatcher(aeffect, eff.setBlockSize, 0, audio.global.bufferSampleFrameCount, null, 0);

    {
        char[300] canDo;
        const result = aeffect.dispatcher(aeffect, effCanDo, 0, 0, canDo.ptr, 0);
        logDebug("VST: canDo='", canDo[0 .. result], "'");
    }

    return aeffect;
}