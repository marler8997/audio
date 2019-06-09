module audio.backend.wasapi;

import mar.from;
import mar.passfail;
import mar.c : cstring;
import mar.windows : Handle;
import mar.windows.kernel32 : GetLastError, CloseHandle, CreateEventA;
import mar.windows.coreaudio : IAudioClient, IAudioRenderClient;

import audio.log;
static import audio.global;
import audio.renderformat;

struct GlobalData
{
    IAudioClient* audioClient;
    Handle bufferReadyEvent;
    IAudioRenderClient* renderClient;
}
private __gshared GlobalData global;


//
// We preform some steps here because they may affect global parameters
// such as bufferSampleFrameCount and sampleFramesPerSec
passfail setup()
{
    import mar.windows : ClsCtx;
    import mar.windows.winmm.nolink :
        WaveFormatTag, WaveFormatEx, WaveFormatExtensible, KSDataFormat;
    import mar.windows.ole32.nolink : CoInit;
    import mar.windows.ole32 :  CoInitializeEx, CoCreateInstance, CoTaskMemFree;
    import mar.windows.coreaudio : DataFlow, Role,
        IMMDeviceEnumerator, MMDeviceEnumerator, IMMDevice,
        AudioClientShareMode, AudioClientStreamFlags;

    import audio.backend.waveout : dumpWaveFormat;

    IMMDeviceEnumerator* enumerator;
    IMMDevice* device;
    WaveFormatEx* format;
    {
        // Note: I think DRUNTIME may be calling CoInitialize sometimes.
        // If so then I need to figure out how to match druntime.
        const result = CoInitializeEx(null, CoInit.apartmentThreaded);
        //const result = CoInitializeEx(null, CoInit.multiThreaded);
        if (result.failed)
        {
            logError("CoInitializeEx failed, result=", result);
            goto LcoInitializeFailed;
        }
    }

    {
        const result = CoCreateInstance(
            &MMDeviceEnumerator.id,
            null,
            ClsCtx.all,
            &IMMDeviceEnumerator.id,
            cast(void**)&enumerator);
        if (result.failed)
        {
            logError("CoCreateInstance for MMDeviceEnumerator failed, hresult=", result);
            goto LcoCreateInstanceFailed;
        }
    }
    logDebug("calling getDefaultAudioEndpoint...");
    {
        const result = enumerator.getDefaultAudioEndpoint(
            DataFlow.render, Role.console, &device);
        if (result.failed)
        {
            // TODO: clean up IMMDeviceEnumerator
            logError("MMDeviceEnumerator.getDefaultAudioEndpoint failed, hresult=", result);
            goto LgetDefaultAudioEndpointFailed;
        }
    }
    logDebug("device=", cast(void*)device);
    {
        const result = device.activate(&IAudioClient.id, ClsCtx.all, null, cast(void**)&global.audioClient);
        if (result.failed)
        {
            // TODO: clean up IMMDeviceEnumerator and IMMDevice
            logError("IMMDevice.activate failed, hresult=", result);
            goto LdeviceActivateFailed;
        }
    }
    {
        const result = global.audioClient.getMixFormat(&format);
        if (result.failed)
        {
            // TODO: clean up IMMDeviceEnumerator and IMMDevice
            logError("IAudioClient.getMixFormat failed, hresult=", result);
            goto LgetMixFormatFailed;
        }
    }
    dumpWaveFormat(format);


    if (format.samplesPerSec != audio.global.sampleFramesPerSec)
    {
        log("OVERRIDE: sampleFramesPerSec (", audio.global.sampleFramesPerSec,
            ") does not match, setting to ", format.samplesPerSec);
        audio.global.sampleFramesPerSec = format.samplesPerSec;
    }
    if (format.channelCount != audio.global.channelCount)
    {
        logError("backend channel count different from global, not implemented, global=",
            audio.global.channelCount, " backend=", format.channelCount);
        log("the backend should probably allow the channel count to be modified");
        goto LunsupportedWaveFormat;
    }
    {
        const globalBlockAlign = audio.global.channelCount * RenderFormat.SamplePoint.sizeof;
        if (format.blockAlign != globalBlockAlign)
        {
            logError("backend blockAlign different from global, not implemented, global=",
                globalBlockAlign, " backend=", format.blockAlign);
            goto LunsupportedWaveFormat;
        }
    }

    if (format.tag == WaveFormatTag.extensible)
    {
        auto formatExtensible = cast(WaveFormatExtensible*)format;
        if (formatExtensible.subFormat != KSDataFormat.ieeeFloat)
        {
            logError("extensible format guid ", formatExtensible.subFormat, " is not supported");
            goto LunsupportedWaveFormat;
        }
    }
    else
    {
        // TODO: cleanup stuff
        logError("unsupported WaveFormat tag ", format.tag);
        goto LunsupportedWaveFormat;
    }
    //
    // Set a compatible buffer size
    //
    // The way it is currently coded, audio.global.bufferSampleFrameCount cannot
    // exceed the default Period.  This is because we wait to render the next buffer
    // until the system signals the buffer is ready, however, it will only signal it
    // is ready once the defaultPeriod amount of buffer is available.  So if we request
    // a larger buffer, it will fail.  I could sleep some more, but rather than coding that,
    // right now I just make sure our global buffer size isn't larger than the default period.
    //
    {
        long defaultPeriod;
        long minPeriod;
        const result = global.audioClient.getDevicePeriod(&defaultPeriod, &minPeriod);
        if (result.failed)
        {
            logError("audioClient.getDevicePeriod failed, result=", result);
            goto LaudioClientGetDevicePeriodFailed;
        }
        const defaultBufferSampleFrameCount = defaultPeriod * audio.global.sampleFramesPerSec / 10000000;
        const minBufferSampleFrameCount = minPeriod * audio.global.sampleFramesPerSec / 10000000;
        log("DefaultPeriod=", defaultPeriod, " (100ns) or ", defaultPeriod / 10000, " ms or ",
            defaultBufferSampleFrameCount, " sampleFrames");
        log("MinPeriod=", minPeriod, " (100ns) or ", minPeriod / 10000, " ms or ",
            minBufferSampleFrameCount, " sampleFrames");
        if (audio.global.bufferSampleFrameCount == 0)
        {
            log("Setting bufferSampleFrameCount to ", cast(uint)defaultBufferSampleFrameCount);
            audio.global.bufferSampleFrameCount = cast(uint)defaultBufferSampleFrameCount;
        }
        else if (audio.global.bufferSampleFrameCount > defaultBufferSampleFrameCount)
        {
            log("OVERRIDE: bufferSampleFrameCount (",
                audio.global.bufferSampleFrameCount, ") is too big, setting to ",
                defaultBufferSampleFrameCount);
            audio.global.bufferSampleFrameCount = cast(uint)defaultBufferSampleFrameCount;
        }
        else if (audio.global.bufferSampleFrameCount < minBufferSampleFrameCount)
        {
            log("OVERRIDE: bufferSampleFrameCount (",
                audio.global.bufferSampleFrameCount, ") is too small, setting to ",
                minBufferSampleFrameCount);
            audio.global.bufferSampleFrameCount = cast(uint)minBufferSampleFrameCount;
        }
    }

    {
        auto bufferDuration = cast(long)(
            audio.global.bufferSampleFrameCount * 10000000.0 / audio.global.sampleFramesPerSec
        );
        logDebug("bufferDuration=", bufferDuration, " (100ns)");
        const result = global.audioClient.initialize(
            AudioClientShareMode.shared_,
            //AudioClientStreamFlags.none,
            AudioClientStreamFlags.eventCallback,
            bufferDuration,
            0,
            format,
            null);
        if (result.failed)
        {
            logError("audioClient.initialize failed, result=", result);
            goto LaudioClientInitializeFailed;
        }
    }
    {
        uint bufferSampleFrameCount;
        const result = global.audioClient.getBufferSize(&bufferSampleFrameCount);
        if (result.failed)
        {
            logError("audioClient.getBufferSize failed, result=", result);
            goto LaudioClientGetBufferSizeFailed;
        }
        if (bufferSampleFrameCount < audio.global.bufferSampleFrameCount)
        {
            logError("backend bufferSampleCount is less than global, not implemented, global=",
                audio.global.bufferSampleFrameCount, " backend=", bufferSampleFrameCount);
            goto LaudioClientBufferSizeMismatch;
        }
    }
    global.bufferReadyEvent = CreateEventA(null, 1, 0, cstring.nullValue);
    if(global.bufferReadyEvent.isNull)
    {
        logError("CreateEventA failed, e=", GetLastError());
        goto LcreateEventFailed;
    }
    {
        const result = global.audioClient.setEventHandle(global.bufferReadyEvent);
        if (result.failed)
        {
            logError("audioClient.setEventHandle failed, result=", result);
            goto LaudioClientSetEventHandleFailed;
        }
    }
    {
        const result = global.audioClient.getService(&IAudioRenderClient.id, cast(void**)&global.renderClient);
        if (result.failed)
        {
            logError("audioClient.getService failed, result=", result);
            goto LaudioClientGetServiceFailed;
        }
    }

    log("TODO: !!!!!!!!!!!!!!! What can I clean up now?????");
    // enumerator.release(); ???
    return passfail.pass;
    global.renderClient.release();
    global.renderClient = null;
LaudioClientGetServiceFailed:
LbadPeriod:
LaudioClientGetDevicePeriodFailed:
LaudioClientSetEventHandleFailed:
    CloseHandle(global.bufferReadyEvent);
    global.bufferReadyEvent = Handle.nullValue;
LcreateEventFailed:
LaudioClientBufferSizeMismatch:
LaudioClientGetBufferSizeFailed:
LaudioClientInitializeFailed:
LunsupportedWaveFormat:
    CoTaskMemFree(format);
LgetMixFormatFailed:
    global.audioClient.release();
    global.audioClient = null;
LdeviceActivateFailed:
    device.release();
LgetDefaultAudioEndpointFailed:
    enumerator.release();
LcoCreateInstanceFailed:
LcoInitializeFailed:
    return passfail.fail;
}

