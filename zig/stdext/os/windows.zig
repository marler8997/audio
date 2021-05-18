pub const kernel32 = @import("./windows/kernel32.zig");

pub const consoleapi = @import("./windows/consoleapi.zig");
pub const winuser = @import("./windows/winuser.zig");

//
//
//
const std = @import("std");

pub fn LOBYTE(value: std.os.windows.WORD)  std.os.windows.BYTE
{ return @intCast(std.os.windows.BYTE, 0xff & value); }
pub fn HIBYTE(value: std.os.windows.WORD)  std.os.windows.BYTE
{ return @intCast(std.os.windows.BYTE, 0xff & (value >> 8)); }
pub fn LOWORD(value: std.os.windows.DWORD) std.os.windows.WORD
{ return @intCast(std.os.windows.WORD, 0xffff & value); }
pub fn HIWORD(value: std.os.windows.DWORD) std.os.windows.WORD
{ return @intCast(std.os.windows.WORD, 0xffff & (value >> 16)); }
