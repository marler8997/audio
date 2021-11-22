const std = @import("std");
const midilog = std.log.scoped(.midi);

const audio = @import("../../audio.zig");

const win32 = struct {
    usingnamespace @import("win32").media;
    usingnamespace @import("win32").media.audio;
};
//usingnamespace @import("win32missing.zig");

const State = enum {
    initial,
    midiInOpened,
    started,
};

callback: audio.midi.ReaderCallback,
state: State,
midiHandle: win32.HMIDIIN,

pub fn init(callback: audio.midi.ReaderCallback) @This() {
    return @This() {
        .callback = callback,
        .state = State.initial,
        .midiHandle = undefined,
    };
}

pub fn start(self: *@This(), midiDeviceID: u32) !void {

    errdefer stop(self) catch {}; // just attempt to stop on failure

    if (self.state == State.initial) {
        const result = win32.midiInOpen(
            // TODO: this cast shouldn't be necessary, file an issue?
            @ptrCast(*?win32.HMIDIIN, &self.midiHandle),
            midiDeviceID,
            @ptrToInt(inCallback),
            @ptrToInt(self),
            win32.CALLBACK_FUNCTION);
        if (result != win32.MMSYSERR_NOERROR) {
            midilog.err("midiInOpen failed, result={}", .{result});
            return error.Unexpected;
        }
        self.state = State.midiInOpened;
    }
    if (self.state == State.midiInOpened) {
        const result = win32.midiInStart(self.midiHandle);
        if (result != win32.MMSYSERR_NOERROR) {
            midilog.err("midiInStart failed, result={}", .{result});
            return error.Unexpected;
        }
        self.state = State.started;
    }
}

pub fn stop(self: *@This()) !void {
    midilog.info("WindowsMidiReader", .{});
    if (self.state == State.started) {
        const result = win32.midiInStop(self.midiHandle);
        if (result != win32.MMSYSERR_NOERROR) {
            midilog.err("midiInStop failed, result={}", .{result});
            return error.Unexpected;
        }
        self.state = State.midiInOpened;
    }
    if (self.state == State.midiInOpened) {
        const result = win32.midiInClose(self.midiHandle);
        if (result != win32.MMSYSERR_NOERROR) {
            midilog.err("midiInClose failed, result={}", .{result});
            return error.Unexpected;
        }
        self.state = State.initial;
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
    var device = @intToPtr(*@This(), instance);
    switch (msg) {
        win32.MM_MIM_OPEN => {
            midilog.debug("[MidiListenCallback] open", .{});
        },
        win32.MM_MIM_CLOSE => {
            midilog.debug("[MidiListenCallback] close", .{});
        },
        win32.MM_MIM_DATA => {
            const midi_msg = audio.midi.MidiMsgUnion { .bytes = [3]u8 {
                @intCast(u8, (param1 >>  0) & 0xFF),
                @intCast(u8, (param1 >>  8) & 0xFF),
                @intCast(u8, (param1 >> 16) & 0xFF),
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
