const std = @import("std");
const win32 = struct {
    usingnamespace @import("win32").media;
    usingnamespace @import("win32").media.audio;
};

const audio = @import("audio");
const mmsystem = audio.windows.mmsystem;

pub fn main() !void {
    const in_num_devs = win32.midiInGetNumDevs();
    std.log.info("midiInGetNumDevs={}", .{in_num_devs});
    {
        var i: u32 = 0;
        while (i < in_num_devs) : (i += 1) {
            var caps: win32.MIDIINCAPS = undefined;
            const result = win32.midiInGetDevCaps(i, &caps, @sizeOf(@TypeOf(caps)));
            if (result == win32.MMSYSERR_NOERROR) {
                std.log.info("    {}: {}", .{i, caps});
            } else {
                std.log.err("     {}: midiInGetDevCaps failed, error={}", .{i, mmsystem.fmtMmsyserr(result)});
            }
        }
    }

    const out_num_devs = win32.midiOutGetNumDevs();
    std.log.info("midiOutGetNumDevs={}", .{out_num_devs});
    {
        var i: u32 = 0;
        while (i < out_num_devs) : (i += 1) {
            var caps: win32.MIDIOUTCAPS = undefined;
            const result = win32.midiOutGetDevCaps(i, &caps, @sizeOf(@TypeOf(caps)));
            if (result == win32.MMSYSERR_NOERROR) {
                std.log.info("    {}: {}", .{i, fmtMidiOutCaps(&caps)});
            } else {
                std.log.err("     {}: midiOutGetDevCaps failed, error={}", .{i, mmsystem.fmtMmsyserr(result)});
            }
        }
    }
}

pub fn fmtMidiOutCaps(caps: *win32.MIDIOUTCAPS) MidiOutCapsFormatter {
    return .{ .caps = caps };
}
const MidiOutCapsFormatter = struct {
    caps: *win32.MIDIOUTCAPS,
    pub fn format(
        self: MidiOutCapsFormatter,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("ManufacturerId: {}, ProductId: {}, DriverVersion: {}, ", .{
            self.caps.wMid,
            self.caps.wPid,
            self.caps.vDriverVersion,
        });
        {
            // TODO: add support for non-unicode
            std.debug.assert(@TypeOf(self.caps.szPname) == [32]u16);
            const name_ptr: [*:0]u16 = @alignCast(2, @ptrCast([*:0]align(1) u16, &self.caps.szPname));
            const name_slice = std.mem.span(name_ptr);
            try writer.print("ProductName: \"{s}\", ", .{std.unicode.fmtUtf16le(name_slice)});
        }
        try writer.print("Technology: {}, Voices: {}, Notes: {}, ChannelMask: 0x{x}, Support: {}", .{
            self.caps.wTechnology,
            self.caps.wVoices,
            self.caps.wNotes,
            self.caps.wChannelMask,
            self.caps.dwSupport,
        });
    }
};
