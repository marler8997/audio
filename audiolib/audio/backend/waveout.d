module audio.backend.waveout;

import mar.passfail;
import mar.mem : zero;
import mar.c : cstring;

import mar.windows : Handle, INFINITE, InputRecord, ConsoleFlag;
import mar.windows.kernel32 :
    GetLastError, GetCurrentThreadId,
    CreateEventA, SetEvent, ResetEvent,
    QueryPerformanceFrequency, QueryPerformanceCounter,
    WaitForSingleObject;
import mar.windows.winmm;
/*
import mar.windows.winmm :
    WaveFormatTag, WaveoutHandle, WaveFormatEx, SpeakerFlags, KSDataFormat,
    WaveFormatExtensible, WaveHeader, WaveOutputMessage,
    waveOutOpen, waveOutClose, waveOutPrepareHeader, waveOutWrite, waveOutUnprepareHeader;
*/

import audio.log;

struct CustomWaveHeader
{
  WaveHeader base;
  Handle freeEvent;
  //long writeTime;
  //long setEventTime;
}

enum PlayBufferCount = 2;

struct GlobalData
{
    WaveoutHandle waveOut;
    WaveFormatExtensible waveFormat;
    CustomWaveHeader[PlayBufferCount] waveHeaders;
    CustomWaveHeader *frontBuffer;
    CustomWaveHeader *backBuffer;
    uint playBufferSize;
}
private __gshared GlobalData global;

passfail setup()
{
    return passfail.pass;
}

passfail startingRenderLoop()
{
    if (setupGlobalData().failed)
        return passfail.fail;

    const result = waveOutOpen(&global.waveOut,
        WAVE_MAPPER,
        &global.waveFormat.format,
        cast(void*)&waveOutCallback,
        null,
        MuitlmediaOpenFlags.callbackFunction);
    if(result.failed)
    {
        //printf("waveOutOpen failed (result=%d '%s')\n", result, getMMRESULTString(result));
        logError("waveOutOpen failed, result=", result);
        return passfail.fail;
    }
    return passfail.pass;
}
passfail stoppingRenderLoop()
{
    if (waveOutClose(global.waveOut).failed)
        return passfail.fail;
    return passfail.pass;
}

passfail writeFirstBuffer(void* renderBuffer)
{
    return writeBuffer(renderBuffer);
}
/**
Writes the given renderBuffer to the audio backend.
Also blocks until the next buffer needs to be rendered.
This blocking characterstic is what keeps the render thread from spinning.
*/
passfail writeBuffer(void* renderBuffer)
{
    import mar.mem : memcpy;
    import mar.windows : INFINITE;
    import mar.windows.kernel32 : GetLastError, WaitForSingleObject;

    static import audio.global;
    import audio.renderformat;

    // TODO: figure out which functions are taking the longest
    //now.update();

    // Since we are using the same format as Render format, no need to convert
    memcpy(global.backBuffer.base.data, renderBuffer,
        audio.global.bufferSampleFrameCount * audio.global.channelCount * RenderFormat.SamplePoint.sizeof);
    /*
    if (audio.global.channelCount == 1)
    {
        logError("waveout writeBuffer channelCount 1 not impl");
        return passfail.fail;
    }
    else if (audio.global.channelCount == 2)
    {
        Format.monoToStereo(cast(uint*)global.backBuffer.base.data, cast(ushort*)renderBuffer, global.bufferSampleFrameCount);
    }
    else
    {
        logError("waveout writeBuffer channelCount ", audio.global.channelCount, " not impl");
        return passfail.fail;
    }
    */
    // TODO: is prepare necessary each time with no backbuffer?
    {
        const result = waveOutPrepareHeader(global.waveOut, &global.backBuffer.base, WaveHeader.sizeof);
        if (result.failed)
        {
            logError("waveOutPrepareHeader failed, result=", result);
            return passfail.fail;
        }
    }
    if(ResetEvent(global.backBuffer.freeEvent).failed)
    {
        logError("ResetEvent failed, e=", GetLastError());
        return passfail.fail;
    }
    {
        const result = waveOutWrite(global.waveOut, &global.backBuffer.base, WaveHeader.sizeof);
        if (result.failed)
        {
            logError("waveOutWrite failed, result=", result);
            return passfail.fail;
        }
    }

    // Wait for the front buffer, this delays the next render so it doesn't happen
    // too soon.
    {
        //logDebug("waiting for play buffer...");
        const result = WaitForSingleObject(global.frontBuffer.freeEvent, INFINITE);
        if (result != 0)
        {
            logError("Expected WaitForSingleObject to return 0 but got ", result, ", e=", GetLastError());
            return passfail.fail;
        }
    }
    // TODO: is unprepare necessary with no backbuffer?
    {
        const result = waveOutUnprepareHeader(global.waveOut, &global.frontBuffer.base, WaveHeader.sizeof);
        if (result.failed)
        {
            logError("waveOutUnprepareHeader failed, result=", result);
            return passfail.fail;
        }
    }
    auto temp = global.frontBuffer;
    global.frontBuffer = global.backBuffer;
    global.backBuffer = temp;
    return passfail.pass;
}

