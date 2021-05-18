//module audio.backend.waveout;
//
//import mar.passfail;
//import mar.mem : zero;
//import mar.c : cstring;
const std = @import("std");

const win32 = @import("win32");
usingnamespace win32.system.system_services;
usingnamespace win32.system.threading;
usingnamespace win32.system.windows_programming;
usingnamespace win32.media.multimedia;
usingnamespace win32.media.audio.core_audio;
const win32fix = @import("../win32fix.zig");
// this constant is missing from win32: https://github.com/microsoft/win32metadata/issues/482
const WAVE_MAPPER : u32 = 0xFFFFFFFF;

const audio = @import("../../audio.zig");
usingnamespace audio.log;
usingnamespace audio.renderformat;

const CustomWaveHeader = extern struct {
    base: WAVEHDR,
    freeEvent : HANDLE,
    //i64 writeTime;
    //i64 setEventTime;
};

const global = struct {
    var waveOut: HWAVEOUT = undefined;
    var waveFormat: win32fix.WAVEFORMATEXTENSIBLE = undefined;
    var waveHeaders: [2]CustomWaveHeader = undefined;
    var frontBuffer: *CustomWaveHeader = undefined;
    var backBuffer: *CustomWaveHeader = undefined;
    var playBufferSize: u32 = undefined;
};

pub const funcs = audio.backend.BackendFuncs {
    .setup = setup,
    .startingRenderLoop = startingRenderLoop,
    .stoppingRenderLoop = stoppingRenderLoop,
    .writeFirstBuffer = writeBuffer,
    .writeBuffer = writeBuffer,
};

fn setup() anyerror!void {
    //logDebug("waveout setup");
}

const LocalError  = error {
    WaveOutOpenFailed,
    WaveOutCloseFailed,
    WaveOutPrepareHeaderFailed,
    WaveOutUnprepareHeaderFailed,
    WaveOutWriteFailed,
    WaitForSingleObjectFailed,
};

fn startingRenderLoop() anyerror!void {

    logDebug("waveout: startingRenderLoop", .{});
    try setupGlobalData();
    const temp : usize = @sizeOf(WAVEFORMATEX);
    //logDebug("@sizeOf(WAVEFORMATEX)={}", .{temp});
    //stdext.debug.dumpData("WAVEFORMATEX", stdext.debug.ptrData(&global.waveFormat));
    const result = waveOutOpen(&global.waveOut,
        WAVE_MAPPER,
        &global.waveFormat.Format,
        @ptrToInt(waveOutCallback),
        0,
        CALLBACK_FUNCTION);
    if (result != MMSYSERR_NOERROR)
    {
        //printf("waveOutOpen failed (result=%d '%s')\n", .{result, getMMRESULTString(result)});
        logError("waveOutOpen failed, result={}", .{result});
        return LocalError.WaveOutOpenFailed;
    }
}
fn stoppingRenderLoop() anyerror!void {
    const result = waveOutClose(global.waveOut);
    if (result != MMSYSERR_NOERROR) {
        logError("waveOutClose failed, result={}", .{result});
        return LocalError.WaveOutCloseFailed;
    }
}

