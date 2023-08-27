
// TODO: move this to win32
pub fn LOBYTE(val: anytype) u8 { return @intCast(u8, 0xFF & val); }
pub fn HIBYTE(val: anytype) u8 { return LOBYTE(val >> 8); }
pub fn LOWORD(val: anytype) u16 { return @intCast(u16, 0xFFFF & val); }
pub fn HIWORD(val: anytype) u16 { return LOWORD(val >> 16); }
