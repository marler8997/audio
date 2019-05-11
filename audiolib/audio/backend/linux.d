module audio.backend.linux;

import mar.passfail;

import audio.log;

// don't know what the linux audio api is yet, this
// is just a stub for now
auto samplesPerSec() { return global.samplesPerSec; }
auto bufferSampleCount() { return global.bufferSampleCount; }

enum AudioFormat
{
    pcm, float_
}

struct Global
{
    uint samplesPerSec;
    uint bufferSampleCount;
}
__gshared Global global;

passfail platformInit() { return passfail.pass; }
void open() { }
void close() { }

ubyte setAudioFormatAndBufferConfig(AudioFormat formatID,
				   uint samplesPerSec,
				   ubyte channelSampleBitLength,
				   ubyte channelCount,
				   uint bufferSampleCount)
{
    global.samplesPerSec = samplesPerSec;
    global.bufferSampleCount = bufferSampleCount;
    return 0;
}

passfail writeBuffer(Format)(void* renderBuffer)
{
    // stub
    logError("writeBuffer not implemented in linux");
    return passfail.fail;
}
