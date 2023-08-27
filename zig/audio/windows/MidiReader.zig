const MidiReader = @This();

const std = @import("std");
const midilog = std.log.scoped(.midi);

const audio = @import("../../audio.zig");

const win32 = struct {
    usingnamespace @import("win32").media;
    usingnamespace @import("win32").media.audio;
};

const mmsystem = @import("mmsystem.zig");
const fmtMmsyserr = mmsystem.fmtMmsyserr;

callback: audio.midi.ReaderCallback,
handle: win32.HMIDIIN,

pub fn init(callback: audio.midi.ReaderCallback) MidiReader {
    return MidiReader {
        .callback = callback,
        .handle = undefined,
    };
}

// NOTE: start is seperated from init because we need to pass a pointer to MidiReader
//       to the midiInOpen function.
pub fn start(self: *MidiReader, device_id: u32) error{AlreadyReported}!void {
    {
        const result = win32.midiInOpen(
            // TODO: this cast shouldn't be necessary, file an issue?
            @ptrCast(&self.handle),
            device_id,
            @intFromPtr(&inCallback),
            @intFromPtr(self),
            win32.CALLBACK_FUNCTION);
        if (result != win32.MMSYSERR_NOERROR) {
            midilog.err("midiInOpen failed, error={}", .{fmtMmsyserr(result)});
            return error.AlreadyReported;
        }
    }
    errdefer {
        const result = win32.midiInClose(self.handle);
        if (result != win32.MMSYSERR_NOERROR)
            std.debug.panic("midiInClose failed, error={}", .{fmtMmsyserr(result)});
    }
    {
        const result = win32.midiInStart(self.handle);
        if (result != win32.MMSYSERR_NOERROR) {
            midilog.err("midiInStart failed, error={}", .{fmtMmsyserr(result)});
            return error.AlreadyReported;
        }
    }
}

/// do not call stop unless start was called
pub fn stop(self: MidiReader) void {
    {
        const result = win32.midiInStop(self.handle);
        if (result != win32.MMSYSERR_NOERROR)
            std.debug.panic("midiInStop failed, error={}", .{fmtMmsyserr(result)});
    }
    {
        const result = win32.midiInClose(self.handle);
        if (result != win32.MMSYSERR_NOERROR)
            std.debug.panic("midiInClose failed, error={}", .{fmtMmsyserr(result)});
    }
}

fn inCallback(
    handle: win32.HMIDIIN,
    msg: u32,
    instance: usize,
    param1: usize,
    param2: usize
) callconv(std.os.windows.WINAPI) void {
    _ = handle;
    var device: *MidiReader = @ptrFromInt(instance);
    switch (msg) {
        win32.MM_MIM_OPEN => {
            midilog.debug("[MidiListenCallback] open", .{});
        },
        win32.MM_MIM_CLOSE => {
            midilog.debug("[MidiListenCallback] close", .{});
        },
        win32.MM_MIM_DATA => {
            const midi_msg = audio.midi.MidiMsgUnion { .bytes = .{
                .@"0" = @intCast((param1 >>  0) & 0xFF),
                .@"1" = @intCast((param1 >>  8) & 0xFF),
                .@"2" = @intCast((param1 >> 16) & 0xFF),
            }};
            device.callback(param2, midi_msg.msg);
        },
//        } case win32.MIM_LONGDATA:
//            logDebug("[MidiListenCallback] longdata");
//            break;
//        case win32.MIM_ERROR:
//            logDebug("[MidiListenCallback] error");
//            break;
//        case win32.MIM_LONGERROR:
//            logDebug("[MidiListenCallback] longerror");
//            break;
//        case win32.MIM_MOREDATA:
//            logDebug("[MidiListenCallback] moredata");
//            break;
        else => {
            midilog.warn("[MidiListenCallback] UNHANDLED msg={}", .{msg});
        },
    }
}
