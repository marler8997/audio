module _none;

import mar.windows.waveout : WaveFormatTag;

import audio.log;
import audio.render;
import audio.backend.waveout;


int main(string[] args)
{
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

    // This should always be done first thing
    if(audio.backend.waveout.platformInit().failed)
        return 1;

    //initializeRenderers(1); // Use 1 right now for testing
    if(initializeRenderers(16))
        return 1;

    //
    // Note: waveOut function will probably not be able to
    //       keep up with a buffer size less then 23 ms (around 1024 samples @ 44100HZ).
    //       This is a limitation on waveOut API (which is pretty high level).
    //       To get better latency, I'll need to use CoreAudio.
    //
    if(setAudioFormatAndBufferConfig(WaveFormatTag.pcm,
        44100, // samplesPerSecond
        16,    // channelSampleBitLength
        2,     // channelCount
        //4410)) // bufferSampleCount (about 100 ms)
        2205)) // bufferSampleCount (about 50 ms)
        //1664)) // bufferSampleCount (about 40 ms)
        //441)) // bufferSampleCount (about 10 ms)
        return 1;
    /*
    if(setAudioFormatAndBufferConfig(WaveFormatTag.float_,
        48000, // samplesPerSecond
        32,    // channelSampleBitLength
        2,     // channelCount
        //4410); // bufferSampleCount (about 100 ms)
        2205)) // bufferSampleCount (about 50 ms)
        //1664); // bufferSampleCount (about 40 ms)
        //441); // bufferSampleCount (about 10 ms)
        return 1;
    */
    return shim();
}
