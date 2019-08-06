const std = @import("std");

pub fn log(comptime fmt: []const u8, args: ...) void {
    std.debug.warn(fmt ++ "\n", args);
}
pub fn flushLog() void {
    //try std.debug.flush();
}

pub fn logError(comptime fmt: []const u8, args: ...) void {
    std.debug.warn("Error: " ++ fmt ++ "\n", args);
}
pub fn logDebug(comptime fmt: []const u8, args: ...) void {
    std.debug.warn("[DEBUG] " ++ fmt ++ "\n", args);
}
