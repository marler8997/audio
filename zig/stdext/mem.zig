const std = @import("std");

pub fn set(dest: anytype, value: anytype) void {
    std.mem.set(@TypeOf(dest[0]), dest, value);
}
