#include "render.h"

int main(int argc, char* argv[])
{
  // This should always be done first thing
  if(platformInit())
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
  if(setAudioFormatAndBufferConfig(WAVE_FORMAT_PCM,
				   44100, // samplesPerSecond
				   16,    // channelSampleBitLength
				   2,     // channelCount
				   //4410)) // bufferSampleCount (about 100 ms)
				   2205)) // bufferSampleCount (about 50 ms)
                                   //1664)) // bufferSampleCount (about 40 ms)
                                   //441)) // bufferSampleCount (about 10 ms)
    return 1;
    /*
  if(setAudioFormatAndBufferConfig(WAVE_FORMAT_FLOAT,
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

