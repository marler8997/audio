module audio.backend.linux;

import mar.passfail;

import audio.log;

// don't know what the linux audio api is yet, this
// is just a stub for now
auto bufferSampleFramesCount() { return global.bufferSampleFramesCount; }

struct Global
{
    uint bufferSampleFramesCount;
}
__gshared Global global;

passfail platformInit() { return passfail.pass; }
void open() { }
void close() { }

passfail setAudioFormatAndBufferConfig(uint bufferSampleFramesCount)
{
    global.bufferSampleFramesCount = bufferSampleFramesCount;
    return passfail.pass;
}

passfail writeBuffer(void* renderBuffer)
{
    // stub
    logError("writeBuffer not implemented in linux");
    return passfail.fail;
}
