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

    audio.global.channelCount = 1;
    //audio.global.channelCount = 2;
    //audio.global.samplesPerSec = 44100;
    audio.global.samplesPerSec = 48000;
    logDebug(audio.global.channelCount, " channels at ", audio.global.samplesPerSec, " Hz");

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
    if(audio.backend.setAudioFormatAndBufferConfig(
        //44100) // bufferSampleCount (about 1000 ms)
        //4410) // bufferSampleCount (about 100 ms)
        2205) // bufferSampleCount (about 50 ms)
        //1664) // bufferSampleCount (about 40 ms)
        //441) // bufferSampleCount (about 10 ms)
    .failed)
        return 1;

    //return go();
    return go2();
}

struct SampleRange
{
    import audio.midi : MidiNote;

    MidiNote startNote;
    MidiNote sampleNote;
    string sampleFile;
}
passfail loadGrandPiano(from!"audio.dag".SamplerMidiInstrument* instrument, const(float)[256] freqTable)
{
    import mar.array : StaticArray, StaticImmutableArray, fixedArrayBuilder, asDynamic;
    import mar.mem : malloc, free;
    import audio.dag : SkewedSample, SampleInstrumentData;
    import audio.midi : MidiNote, stdFreq;

    // Can't use an array literal because of -betterC
    const ranges = fixedArrayBuilder!(SampleRange, 21)
        .put(SampleRange(MidiNote.a0     , MidiNote.e1     , "MF-e1.aif"     ))
        .put(SampleRange(MidiNote.f1     , MidiNote.b1     , "MF-b1.aif"     ))
        .put(SampleRange(MidiNote.c2     , MidiNote.d2     , "MF-d2.aif"     ))
        .put(SampleRange(MidiNote.f2     , MidiNote.g2     , "MF-g2.aif"     ))
        .put(SampleRange(MidiNote.a2     , MidiNote.c3     , "MF-c3.aif"     ))
        .put(SampleRange(MidiNote.d3     , MidiNote.e3     , "MF-e3.aif"     ))
        .put(SampleRange(MidiNote.fsharp3, MidiNote.g3     , "MF-g3.aif"     ))
        .put(SampleRange(MidiNote.asharp3, MidiNote.b3     , "MF-b3.aif"     ))
        .put(SampleRange(MidiNote.d4     , MidiNote.dsharp4, "MF-dsharp4.aif"))
        .put(SampleRange(MidiNote.fsharp4, MidiNote.g4     , "MF-g4.aif"     ))
        .put(SampleRange(MidiNote.asharp4, MidiNote.b4     , "MF-b4.aif"     ))
        .put(SampleRange(MidiNote.d5     , MidiNote.dsharp5, "MF-dsharp5.aif"))
        .put(SampleRange(MidiNote.fsharp5, MidiNote.g5     , "MF-g5.aif"     ))
        .put(SampleRange(MidiNote.a5     , MidiNote.b5     , "MF-b5.aif"     ))
        .put(SampleRange(MidiNote.csharp6, MidiNote.d6     , "MF-d6.aif"     ))
        .put(SampleRange(MidiNote.e6     , MidiNote.f6     , "MF-f6.aif"     ))
        .put(SampleRange(MidiNote.gsharp6, MidiNote.a6     , "MF-a6.aif"     ))
        .put(SampleRange(MidiNote.c7     , MidiNote.csharp7, "MF-csharp7.aif"))
        .put(SampleRange(MidiNote.f7     , MidiNote.fsharp7, "MF-fsharp7.aif"))
        .put(SampleRange(MidiNote.a7     , MidiNote.asharp7, "MF-asharp7.aif"))
        .put(SampleRange(MidiNote.csharp8, MidiNote.none   , null            ))
        .finish;
    auto samples = cast(SkewedSample*)malloc(SkewedSample.sizeof * (MidiNote.max + 1));
    ubyte channelCount = 0;
    for (size_t i = 0;; i++)
    {
        import mar.print : sprintMallocSentinel;
        import audio.format.aiff : loadAiffSample;

        auto range = ranges[i];
        if (!range.sampleFile)
            break;

        auto fullName = sprintMallocSentinel(r"D:\GrandPiano\", range.sampleFile);
        scope (exit) free(fullName.ptr.raw);
        logDebug("loading '", fullName, "'...");
        auto result = loadAiffSample(fullName.ptr);
        if (result.failed)
        {
            logError("failed to load '", fullName, "': ", result);
            return passfail.fail;
        }

        auto rangeLength = ranges[i + 1].startNote - range.startNote;
        foreach (note; range.startNote .. ranges[i + 1].startNote + 1)
        {
            const skew = (note == range.sampleNote && freqTable.ptr == stdFreq.ptr) ? float.nan :
                freqTable[note] / stdFreq[range.sampleNote];
            samples[note] = SkewedSample(result.val.array, skew);
        }

        if (channelCount == 0)
            channelCount = result.val.channelCount;
        else
        {
            if (result.val.channelCount != channelCount)
            {
                logError("channel count mismatch ", channelCount, " != ", result.val.channelCount);
                return passfail.fail;
            }
        }
    }
    instrument.initialize(SampleInstrumentData(samples[0 .. MidiNote.max + 1], 2.0, channelCount));
    return passfail.pass;
}

//version = SinWave;
//version = SawWave;
version = GrandPiano;

version = UseMidiInstrument;
//version = UsePCKeyboard;
int go2()
{
    version (Windows)
        import mar.windows.kernel32 : CreateThread;

    import audio.dag;
    import backend = audio.backend;

    version (UsePCKeyboard)
    {
        auto pcKeyboardInput = from!"audio.pckeyboard".PCKeyboardInputNode();
        pcKeyboardInput.initialize();
    }
    version (UseMidiInstrument)
    {
        auto midiInput = from!"audio.windowsmidi".WindowsMidiInputNode();
        midiInput.initialize();
    }
    version (SinWave)
    {
        auto sinWave = SinOscillatorMidiInstrument!RenderFormat();
        sinWave.initialize(OscillatorInstrumentData(.1));
        version (UsePCKeyboard)
            pcKeyboardInput.tryAddInstrument(sinWave.asBase).enforce();
        version (UseMidiInstrument)
            midiInput.tryAddInstrument(sinWave.asBase).enforce();
    }
    version (SawWave)
    {
        auto sawWave = SawOscillatorMidiInstrument!RenderFormat();
        sawWave.initialize(OscillatorInstrumentData(.1));
        version (UsePCKeyboard)
            pcKeyboardInput.tryAddInstrument(sawWave.asBase).enforce();
        version (UseMidiInstrument)
            midiInput.tryAddInstrument(sawWave.asBase).enforce();
    }
    version (GrandPiano)
    {
        SamplerMidiInstrument grandPiano;
        if (loadGrandPiano(&grandPiano, from!"audio.midi".stdFreq).failed)
            return 1; // fail
        //if (loadGrandPiano(&grandPiano, from!"audio.midi".justC4Freq).failed)
        //    return 1; // fail
        version (UsePCKeyboard)
            pcKeyboardInput.tryAddInstrument(grandPiano.asBase).enforce();
        version (UseMidiInstrument)
            midiInput.tryAddInstrument(grandPiano.asBase).enforce();
    }

    version (UsePCKeyboard)
    {
        pcKeyboardInput.startMidiDeviceInput().enforce();
        addRootRenderNode(pcKeyboardInput.asBase);
    }
    version (UseMidiInstrument)
    {
        midiInput.startMidiDeviceInput(0).enforce(); // just hardcode MIDI device 0 for now
        addRootRenderNode(midiInput.asBase);
    }

    backend.open();
    import audio.render : renderThread;
    version (Windows)
    {
        auto audioWriteThread = CreateThread(null,
            0,
            &renderThread,
            null,
            0,
            null);
        if (audioWriteThread.isNull)
        {
            import mar.windows.kernel32 : GetLastError;
            logError("CreateThread failed, e=", GetLastError());
            return 1;
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

ubyte go()
{
    version (Windows)
    {
        import mar.windows.kernel32 : CreateThread;
        import mar.windows.winmm : MuitlmediaOpenFlags, WAVE_MAPPER;
    }

    import backend = audio.backend;
    import audio.backend;

    /*
    {
        import mar.windows.types : ThreadPriority;
        import mar.windows.kernel32 : GetCurrentThread, GetThreadPriority, SetThreadPriority;
        const thread = GetCurrentThread();
        const priority = GetThreadPriority(thread);
        logDebug("ThreadPriority=", priority);
        if (priority < ThreadPriority.timeCritical)
        {
            logDebug("Setting thread priority to ", ThreadPriority.timeCritical);
            if (SetThreadPriority(thread, ThreadPriority.timeCritical).failed)
            {
                logError("Failed to set thread priority, e=", GetLastError());
                return 1; // fail
            }
        }
    }
    */


    /*
    dumpWaveFormat(&global.waveFormat);
    logDebug("WAVE_MAPPER=", WAVE_MAPPER);
    logDebug("WaveoutOpenFlags.callbackFunction=", WaveoutOpenFlags.callbackFunction);
    */
    backend.open();
    import audio.render : renderThread;
    version (Windows)
    {
        auto audioWriteThread = CreateThread(null,
            0,
            &renderThread,
            null,
            0,
            null);
    }

    version(UseMidiInstrument)
    {
        version (Windows)
        {
            static import audio.windowsmidiinstrument;
            audio.windowsmidiinstrument.readNotes!RenderFormat(0);
        }
        else
        {
            logError("midi not implemented on this platform");
        }
    }
    else
    {
        /*
        BROKEN:
            audio.obj : error LNK2019: unresolved external symbol __memsetn referenced in function audio.pckeyboardinstrument.readNotes!(audio.format.FloatFormat).readNotes()
        static import audio.pckeyboardinstrument;
        audio.pckeyboardinstrument.readNotes!RenderFormat();
        */
    }
    backend.close();

    return 0;
}