passfail startingRenderLoop()
{
    return passfail.pass;
}
passfail stoppingRenderLoop()
{
    logError("wasapi close not implemented");
    return passfail.fail;
    /*
    if (waveOutClose(global.waveOut).failed)
        return passfail.fail;
    return passfail.pass;
    */
}

private passfail sendBuffer(void* renderBuffer, bool start)
{
    import mar.mem : memcpy;
    import mar.windows : INFINITE;
    import mar.windows.kernel32 : GetLastError, ResetEvent, WaitForSingleObject;

    void* backendBuffer;
    {
        const result = global.renderClient.getBuffer(audio.global.bufferSampleFrameCount, &backendBuffer);
        if (result.failed)
        {
            logError("audioRenderClient.getBuffer failed, result=", result);
            return passfail.fail;
        }
    }
    // Since we are using the same format as Render format, no need to convert
    memcpy(backendBuffer, renderBuffer,
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
    if(ResetEvent(global.bufferReadyEvent).failed)
    {
        logError("ResetEvent failed, e=", GetLastError());
        return passfail.fail;
    }
    {
        const result = global.renderClient.releaseBuffer(audio.global.bufferSampleFrameCount, 0);
        if (result.failed)
        {
            // TODO: cleanup?
            logError("audioRenderClient.releaseBuffer failed, result=", result);
            return passfail.fail;
        }
    }
    if (start)
    {
        const result = global.audioClient.start();
        if (result.failed)
        {
            // TODO: cleanup?
            logError("audioRenderClient.start failed, result=", result);
            return passfail.fail;
        }
    }
    {
        //logDebug("waiting for play buffer...");
        const result = WaitForSingleObject(global.bufferReadyEvent, INFINITE);
        if (result != 0)
        {
            logError("Expected WaitForSingleObject to return 0 but got ", result, ", e=", GetLastError());
            return passfail.fail;
        }
    }
    {
        uint sampleFramePadding;
        const result = global.audioClient.getCurrentPadding(&sampleFramePadding);
        if (result.failed)
        {
            logError("audioRenderClient.getCurrentPadding failed, result=", result);
            return passfail.fail;
        }
        //log("SampleFramePadding=", sampleFramePadding);
    }
    return passfail.pass;
}


passfail writeFirstBuffer(void* renderBuffer)
{
    return sendBuffer(renderBuffer, true);
}

/**
Writes the given renderBuffer to the audio backend.
Also blocks until the next buffer needs to be rendered.
This blocking characterstic is what keeps the render thread from spinning.

TODO: Read the "Remarks" section from:
    https://docs.microsoft.com/en-us/windows/desktop/api/audioclient/nf-audioclient-iaudioclient-initialize
*/
passfail writeBuffer(void* renderBuffer)
{
    return sendBuffer(renderBuffer, false);
    /+
    // Sleep for how long?
    uint sampleFramePadding;
    {
        const result = global.audioClient.getCurrentPadding(&sampleFramePadding);
        if (result.failed)
        {
            logError("audioRenderClient.getCurrentPadding failed, result=", result);
            return passfail.fail;
        }
    }
    log("SampleFramePadding=", sampleFramePadding);
    if (sampleFramePadding < audio.global.bufferSampleFrameCount)
    {
        logError("NOT IMPLEMENTED: sampleFramePadding=", sampleFramePadding,
            " < bufferSampleFrameCount=", audio.global.bufferSampleFrameCount);
        return passfail.fail;
    }
    {
        const result = renderClient.getBuffer(audio.global.bufferSampleFrameCount,
            &global.buffer);
    }
    logError("wasapi.writeBuffer not fully implemented");
    return passfail.fail;
    +/
}
