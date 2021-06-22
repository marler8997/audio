const std = @import("std");
const midilog = std.log.scoped(.midi);

const audio = @import("../../audio.zig");

const win32 = @import("win32");
usingnamespace win32.media.multimedia;
//usingnamespace @import("win32missing.zig");

const State = enum {
    initial,
    midiInOpened,
    started,
};

callback: audio.midi.ReaderCallback,
state: State,
midiHandle: HMIDIIN,

pub fn init(callback: audio.midi.ReaderCallback) @This() {
    return @This() {
        .callback = callback,
        .state = State.initial,
        .midiHandle = undefined,
    };
}

pub fn start(device: *@This(), midiDeviceID: u32) !void {

    errdefer stop(device) catch {}; // just attempt to stop on failure

    if (device.state == State.initial) {
        const result = midiInOpen(
            &device.midiHandle,
            midiDeviceID,
            @ptrToInt(inCallback),
            @ptrToInt(device),
            CALLBACK_FUNCTION);
        if (result != MMSYSERR_NOERROR) {
            midilog.err("midiInOpen failed, result={}", .{result});
            return error.Unexpected;
        }
        device.state = State.midiInOpened;
    }
    if (device.state == State.midiInOpened) {
        const result = midiInStart(device.midiHandle);
        if (result != MMSYSERR_NOERROR) {
            midilog.err("midiInStart failed, result={}", .{result});
            return error.Unexpected;
        }
        device.state = State.started;
    }
}

pub fn stop(device: *@This()) !void {
    midilog.info("WindowsMidiReader", .{});
    if (device.state == State.started) {
        const result = midiInStop(device.midiHandle);
        if (result != MMSYSERR_NOERROR) {
            midilog.err("midiInStop failed, result={}", .{result});
            return error.Unexpected;
        }
        device.state = State.midiInOpened;
    }
    if (device.state == State.midiInOpened) {
        const result = midiInClose(device.midiHandle);
        if (result != MMSYSERR_NOERROR) {
            midilog.err("midiInClose failed, result={}", .{result});
            return error.Unexpected;
        }
        device.state = State.initial;
    }
}

fn inCallback(
    handle: HMIDIIN,
    msg: u32,
    instance: usize,
    param1: usize,
    param2: usize
) callconv(std.os.windows.WINAPI) void {
    var device = @intToPtr(*@This(), instance);
    switch (msg) {
        MM_MIM_OPEN => {
            midilog.debug("[MidiListenCallback] open", .{});
        },
        MM_MIM_CLOSE => {
            midilog.debug("[MidiListenCallback] close", .{});
        },
        MM_MIM_DATA => {
            const midi_msg = audio.midi.MidiMsgUnion { .bytes = [3]u8 {
                @intCast(u8, (param1 >>  0) & 0xFF),
                @intCast(u8, (param1 >>  8) & 0xFF),
                @intCast(u8, (param1 >> 16) & 0xFF),
            }};
            device.callback(param2, midi_msg.msg);
        },
//        } case MIM_LONGDATA:
//            logDebug("[MidiListenCallback] longdata");
//            break;
//        case MIM_ERROR:
//            logDebug("[MidiListenCallback] error");
//            break;
//        case MIM_LONGERROR:
//            logDebug("[MidiListenCallback] longerror");
//            break;
//        case MIM_MOREDATA:
//            logDebug("[MidiListenCallback] moredata");
//            break;
        else => {
            midilog.warn("[MidiListenCallback] UNHANDLED msg={}", .{msg});
        },
    }
}
