module audio.backend.linux;

import mar.passfail;

import audio.log;

// don't know what the linux audio api is yet, this
// is just a stub for now
auto bufferSampleCount() { return global.bufferSampleCount; }

struct Global
{
    uint bufferSampleCount;
}
__gshared Global global;

passfail platformInit() { return passfail.pass; }
void open() { }
void close() { }

passfail setAudioFormatAndBufferConfig(uint bufferSampleCount)
{
    global.bufferSampleCount = bufferSampleCount;
    return passfail.pass;
}

passfail writeBuffer(Format)(void* renderBuffer)
{
    // stub
    logError("writeBuffer not implemented in linux");
    return passfail.fail;
}
