const std = @import("std");
const win32 = @import("win32");

usingnamespace win32.media.multimedia;

pub fn main() !void {
    const in_num_devs = midiInGetNumDevs();
    std.log.info("midiInGetNumDevs={}", .{in_num_devs});

    const out_num_devs = midiOutGetNumDevs();
    std.log.info("midiOutGetNumDevs={}", .{out_num_devs});
}
