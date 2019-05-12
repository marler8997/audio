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

    audio.global.channelCount = 2;
    //audio.global.samplesPerSec = 44100;
    audio.global.samplesPerSec = 48000;

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


passfail loadGrandPiano(from!"audio.dag".SamplerMidiInstrument* instrument)
{
    import mar.mem : malloc, free;
    import audio.midi : MidiNote;

    immutable string[20] sampleFiles = [
        "MF-e1.aif",
        "MF-b1.aif",
        "MF-d2.aif",
        "MF-g2.aif",
        "MF-c3.aif",
        "MF-e3.aif",
        "MF-g3.aif",
        "MF-b3.aif",
        "MF-dsharp4.aif",
        "MF-g4.aif",
        "MF-b4.aif",
        "MF-dsharp5.aif",
        "MF-g5.aif",
        "MF-b5.aif",
        "MF-d6.aif",
        "MF-f6.aif",
        "MF-a6.aif",
        "MF-csharp7.aif",
        "MF-fsharp7.aif",
        "MF-asharp7.aif",
    ];
    auto samples = cast(RenderFormat.SampleType[]*)malloc((RenderFormat.SampleType[]).sizeof * (MidiNote.max + 1));
    foreach (i, sampleBasename; sampleFiles)
    {
        import mar.print : sprintMallocSentinel;
        import audio.format.aiff : loadAiffSample;

        auto fullName = sprintMallocSentinel(r"D:\GrandPiano\", sampleBasename);
        scope (exit) free(fullName.ptr.raw);
        logDebug("loading '", fullName, "'...");
        auto result = loadAiffSample(fullName.ptr);
        if (result.failed)
        {
            logError("failed to load '", fullName, "': ", result);
            return passfail.fail;
        }
        //samples[i] =
    }
    log("loadGrandPiano not implemented");
    return passfail.fail;
}

//version = GrandPiano;
int go2()
{
    version (Windows)
        import mar.windows.kernel32 : CreateThread;

    import audio.dag;
    import backend = audio.backend;


    //auto midiInstrument = SinMidiInstrument!RenderFormat();
    //auto midiInstrument = SinOscillatorMidiInstrument!RenderFormat();
    auto midiInstrument = SawOscillatorMidiInstrument!RenderFormat();
    midiInstrument.init();
    auto midiInput = MidiInputNode();
    midiInput.init();
    midiInput.tryAddInstrument(midiInstrument.asBase).enforce();

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