// TODO: define a function to get the AudioFormat string (platform dependent?)

// 0 = success
private passfail setupGlobalData()
{
    import mar.mem;
    static import audio.global;
    import audio.renderformat;
    import audio.renderformat.options : Pcm16Format, FloatFormat;

    //
    // Setup audio format
    //
    global.waveFormat.format.samplesPerSec  = audio.global.sampleFramesPerSec;

    global.waveFormat.format.bitsPerSample  = RenderFormat.SamplePoint.sizeof * 8;
    global.waveFormat.format.blockAlign     = cast(ushort)(RenderFormat.SamplePoint.sizeof * audio.global.channelCount);

    global.waveFormat.format.channelCount   = audio.global.channelCount;

    global.waveFormat.format.avgBytesPerSec = global.waveFormat.format.blockAlign * audio.global.sampleFramesPerSec;

    // For now just match the render format so we don't have to convert
    if (is(RenderFormat == Pcm16Format))
    {
        global.waveFormat.format.tag        = WaveFormatTag.pcm;
        global.waveFormat.format.extraSize  = 0; // Size of extra info
    }
    else if (is(RenderFormat == FloatFormat))
    {
        global.waveFormat.format.tag         = WaveFormatTag.extensible;
        global.waveFormat.format.extraSize   = 22; // Size of extra info
        global.waveFormat.validBitsPerSample = RenderFormat.SamplePoint.sizeof * 8;
        if (audio.global.channelCount == 1)
            global.waveFormat.channelMask    = SpeakerFlags.frontCenter;
        else if (audio.global.channelCount == 2)
            global.waveFormat.channelMask    = SpeakerFlags.frontLeft | SpeakerFlags.frontRight;
        else
        {
            logError("waveout channel count ", audio.global.channelCount, " not implemented");
            return passfail.fail;
        }
        global.waveFormat.subFormat          = KSDataFormat.ieeeFloat;
    }
    else
    {
        logError("waveout does not support this render format");
        return passfail.fail;
    }

    // Setup Buffers
    global.playBufferSize = audio.global.bufferSampleFrameCount * global.waveFormat.format.blockAlign;
    foreach (i; 0 .. PlayBufferCount)
    {
        if (global.waveHeaders[i].base.data)
            free(global.waveHeaders[i].base.data);
        global.waveHeaders[i].base.bufferLength = global.playBufferSize;
        global.waveHeaders[i].base.data = malloc(global.playBufferSize);
        if(global.waveHeaders[i].base.data == null)
        {
            logError("malloc failed");
            return passfail.fail;
        }
        global.waveHeaders[i].freeEvent = CreateEventA(null, 1, 1, cstring.nullValue);
        if(global.waveHeaders[i].freeEvent.isNull)
        {
            logError("CreateEvent failed");
            return passfail.fail;
        }
    }
    global.frontBuffer = &global.waveHeaders[0];
    global.backBuffer = &global.waveHeaders[1];

    return passfail.pass;
}