/// Writes the given renderBuffer to the audio backend.
/// Also blocks until the next buffer needs to be rendered.
/// This blocking characterstic is what keeps the render thread from spinning.
fn writeBuffer(renderBuffer: [*]const SamplePoint) anyerror!void {

    // TODO: figure out which functions are taking the longest
    //now.update();

    // Since we are using the same format as Render format, no need to convert
    @memcpy(global.backBuffer.base.lpData, @ptrCast([*]const u8, renderBuffer),
        audio.global.bufferSampleFrameCount * audio.global.channelCount * @sizeOf(SamplePoint));


    //if (audio.global.channelCount == 1)
    //{
    //    logError("waveout writeBuffer channelCount 1 not impl");
    //    return passfail.fail;
    //}
    //else if (audio.global.channelCount == 2)
    //{
    //    Format.monoToStereo(cast(uint*)global.backBuffer.base.data, cast(ushort*)renderBuffer, global.bufferSampleFrameCount);
    //}
    //else
    //{
    //    logError("waveout writeBuffer channelCount ", audio.global.channelCount, " not impl");
    //    return passfail.fail;
    //}

    // TODO: is prepare necessary each time with no backbuffer?
    {
        const result = waveOutPrepareHeader(global.waveOut,
            &global.backBuffer.base, @sizeOf(@TypeOf(global.backBuffer.*)));
        if (result != MMSYSERR_NOERROR) {
            logError("waveOutPrepareHeader failed, result={}", .{result});
            return LocalError.WaveOutPrepareHeaderFailed;
        }
    }
    if(0 == ResetEvent(global.backBuffer.freeEvent))
    {
        logError("ResetEvent failed, e={}", .{std.os.windows.kernel32.GetLastError()});
        return error.Unexpected;
    }
    {
        const result = waveOutWrite(global.waveOut,
            &global.backBuffer.base, @sizeOf(@TypeOf(global.backBuffer.*)));
        if (result != MMSYSERR_NOERROR) {
            logError("waveOutWrite failed, result={}", .{result});
            return LocalError.WaveOutWriteFailed;
        }
    }

    // Wait for the front buffer, this delays the next render so it doesn't happen
    // too soon.
    //logDebug("waiting for play buffer...");
    switch (WaitForSingleObjectEx(global.frontBuffer.freeEvent, INFINITE, FALSE)) {
        WAIT_OBJECT_0 => {},
        else => |err| {
            logError("WaitForSingleObjectEx failed, result={}, e={}", .{err, std.os.windows.kernel32.GetLastError()});
            return error.WaitForSingleObjectFailed;
        },
    }
    // TODO: is unprepare necessary with no backbuffer?
    {
        const result = waveOutUnprepareHeader(global.waveOut,
            &global.frontBuffer.base, @sizeOf(@TypeOf(global.backBuffer.*)));
        if (result != MMSYSERR_NOERROR) {
            logError("waveOutUnprepareHeader failed, result={}", .{result});
            return LocalError.WaveOutUnprepareHeaderFailed;
        }
    }
    var temp = global.frontBuffer;
    global.frontBuffer = global.backBuffer;
    global.backBuffer = temp;
}

fn setupGlobalData() anyerror!void {
    //
    // For now just match the render format so we don't have to convert
    //
    global.waveFormat.Format.nSamplesPerSec  = audio.global.sampleFramesPerSec;
    global.waveFormat.Format.wBitsPerSample  = @sizeOf(SamplePoint) * 8;
    global.waveFormat.Format.nBlockAlign     = @sizeOf(SamplePoint) * audio.global.channelCount;
    global.waveFormat.Format.nChannels       = audio.global.channelCount;
    global.waveFormat.Format.nAvgBytesPerSec = global.waveFormat.Format.nBlockAlign * audio.global.sampleFramesPerSec;

    switch (RenderFormat.type_) {
        RenderFormatType.pcm16 => {
            global.waveFormat.Format.wFormatTag = WAVE_FORMAT_PCM;
            global.waveFormat.Format.cbSize     = 0;
        },
        RenderFormatType.float32 => {

            global.waveFormat.Format.wFormatTag  = WAVE_FORMAT_EXTENSIBLE;
            global.waveFormat.Format.cbSize      = 22; // Size of extra info
            global.waveFormat.wValidBitsPerSample = @sizeOf(SamplePoint) * 8;
            if (audio.global.channelCount == 1) {
                global.waveFormat.dwChannelMask  = SPEAKER_FRONT_CENTER;
            } else if (audio.global.channelCount == 2) {
                global.waveFormat.dwChannelMask  = SPEAKER_FRONT_LEFT | SPEAKER_FRONT_RIGHT;
            } else {
                logError("waveout channel count {} not implemented", .{audio.global.channelCount});
                return error.NotImplemented;
            }
            global.waveFormat.SubFormat          = CLSID_KSDATAFORMAT_SUBTYPE_IEEE_FLOAT.*;
        },
        //else => {
        //    logError("waveout doesn't support the current render format", .{});
        //    return error.RenderFormatError;
        //},
    }

    // Setup Buffers
    global.playBufferSize = audio.global.bufferSampleFrameCount * global.waveFormat.Format.nBlockAlign;
    for (global.waveHeaders) |*waveHeader| {
        waveHeader.base.dwBufferLength = global.playBufferSize;
        var buffer = try audio.global.allocator.alloc(SamplePoint, global.playBufferSize);
        // https://github.com/microsoft/win32metadata/issues/483
        //waveHeader.base.lpData = @ptrCast([*]u8, buffer.ptr);
        waveHeader.base.lpData = @ptrCast([*:0]u8, buffer.ptr);
        waveHeader.freeEvent = CreateEventA(null, 1, 1, null);
        if (@ptrToInt(waveHeader.freeEvent) == 0) {
            logError("CreateEventA failed, e={}", .{std.os.windows.kernel32.GetLastError()});
            return error.BadValue;
        }
    }
    global.frontBuffer = &global.waveHeaders[0];
    global.backBuffer = &global.waveHeaders[1];
}

