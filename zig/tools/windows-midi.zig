const std = @import("std");
const win32 = struct {
    usingnamespace @import("win32").media.audio;
};

pub fn main() !void {
    const in_num_devs = win32.midiInGetNumDevs();
    std.log.info("midiInGetNumDevs={}", .{in_num_devs});

    const out_num_devs = win32.midiOutGetNumDevs();
    std.log.info("midiOutGetNumDevs={}", .{out_num_devs});
}
