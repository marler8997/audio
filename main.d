module _none;

import audio.log;
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
    import audio.format : CurrentFormat, Pcm16Format, FloatFormat;
    static if (is(CurrentFormat == Pcm16Format))
    {
        if(audio.backend.setAudioFormatAndBufferConfig(AudioFormat.pcm,
            44100, // samplesPerSecond
            //48000, // samplesPerSecond
            16,    // channelSampleBitLength
            2,     // channelCount
            //44100)) // bufferSampleCount (about 1000 ms)
            //4410)) // bufferSampleCount (about 100 ms)
            2205)) // bufferSampleCount (about 50 ms)
            //1664)) // bufferSampleCount (about 40 ms)
            //441)) // bufferSampleCount (about 10 ms)
            return 1;
    }
    else static if (is(CurrentFormat == FloatFormat))
    {
        if(audio.backend.setAudioFormatAndBufferConfig(AudioFormat.float_,
            48000, // samplesPerSecond
            32,    // channelSampleBitLength
            2,     // channelCount
            //4410); // bufferSampleCount (about 100 ms)
            2205)) // bufferSampleCount (about 50 ms)
            //1664); // bufferSampleCount (about 40 ms)
            //441); // bufferSampleCount (about 10 ms)
            return 1;
    }


    //return go();
    return go2();
}

void waitForEnterKey()
{
    import mar.stdio;
    char[8] buffer;
    auto result = stdin.read(buffer);
}

int go2()
{
    version (Windows)
        import mar.windows.kernel32 : CreateThread;

    import audio.format : CurrentFormat;
    import audio.dag;
    import backend = audio.backend;

    //auto midiInstrument = SinMidiInstrument!CurrentFormat();
    //auto midiInstrument = MidiInstrumentTypeA!(SinOscillatorMidiInstrumentTypeA!CurrentFormat)();
    auto midiInstrument = MidiInstrumentTypeA!(SawOscillatorMidiInstrumentTypeA!CurrentFormat)();
    midiInstrument.init();
    auto midiInput = MidiInputNode();
    midiInput.init();
    midiInput.tryAddInstrument(midiInstrument.asBase).enforce();
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

    import audio.format : CurrentFormat;
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
            audio.windowsmidiinstrument.readNotes!CurrentFormat(0);
        }
        else
        {
            logError("midi not implemented on this platform");
        }
    }
    else
    {
        static import audio.pckeyboardinstrument;
        audio.pckeyboardinstrument.readNotes!CurrentFormat();
    }
    backend.close();

    return 0;
}