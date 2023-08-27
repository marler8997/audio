const std = @import("std");

pub fn dumpData(comptime prefix: []const u8, data: []u8) void {
    for (data, 0..) |byte, index| {
        std.log.info(prefix ++ "[{}] = {}\n", .{index, byte});
    }
}
pub fn ptrData(data: anytype) []u8 {
    return @as([*]u8, @ptrCast(data))[0 .. @sizeOf(@TypeOf(data.*))];
}