extern (Windows) void waveOutCallback(WaveoutHandle waveOut, uint msg, uint* instance,
    uint* param1, uint* param2)
{
    //logDebug("waveOutCallback (instance=0x%p,param1=0x%p,param2=0x%p)\n",
    //instance, param1, param2);
    switch(msg)
    {
    case WaveOutputMessage.open:
        logDebug("[tid=", GetCurrentThreadId(), "] waveOutCallback (msg=", msg, " WOM_OPEN)");
        break;
    case WaveOutputMessage.close:
        logDebug("[tid=", GetCurrentThreadId(), "] waveOutCallback (msg=", msg, " WOM_CLOSE)");
        break;
    case WaveOutputMessage.done:
        //logDebug("[tid=", GetCurrentThreadId(), "] waveOutCallback (msg=", msg, " WOM_DONE)");
        {
            auto header = cast(CustomWaveHeader*)param1;
            //printf("[DEBUG] header (dwBufferLength=%d,data=0x%p)\n",
            //header->dwBufferLength, header->data);
            //QueryPerformanceCounter(&header.setEventTime);
            SetEvent(header.freeEvent);
        }
        break;
    default:
        logDebug("[tid=", GetCurrentThreadId(), "] waveOutCallback (msg=", msg, ")");
        break;
    }
    flushDebug();
}

void dumpWaveFormat(WaveFormatEx* format)
{
    import mar.print : formatHex;
    if (format.tag == WaveFormatTag.extensible)
    {
        dumpWaveFormat(cast(WaveFormatExtensible*)format);
        return;
    }
    logDebug("WaveFormatEx:");
    logDebug(" tag=", format.tag);
    logDebug(" channels=", format.channelCount);
    logDebug(" samplesPerSec=", format.samplesPerSec);
    logDebug(" avgBytesPerSec=", format.avgBytesPerSec);
    logDebug(" blockAlign=", format.blockAlign);
    logDebug(" bitsPerSample=", format.bitsPerSample);
    logDebug(" extraSize=", format.extraSize);
}
void dumpWaveFormat(WaveFormatExtensible* format)
{
    import mar.print : formatHex;
    logDebug("WaveFormatExtensible (tag=", format.format.tag, "):");
    logDebug(" channels=", format.format.channelCount);
    logDebug(" samplesPerSec=", format.format.samplesPerSec);
    logDebug(" avgBytesPerSec=", format.format.avgBytesPerSec);
    logDebug(" blockAlign=", format.format.blockAlign);
    logDebug(" bitsPerSample=", format.format.bitsPerSample);
    logDebug(" extraSize=", format.format.extraSize);
    logDebug(" extra:");
    logDebug(" validBitsPerSample|samplesPerBlock=", format.validBitsPerSample);
    logDebug(" channelMask=0x", format.channelMask.formatHex);
    logDebug(" subFormat=", format.subFormat);
    /*
    logDebug(" subFormat=", format.subFormat.a.formatHex
        , "-", format.subFormat.b.formatHex
        , "-", format.subFormat.c.formatHex
        , "-", format.subFormat.d[0].formatHex
        , "-", format.subFormat.d[1].formatHex
        , "-", format.subFormat.d[2].formatHex
        , "-", format.subFormat.d[3].formatHex
        , "-", format.subFormat.d[4].formatHex
        , "-", format.subFormat.d[5].formatHex
        , "-", format.subFormat.d[6].formatHex
        , "-", format.subFormat.d[7].formatHex
    );
    */

    //logDebug("sizeof WaveFormatEx=", format.format.sizeof);
    //logDebug("offsetof channelMask=", format.channelMask.offsetof);
    //logDebug("offsetof subFormat=", format.subFormat.offsetof);
}
