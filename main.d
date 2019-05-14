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

void waitForEnterKey()
{
    import mar.stdio;
    char[8] buffer;
    auto result = stdin.read(buffer);
}

struct SampleRange
{
    import audio.midi : MidiNote;

    string sampleFile;
    MidiNote startNote;
    const(float)[] skews;
    //const(ubyte[])[] skipPatterns;
}
passfail loadGrandPiano(from!"audio.dag".SamplerMidiInstrument* instrument)
{
    import mar.array : StaticArray, StaticImmutableArray, fixedArrayBuilder, asDynamic;
    import mar.mem : malloc, free;
    import audio.dag : SkewedSample, SampleInstrumentData;
    import audio.midi : MidiNote, stdFreq;

    // Can't use an array literal because of -betterC
    auto ranges = fixedArrayBuilder!(SampleRange, 21)
        .put(SampleRange("MF-e1.aif"     , MidiNote.a0, StaticImmutableArray!(float,
            stdFreq[MidiNote.a0] / stdFreq[MidiNote.e1],
            stdFreq[MidiNote.asharp0] / stdFreq[MidiNote.e1],
            stdFreq[MidiNote.b0] / stdFreq[MidiNote.e1],
            stdFreq[MidiNote.c1] / stdFreq[MidiNote.e1],
            stdFreq[MidiNote.csharp1] / stdFreq[MidiNote.e1],
            stdFreq[MidiNote.d1] / stdFreq[MidiNote.e1],
            stdFreq[MidiNote.dsharp1] / stdFreq[MidiNote.e1],
            float.nan,
        )))
        .put(SampleRange("MF-b1.aif"     , MidiNote.f1, StaticImmutableArray!(float,
            stdFreq[MidiNote.f1] / stdFreq[MidiNote.b1],
            stdFreq[MidiNote.fsharp1] / stdFreq[MidiNote.b1],
            stdFreq[MidiNote.g1] / stdFreq[MidiNote.b1],
            stdFreq[MidiNote.gsharp1] / stdFreq[MidiNote.b1],
            stdFreq[MidiNote.a1] / stdFreq[MidiNote.b1],
            stdFreq[MidiNote.asharp1] / stdFreq[MidiNote.b1],
            float.nan,
        )))
        .put(SampleRange("MF-d2.aif"     , MidiNote.c2, StaticImmutableArray!(float,
            stdFreq[MidiNote.c2] / stdFreq[MidiNote.d2],
            stdFreq[MidiNote.csharp2] / stdFreq[MidiNote.d2],
            float.nan,
            stdFreq[MidiNote.dsharp2] / stdFreq[MidiNote.d2],
            stdFreq[MidiNote.e2] / stdFreq[MidiNote.d2],
        )))
        .put(SampleRange("MF-g2.aif"     , MidiNote.f2, StaticImmutableArray!(float,
            stdFreq[MidiNote.f2] / stdFreq[MidiNote.g2],
            stdFreq[MidiNote.fsharp2] / stdFreq[MidiNote.g2],
            float.nan,
            stdFreq[MidiNote.gsharp2] / stdFreq[MidiNote.g2],
        )))
        .put(SampleRange("MF-c3.aif"     , MidiNote.a2, StaticImmutableArray!(float,
            stdFreq[MidiNote.a2] / stdFreq[MidiNote.c3],
            stdFreq[MidiNote.asharp2] / stdFreq[MidiNote.c3],
            stdFreq[MidiNote.b2] / stdFreq[MidiNote.c3],
            float.nan,
            stdFreq[MidiNote.csharp3] / stdFreq[MidiNote.c3],
        )))
        .put(SampleRange("MF-e3.aif"     , MidiNote.d3, StaticImmutableArray!(float,
            stdFreq[MidiNote.d3] / stdFreq[MidiNote.e3],
            stdFreq[MidiNote.dsharp3] / stdFreq[MidiNote.e3],
            float.nan,
            stdFreq[MidiNote.f3] / stdFreq[MidiNote.e3],
        )))
        .put(SampleRange("MF-g3.aif"     , MidiNote.fsharp3, StaticImmutableArray!(float,
            stdFreq[MidiNote.fsharp3] / stdFreq[MidiNote.g3],
            float.nan,
            stdFreq[MidiNote.gsharp3] / stdFreq[MidiNote.g3],
            stdFreq[MidiNote.a3] / stdFreq[MidiNote.g3],
        )))
        .put(SampleRange("MF-b3.aif"     , MidiNote.asharp3, StaticImmutableArray!(float,
            stdFreq[MidiNote.asharp3] / stdFreq[MidiNote.b3],
            float.nan,
            stdFreq[MidiNote.c4] / stdFreq[MidiNote.b3],
            stdFreq[MidiNote.csharp4] / stdFreq[MidiNote.b3],
        )))
        .put(SampleRange("MF-dsharp4.aif", MidiNote.d4, StaticImmutableArray!(float,
            stdFreq[MidiNote.d4] / stdFreq[MidiNote.dsharp4],
            float.nan,
            stdFreq[MidiNote.e4] / stdFreq[MidiNote.dsharp4],
            stdFreq[MidiNote.f4] / stdFreq[MidiNote.dsharp4],
        )))
        .put(SampleRange("MF-g4.aif"     , MidiNote.fsharp4, StaticImmutableArray!(float,
            stdFreq[MidiNote.fsharp4] / stdFreq[MidiNote.g4],
            float.nan,
            stdFreq[MidiNote.gsharp4] / stdFreq[MidiNote.g4],
            stdFreq[MidiNote.a4] / stdFreq[MidiNote.g4],
        )))
        .put(SampleRange("MF-b4.aif"     , MidiNote.asharp4, StaticImmutableArray!(float,
            stdFreq[MidiNote.asharp4] / stdFreq[MidiNote.b4],
            float.nan,
            stdFreq[MidiNote.c5] / stdFreq[MidiNote.b4],
            stdFreq[MidiNote.csharp5] / stdFreq[MidiNote.b4],
        )))
        .put(SampleRange("MF-dsharp5.aif", MidiNote.d5, StaticImmutableArray!(float,
            stdFreq[MidiNote.d5] / stdFreq[MidiNote.dsharp5],
            float.nan,
            stdFreq[MidiNote.e5] / stdFreq[MidiNote.dsharp5],
            stdFreq[MidiNote.f5] / stdFreq[MidiNote.dsharp5],
        )))
        .put(SampleRange("MF-g5.aif"     , MidiNote.fsharp5, StaticImmutableArray!(float,
            stdFreq[MidiNote.fsharp5] / stdFreq[MidiNote.g5],
            float.nan,
            stdFreq[MidiNote.gsharp5] / stdFreq[MidiNote.g5],
        )))
        .put(SampleRange("MF-b5.aif"     , MidiNote.a5, StaticImmutableArray!(float,
            stdFreq[MidiNote.a5] / stdFreq[MidiNote.b5],
            stdFreq[MidiNote.asharp5] / stdFreq[MidiNote.b5],
            float.nan,
            stdFreq[MidiNote.c6] / stdFreq[MidiNote.b5],
        )))
        .put(SampleRange("MF-d6.aif"     , MidiNote.csharp6, StaticImmutableArray!(float,
            stdFreq[MidiNote.csharp6] / stdFreq[MidiNote.d6],
            float.nan,
            stdFreq[MidiNote.dsharp6] / stdFreq[MidiNote.d6],
        )))
        .put(SampleRange("MF-f6.aif"     , MidiNote.e6, StaticImmutableArray!(float,
            stdFreq[MidiNote.e6] / stdFreq[MidiNote.f6],
            float.nan,
            stdFreq[MidiNote.fsharp6] / stdFreq[MidiNote.f6],
            stdFreq[MidiNote.g6] / stdFreq[MidiNote.f6],
        )))
        .put(SampleRange("MF-a6.aif"     , MidiNote.gsharp6, StaticImmutableArray!(float,
            stdFreq[MidiNote.gsharp6] / stdFreq[MidiNote.a6],
            float.nan,
            stdFreq[MidiNote.asharp6] / stdFreq[MidiNote.a6],
            stdFreq[MidiNote.b6] / stdFreq[MidiNote.a6],
        )))
        .put(SampleRange("MF-csharp7.aif", MidiNote.c7, StaticImmutableArray!(float,
            stdFreq[MidiNote.c7] / stdFreq[MidiNote.csharp7],
            float.nan,
            stdFreq[MidiNote.d7] / stdFreq[MidiNote.csharp7],
            stdFreq[MidiNote.dsharp7] / stdFreq[MidiNote.csharp7],
            stdFreq[MidiNote.e7] / stdFreq[MidiNote.csharp7],
        )))
        .put(SampleRange("MF-fsharp7.aif", MidiNote.f7, StaticImmutableArray!(float,
            stdFreq[MidiNote.f7] / stdFreq[MidiNote.fsharp7],
            float.nan,
            stdFreq[MidiNote.g7] / stdFreq[MidiNote.fsharp7],
            stdFreq[MidiNote.gsharp7] / stdFreq[MidiNote.fsharp7],
        )))
        .put(SampleRange("MF-asharp7.aif", MidiNote.a7, StaticImmutableArray!(float,
            stdFreq[MidiNote.a7] / stdFreq[MidiNote.asharp7],
            float.nan,
            stdFreq[MidiNote.b7] / stdFreq[MidiNote.asharp7],
            stdFreq[MidiNote.c8] / stdFreq[MidiNote.asharp7],
        )))
        .put(SampleRange(null            , MidiNote.csharp8, null))
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

        auto patternCount = ranges[i + 1].startNote - range.startNote;
        if (range.skews.length != patternCount)
        {
            logError("range ", range.sampleFile, " has ", range.skews.length,
                " skew elements but needs ", patternCount);
            return passfail.fail;
        }
        foreach (noteOffset; 0 .. patternCount)
        {
            samples[range.startNote + noteOffset] = SkewedSample(result.val.array, range.skews[noteOffset]);
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
int go2()
{
    version (Windows)
        import mar.windows.kernel32 : CreateThread;

    import audio.dag;
    import backend = audio.backend;


    //auto midiInstrument = SinMidiInstrument!RenderFormat();
    //auto midiInstrument = SinOscillatorMidiInstrument!RenderFormat();
    //midiInstrument.initialize();
    auto midiInput = from!"audio.windowsmidi".WindowsMidiInputNode();
    midiInput.initialize();
    version (SinWave)
    {
        auto sinWave = SinOscillatorMidiInstrument!RenderFormat();
        sinWave.initialize(OscillatorInstrumentData(.1));
        midiInput.tryAddInstrument(sinWave.asBase).enforce();
    }
    version (SawWave)
    {
        auto sawWave = SawOscillatorMidiInstrument!RenderFormat();
        sawWave.initialize(OscillatorInstrumentData(.1));
        midiInput.tryAddInstrument(sawWave.asBase).enforce();
    }
    version (GrandPiano)
    {
        SamplerMidiInstrument grandPiano;
        if (loadGrandPiano(&grandPiano).failed)
            return 1; // fail
        midiInput.tryAddInstrument(grandPiano.asBase).enforce();
    }

    midiInput.startMidiDeviceInput(0); // just hardcode device 0 for now
    addRootRenderNode(midiInput.asBase);

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

    log("Press enter to stop");
    flushLog();
    waitForEnterKey();

    backend.close();
    midiInput.stopMidiDeviceInput();
    return 0;
}

//version = UseMidiInstrument;
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