pub fn waveOutCallback(waveout: HWAVEOUT, msg: u32, instance: *u32,
    param1: *u32, param2: *u32) callconv(std.os.windows.WINAPI) void {

    if (msg == MM_WOM_OPEN) {
        //logDebug("[tid=", GetCurrentThreadId(), "] waveOutCallback (msg=", msg, " WOM_OPEN)");
        logDebug("WOM_OPEN (instance={},param1={},param2={})", .{instance, param1, param2});
    } else if (msg == MM_WOM_CLOSE) {
        //logDebug("[tid=", GetCurrentThreadId(), "] waveOutCallback (msg=", msg, " WOM_CLOSE)");
        logDebug("WOM_CLOSE (instance={},param1={},param2={})", .{instance, param1, param2});
    } else if (msg == MM_WOM_DONE) {
        ////logDebug("[tid=", GetCurrentThreadId(), "] waveOutCallback (msg=", msg, " WOM_DONE)");
        //logDebug("WOM_DONE (instance={},param1={},param2={})", instance, param1, param2);
        const header = @fieldParentPtr(CustomWaveHeader, "base",
            @intToPtr(*WAVEHDR, @ptrToInt(param1)));
        //printf("[DEBUG] header (dwBufferLength=%d,data=0x%p)\n",
        //header->dwBufferLength, header->data);
        //QueryPerformanceCounter(&header.setEventTime);
        if (0 == SetEvent(header.freeEvent)) {
            logError("SetEvent on waveout buffer failed, this should cause waveout thread to hang", .{});
        }
    } else {
        //logDebug("[tid=", GetCurrentThreadId(), "] waveOutCallback (msg=", msg, ")");
        logDebug("WOM_? ({}) (instance={},param1={},param2={})", .{msg, instance, param1, param2});
    }
    //flushDebug();
}
//
//void dumpWaveFormat(WaveFormatEx* format)
//{
//    import mar.print : formatHex;
//    if (format.tag == WaveFormatTag.extensible)
//    {
//        dumpWaveFormat(cast(WaveFormatExtensible*)format);
//        return;
//    }
//    logDebug("WaveFormatEx:");
//    logDebug(" tag=", format.tag);
//    logDebug(" channels=", format.channelCount);
//    logDebug(" samplesPerSec=", format.samplesPerSec);
//    logDebug(" avgBytesPerSec=", format.avgBytesPerSec);
//    logDebug(" blockAlign=", format.blockAlign);
//    logDebug(" bitsPerSample=", format.bitsPerSample);
//    logDebug(" extraSize=", format.extraSize);
//}
//void dumpWaveFormat(WaveFormatExtensible* format)
//{
//    import mar.print : formatHex;
//    logDebug("WaveFormatExtensible (tag=", format.format.tag, "):");
//    logDebug(" channels=", format.format.channelCount);
//    logDebug(" samplesPerSec=", format.format.samplesPerSec);
//    logDebug(" avgBytesPerSec=", format.format.avgBytesPerSec);
//    logDebug(" blockAlign=", format.format.blockAlign);
//    logDebug(" bitsPerSample=", format.format.bitsPerSample);
//    logDebug(" extraSize=", format.format.extraSize);
//    logDebug(" extra:");
//    logDebug(" validBitsPerSample|samplesPerBlock=", format.validBitsPerSample);
//    logDebug(" channelMask=0x", format.channelMask.formatHex);
//    logDebug(" subFormat=", format.subFormat);
//    /*
//    logDebug(" subFormat=", format.subFormat.a.formatHex
//        , "-", format.subFormat.b.formatHex
//        , "-", format.subFormat.c.formatHex
//        , "-", format.subFormat.d[0].formatHex
//        , "-", format.subFormat.d[1].formatHex
//        , "-", format.subFormat.d[2].formatHex
//        , "-", format.subFormat.d[3].formatHex
//        , "-", format.subFormat.d[4].formatHex
//        , "-", format.subFormat.d[5].formatHex
//        , "-", format.subFormat.d[6].formatHex
//        , "-", format.subFormat.d[7].formatHex
//    );
//    */
//
//    //logDebug("sizeof WaveFormatEx=", format.format.sizeof);
//    //logDebug("offsetof channelMask=", format.channelMask.offsetof);
//    //logDebug("offsetof subFormat=", format.subFormat.offsetof);
//}
