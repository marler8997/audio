const std = @import("std");
const stdext = @import("stdext");

const mmsystem = stdext.os.windows.mmsystem;

pub fn main() !void {
    const in_num_devs = mmsystem.midiInGetNumDevs();
    std.log.info("midiInGetNumDevs={}", .{in_num_devs});

    const out_num_devs = mmsystem.midiOutGetNumDevs();
    std.log.info("midiOutGetNumDevs={}", .{out_num_devs});
}
