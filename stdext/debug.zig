const std = @import("std");

pub fn dumpData(comptime prefix: []const u8, data: []u8) void {
    for (data) |byte, index | {
        std.debug.warn(prefix ++ "[{}] = {}\n", index, byte);
    }
}
pub fn ptrData(data: anytype) []u8 {
    return @ptrCast([*]u8, data)[0 .. @sizeOf(@TypeOf(data.*))];
}
