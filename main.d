module _none;

import mar.from;
import mar.passfail;

import audio.log;
static import audio.global;
import audio.renderformat;
import audio.render;
import audio.backend : AudioFormat;
static import audio.backend;

extern (C) int main(string[] args)
{
    //{import audio.midi : unittest1; unittest1(); }

    // This should always be done first thing
    if(renderPlatformInit().failed)
        return 1;
    if(audio.backend.platformInit().failed)
        return 1;
    if(from!"audio.pckeyboard".pckeyboardInit().failed)
        return 1;

    //audio.global.channelCount = 1;
    audio.global.channelCount = 2;
    //audio.global.sampleFramesPerSec = 44100;
    audio.global.sampleFramesPerSec = 48000;
    logDebug(audio.global.channelCount, " channels at ", audio.global.sampleFramesPerSec, " Hz");

    {
        import mar.sentinel : lit;
        import audio.vst : AudioOpcode, AEffect, loadPlugin;

        static extern (C) uint vstHostCallback(AEffect *effect,
            AudioOpcode opcode, uint index, uint value, void *ptr, float opt)
        {
            import audio.vst;
            logDebug("vstHostCallback opcode=", opcode, " index=", index ," value=", value,);
            if (opcode == AudioOpcode.MasterVersion)
                return 2400;
            return 0;
        }

        auto aeffect = loadPlugin(lit!"D:\\vst\\ValhallaVintageVerb.dll".ptr, &vstHostCallback);
        logDebug("loadPlugin returned ", cast(void*)aeffect);
    }

    //
    // Note: waveOut function will probably not be able to
    //       keep up with a buffer size less then 23 ms (around 1024 samples @ 44100HZ).
    //       This is a limitation on waveOut API (which is pretty high level).
    //       To get better latency, I'll need to use CoreAudio.
    //
    //const inputDelayMillis = 10;
    //const inputDelayMillis = 20;
    const inputDelayMillis = 30;
    //const inputDelayMillis = 100;
    const bufferSampleFrameSize = audio.global.sampleFramesPerSec * inputDelayMillis / 1000;
    log("bufferSampleFrameSize=", bufferSampleFrameSize, " inputDelay=", inputDelayMillis, " ms");
    if(audio.backend.setAudioFormatAndBufferConfig(bufferSampleFrameSize).failed)
    {
        // error already logged
        return 1;
    }

    return go();
}

//version = SinWave;
//version = SawWave;
version = GrandPiano;

version = UseMidiInstrument;
version = UsePCKeyboard;
int go()
{
    import mar.arraybuilder;
    import audio.dag;
    import backend = audio.backend;

    ArrayBuilder!(MidiInstrument!void*) instruments;
    version (SinWave)
    {
        auto sinWave = SinOscillatorMidiInstrument();
        sinWave.initialize(OscillatorInstrumentData(.4));
        addRootAudioGenerator(sinWave.asBase.asBase).enforce();
        instruments.tryPut(sinWave.asBase).enforce();
    }
    version (SawWave)
    {
        auto sawWave = SawOscillatorMidiInstrument();
        sawWave.initialize(OscillatorInstrumentData(.1));
        addRootAudioGenerator(sawWave.asBase.asBase).enforce();
        instruments.tryPut(sawWave.asBase).enforce();
    }
    version (GrandPiano)
    {
        SamplerMidiInstrument grandPiano;
        if (loadGrandPiano(&grandPiano, 3.0).failed)
            return 1; // fail
        addRootAudioGenerator(grandPiano.asBase.asBase).enforce();
        instruments.tryPut(grandPiano.asBase).enforce();
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
    }
    version (UseMidiInstrument)
    {
        auto midiInput = from!"audio.windowsmidi".WindowsMidiInputNode();
        midiInput.initialize();
        foreach (i; 0 .. instruments.length)
        {
            instruments[i].tryAddInputNode(midiInput.asBase)
                .enforce("failed to add midi device input node");
        }
        midiInput.startMidiDeviceInput(0).enforce(); // just hardcode MIDI device 0 for now
    }

    backend.open();

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

    backend.close();
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
