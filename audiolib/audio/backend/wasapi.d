module audio.backend.wasapi;

import mar.passfail;
/*
import mar.mem : zero;
import mar.c : cstring;

import mar.windows.types : Handle, INFINITE, InputRecord, ConsoleFlag;
import mar.windows.kernel32 :
    GetLastError, GetCurrentThreadId,
    CreateEventA, SetEvent, ResetEvent,
    QueryPerformanceFrequency, QueryPerformanceCounter,
    WaitForSingleObject;
import mar.windows.winmm;
import mar.windows.waveout :
    WaveFormatTag, WaveoutHandle, WaveFormatEx, ChannelFlags, KSDataFormat,
    WaveFormatExtensible, WaveHeader, WaveOutputMessage;
*/
import audio.log;


struct GlobalData
{
    /*
    WaveoutHandle waveOut;
    AudioFormat audioFormatID;
    WaveFormatExtensible waveFormat;
    CustomWaveHeader[PlayBufferCount] waveHeaders;
    CustomWaveHeader *frontBuffer;
    version (UseBackBuffer)
    {
        CustomWaveHeader *backBuffer;
    }
    */
    //uint playBufferSize;
}
private __gshared GlobalData global;

passfail open()
{
    logError("wasapi open not implemented");
    return passfail.fail;
    /*
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
    */
}
passfail close()
{
    logError("wasapi close not implemented");
    return passfail.fail;
    /*
    if (waveOutClose(global.waveOut).failed)
        return passfail.fail;
    return passfail.pass;
    */
}

/**
Writes the given renderBuffer to the audio backend.
Also blocks until the next buffer needs to be rendered.
This blocking characterstic is what keeps the render thread from spinning.
*/
passfail writeBuffer(void* renderBuffer)
{
    logError("wasapi writeBuffer not implemented");
    return passfail.fail;
    /+
    import mar.mem : memcpy;
    import mar.windows.types : INFINITE;
    import mar.windows.kernel32 : GetLastError, WaitForSingleObject;

    static import audio.global;
    import audio.renderformat;

    // TODO: figure out which functions are taking the longest
    //now.update();

    // Since we are using the same format as Render format, no need to convert
    memcpy(global.backBuffer.base.data, renderBuffer,
        bufferSampleFrameCount * audio.global.channelCount * RenderFormat.SamplePoint.sizeof);
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
    +/
}

// TODO: define a function to get the AudioFormat string (platform dependent?)

// 0 = success
passfail setAudioFormatAndBufferConfig(uint bufferSampleFrameCount)
{
    logError("wasapi setAudioFormatAndBufferConfig not impl");
    return passfail.fail;
    /*
    import mar.mem;
    static import audio.global;
    import audio.renderformat;
    import audio.renderformat.options : Pcm16Format, FloatFormat;

    //
    // Setup audio format
    //
    // For now just match the render format so we don't have to convert
    static if (is(RenderFormat == Pcm16Format))
        global.audioFormatID = WaveFormatTag.pcm;
    else static if (is(RenderFormat == FloatFormat))
        global.audioFormatID = WaveFormatTag.float_;
    else static assert("waveout does not support this render format");

    global.waveFormat.format.samplesPerSec  = audio.global.sampleFramesPerSec;

    global.waveFormat.format.bitsPerSample  = RenderFormat.SamplePoint.sizeof * 8;
    global.waveFormat.format.blockAlign     = cast(ushort)(RenderFormat.SamplePoint.sizeof * audio.global.channelCount);

    global.waveFormat.format.channelCount   = audio.global.channelCount;

    global.waveFormat.format.avgBytesPerSec = global.waveFormat.format.blockAlign * audio.global.sampleFramesPerSec;

    if(global.audioFormatID == WaveFormatTag.pcm)
    {
        global.waveFormat.format.tag        = WaveFormatTag.pcm;
        global.waveFormat.format.extraSize  = 0; // Size of extra info
    }
    else if(global.audioFormatID == WaveFormatTag.float_)
    {
        global.waveFormat.format.tag         = WaveFormatTag.extensible;
        global.waveFormat.format.extraSize   = 22; // Size of extra info
        global.waveFormat.validBitsPerSample = RenderFormat.SamplePoint.sizeof * 8;
        if (audio.global.channelCount == 1)
            global.waveFormat.channelMask    = ChannelFlags.frontCenter;
        else if (audio.global.channelCount == 2)
            global.waveFormat.channelMask    = ChannelFlags.frontLeft | ChannelFlags.frontRight;
        else
        {
            logError("waveout channel count ", audio.global.channelCount, " not implemented");
            return passfail.fail;
        }
        global.waveFormat.subFormat          = KSDataFormat.ieeeFloat;
    }
    else
    {
        logError("Unsupported format", global.audioFormatID);
        return passfail.fail;
    }

    // Setup Buffers
    global.bufferSampleFrameCount = bufferSampleFrameCount;
    global.playBufferSize = bufferSampleFrameCount * global.waveFormat.format.blockAlign;
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
    version (UseBackBuffer)
    {
        global.backBuffer = &global.waveHeaders[1];
    }

    return passfail.pass;
    */
}
