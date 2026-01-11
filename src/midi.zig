pub const Reader = @import("midi/Reader.zig");

pub fn countIn() u32 {
    if (builtin.os.tag == .windows) {
        return win32.midiInGetNumDevs();
    }
    @compileError("todo");
}

fn span(comptime len: usize, buf: *const [len]u16) []const u16 {
    for (0..len) |i| {
        if (buf[i] == 0) return buf[0..i];
    }
    return buf;
}

pub fn fmtIn(device_index: u32) FmtIn {
    return FmtIn{ .device_index = device_index };
}
pub const FmtIn = struct {
    device_index: u32,
    pub fn format(f: *const FmtIn, writer: *std.Io.Writer) error{WriteFailed}!void {
        try writeIn(writer, f.device_index);
    }
};

pub fn writeIn(writer: *std.Io.Writer, device_index: u32) error{WriteFailed}!void {
    if (builtin.os.tag == .windows) {
        var caps: win32.MIDIINCAPSW = undefined;
        {
            const result = win32.midiInGetDevCapsW(device_index, &caps, @sizeOf(@TypeOf(caps)));
            if (result != win32.MMSYSERR_NOERROR) {
                try writer.print("midiInGetDevCaps failed, error={f}", .{mmsystem.fmtMmsyserr(result)});
                return;
            }
        }
        try writer.print("'{f}' Mid={} Pid={} DriverVer={} Support={}", .{
            std.unicode.fmtUtf16Le(span(32, @alignCast(&caps.szPname))),
            caps.wMid,
            caps.wPid,
            caps.vDriverVersion,
            caps.dwSupport,
        });
        return;
    }
    @compileError("todo");
}

const builtin = @import("builtin");
const std = @import("std");
const win32 = @import("win32").everything;

const mmsystem = @import("mmsystem.zig");
