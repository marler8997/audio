#ifndef WAVEOUT_H
#define WAVEOUT_H

#include "platform.h"

byte shim();
byte platformInit();
byte setAudioFormatAndBufferConfig(AudioFormat format,
				   uint32 samplesPerSecond,
				   byte channelSampleBitLength,
				   byte channelCount,
				   uint32 bufferSampleCount_);

#endif
