const std = @import("std");
const win32 = struct {
    usingnamespace @import("win32").media;
};

pub fn fmtMmsyserr(error_code: u32)  MmsyserrFormatter {
    return .{ .error_code = error_code };
}
const MmsyserrFormatter = struct {
    error_code: u32,
    pub fn format(
        self: MmsyserrFormatter,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const name =  mmsyserrorName(self.error_code) orelse @as([]const u8, "?");
        try writer.print("{d}({s})", .{self.error_code, name});
    }
};

pub fn mmsyserrorName(error_code: u32) ?[]const u8 {
    return switch (error_code) {
        win32.MMSYSERR_NOERROR => "NOERROR",
        win32.MMSYSERR_ERROR => "ERROR",
        win32.MMSYSERR_BADDEVICEID => "BADDEVICEID",
        win32.MMSYSERR_NOTENABLED => "NOTENABLED",
        win32.MMSYSERR_ALLOCATED => "ALLOCATED",
        win32.MMSYSERR_INVALHANDLE => "INVALHANDLE",
        win32.MMSYSERR_NODRIVER => "NODRIVER",
        win32.MMSYSERR_NOMEM => "NOMEM",
        win32.MMSYSERR_NOTSUPPORTED => "NOTSUPPORTED",
        win32.MMSYSERR_BADERRNUM => "BADERRNUM",
        win32.MMSYSERR_INVALFLAG => "INVALFLAG",
        win32.MMSYSERR_INVALPARAM => "INVALPARAM",
        win32.MMSYSERR_HANDLEBUSY => "HANDLEBUSY",
        win32.MMSYSERR_INVALIDALIAS => "INVALIDALIAS",
        win32.MMSYSERR_BADDB => "BADDB",
        win32.MMSYSERR_KEYNOTFOUND => "KEYNOTFOUND",
        win32.MMSYSERR_READERROR => "READERROR",
        win32.MMSYSERR_WRITEERROR => "WRITEERROR",
        win32.MMSYSERR_DELETEERROR => "DELETEERROR",
        win32.MMSYSERR_VALNOTFOUND => "VALNOTFOUND",
        win32.MMSYSERR_NODRIVERCB => "NODRIVERCB",
        win32.MMSYSERR_MOREDATA => "MOREDATA",
        else => null,
    };
}
