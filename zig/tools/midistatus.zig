const std = @import("std");
const win32 = struct {
    usingnamespace @import("win32").media;
    usingnamespace @import("win32").media.audio;
};

const audio = @import("audio");
const mmsystem = audio.windows.mmsystem;

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

pub fn main() !u8 {
    const all_cmd_args = try std.process.argsAlloc(allocator);
    // no need to free

    var verbose = false;
    for (all_cmd_args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--verbose")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try std.io.getStdErr().writer().print("Usage: midistatus [--verbose]\n", .{});
            return 0xff;
        } else {
            std.log.err("unknown command-line argument '{s}'", .{arg});
            return 0xff;
        }
    }

    const stdout = std.io.getStdOut().writer();

    const in_num_devs = win32.midiInGetNumDevs();
    {
        var i: u32 = 0;
        while (i < in_num_devs) : (i += 1) {
            var caps: win32.MIDIINCAPS = undefined;
            const result = win32.midiInGetDevCaps(i, &caps, @sizeOf(@TypeOf(caps)));
            if (result == win32.MMSYSERR_NOERROR) {
                try stdout.print("Input {}: {}\n", .{i, fmtMidiInCaps(&caps, verbose)});
            } else {
                try stdout.print("Input {}: midiInGetDevCaps failed, error={}\n", .{i, mmsystem.fmtMmsyserr(result)});
            }
        }
    }

    const out_num_devs = win32.midiOutGetNumDevs();
    {
        var i: u32 = 0;
        while (i < out_num_devs) : (i += 1) {
            var caps: win32.MIDIOUTCAPS = undefined;
            const result = win32.midiOutGetDevCaps(i, &caps, @sizeOf(@TypeOf(caps)));
            if (result == win32.MMSYSERR_NOERROR) {
                try stdout.print("Output {}: {}\n", .{i, fmtMidiOutCaps(&caps, verbose)});
            } else {
                try stdout.print("Output {}: midiOutGetDevCaps failed, error={}\n", .{i, mmsystem.fmtMmsyserr(result)});
            }
        }
    }
    return 0;
}

pub fn fmtMidiInCaps(caps: *win32.MIDIINCAPS, verbose: bool) MidiInCapsFormatter {
    return .{ .caps = caps, .verbose = verbose };
}
const MidiInCapsFormatter = struct {
    caps: *win32.MIDIINCAPS,
    verbose: bool,
    pub fn format(
        self: MidiInCapsFormatter,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        {
            // TODO: add support for non-unicode
            std.debug.assert(@TypeOf(self.caps.szPname) == [32]u16);
            const name_ptr: [*:0]u16 = @alignCast(2, @ptrCast([*:0]align(1) u16, &self.caps.szPname));
            const name_slice = std.mem.span(name_ptr);
            try writer.print("\"{s}\"", .{std.unicode.fmtUtf16le(name_slice)});
        }
        if (self.verbose) {
            try writer.print(" Mid={} Pid={} DriverVer={} Support={}", .{
                self.caps.wMid,
                self.caps.wPid,
                self.caps.vDriverVersion,
                self.caps.dwSupport,
            });
        }
    }
};

pub fn fmtMidiOutCaps(caps: *win32.MIDIOUTCAPS, verbose: bool) MidiOutCapsFormatter {
    return .{ .caps = caps, .verbose = verbose };
}
const MidiOutCapsFormatter = struct {
    caps: *win32.MIDIOUTCAPS,
    verbose: bool,
    pub fn format(
        self: MidiOutCapsFormatter,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        {
            // TODO: add support for non-unicode
            std.debug.assert(@TypeOf(self.caps.szPname) == [32]u16);
            const name_ptr: [*:0]u16 = @alignCast(2, @ptrCast([*:0]align(1) u16, &self.caps.szPname));
            const name_slice = std.mem.span(name_ptr);
            try writer.print("\"{s}\"", .{std.unicode.fmtUtf16le(name_slice)});
        }
        if (self.verbose) {
            try writer.print(" Mid={} Pid={} DriverVer={} Technology={} Voices={} Notes={} ChannelMask=0x{x} Support={}", .{
                self.caps.wMid,
                self.caps.wPid,
                self.caps.vDriverVersion,
                self.caps.wTechnology,
                self.caps.wVoices,
                self.caps.wNotes,
                self.caps.wChannelMask,
                self.caps.dwSupport,
            });
        }
    }
};
