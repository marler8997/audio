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
    const(ubyte[])[] skipPatterns;
}
passfail loadGrandPiano(from!"audio.dag".SamplerMidiInstrument* instrument)
{
    import mar.array : StaticArray, StaticImmutableArray, fixedArrayBuilder, asDynamic;
    import mar.mem : malloc, free;
    import audio.dag : SampleWithSkipPattern, SampleInstrumentData;
    import audio.midi : MidiNote;

    // Can't use an array literal because of -betterC
    auto skipZero = StaticImmutableArray!(ubyte, 0);
    auto skipOne = StaticImmutableArray!(ubyte, 1);
    auto skipA = StaticImmutableArray!(ubyte, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1);
    auto b3SkipPatterns = StaticImmutableArray!(ubyte[],
        null, null, skipA, null);
    auto ranges = fixedArrayBuilder!(SampleRange, 21)
        .put(SampleRange("MF-e1.aif"     , MidiNote.a0, null))
        .put(SampleRange("MF-b1.aif"     , MidiNote.f0, null))
        .put(SampleRange("MF-d2.aif"     , MidiNote.c2, null))
        .put(SampleRange("MF-g2.aif"     , MidiNote.f2, null))
        .put(SampleRange("MF-c3.aif"     , MidiNote.a2, null))
        .put(SampleRange("MF-e3.aif"     , MidiNote.d3, null))
        .put(SampleRange("MF-g3.aif"     , MidiNote.fsharp3, null))
        .put(SampleRange("MF-b3.aif"     , MidiNote.asharp3, b3SkipPatterns.asDynamic))
        /*
        .put(SampleRange("MF-b3.aif"     , MidiNote.asharp3, StaticArray!(ubyte[]
            , null
            , null
            , skipOne
            , null
        )))
        */
        .put(SampleRange("MF-dsharp4.aif", MidiNote.d4, null))
        .put(SampleRange("MF-g4.aif"     , MidiNote.fsharp4, null))
        .put(SampleRange("MF-b4.aif"     , MidiNote.asharp4, null))
        .put(SampleRange("MF-dsharp5.aif", MidiNote.d5, null))
        .put(SampleRange("MF-g5.aif"     , MidiNote.fsharp5, null))
        .put(SampleRange("MF-b5.aif"     , MidiNote.a5, null))
        .put(SampleRange("MF-d6.aif"     , MidiNote.csharp6, null))
        .put(SampleRange("MF-f6.aif"     , MidiNote.e6, null))
        .put(SampleRange("MF-a6.aif"     , MidiNote.gsharp6, null))
        .put(SampleRange("MF-csharp7.aif", MidiNote.c7, null))
        .put(SampleRange("MF-fsharp7.aif", MidiNote.f7, null))
        .put(SampleRange("MF-asharp7.aif", MidiNote.a7, null))
        .put(SampleRange(null            , MidiNote.c8, null))
        .finish;
    auto samples = cast(SampleWithSkipPattern*)malloc(SampleWithSkipPattern.sizeof * (MidiNote.max + 1));
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
        if (range.skipPatterns && range.skipPatterns.length != patternCount)
        {
            logError("range ", range.sampleFile, " has ", range.skipPatterns.length,
                " skip pattern(s) but needs ", patternCount);
            return passfail.fail;
        }
        foreach (noteOffset; 0 .. patternCount)
        {
            samples[range.startNote + noteOffset] = SampleWithSkipPattern(result.val.array,
                range.skipPatterns ? range.skipPatterns[noteOffset] : null);
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
    auto midiInput = MidiInputNode();
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

version = UseMidiInstrument;
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
        static import audio.pckeyboardinstrument;
        audio.pckeyboardinstrument.readNotes!RenderFormat();
    }
    backend.close();

    return 0;
}