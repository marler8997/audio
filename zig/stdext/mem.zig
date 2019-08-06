const std = @import("std");

pub fn set(dest: var, value: var) void {
    std.mem.set(@typeOf(dest[0]), dest, value);
}

pub fn secureZero(s: var) void {
    std.mem.secureZero(@typeOf(s[0]), s);
}
