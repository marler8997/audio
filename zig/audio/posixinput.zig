const std = @import("std");

pub const ConsoleMode = struct {
    pub fn setup() anyerror!ConsoleMode {
        return ConsoleMode { };
    }
    pub fn restore(self: *ConsoleMode) void {
        _ = self;
    }
};

pub fn InputEvents(comptime maxSize: comptime_int) type {
    _ = maxSize;
    return struct {
        pub fn init() @This() {
            return @This() {
            };
        }
        pub fn read(self: *@This()) ![]InputEvent {
            _ = self;
            _ = std.os.linux.syscall0(std.os.linux.SYS_pause);
            return error.NotImplemented;
        }
    };
}

pub const KEY_ESCAPE = 0;

const InputEvent = packed union {
    //Record: INPUT_RECORD,
    KeyEvent : KeyEvent,

    pub fn getEventType(self: *const InputEvent) u32 {
        _ = self;
        return 0;
        //return self.Record.EventType;
    }
    pub fn isKeyEvent(self: *InputEvent) ?KeyEvent {
        _ = self;
        return null;
        //return if (self.Record.EventType == stdext.os.windows.kernel32.KEY_EVENT)
        //    self.KeyEvent else null;
    }
    pub const KeyEvent = struct {
        //Record: INPUT_RECORD,
        pub fn getKeyCode(self: *const KeyEvent) u32 {
            _ = self;
            //return self.Record.Event.KeyEvent.wVirtualKeyCode;
            return 0;
        }
        pub fn getKeyDown(self: *const KeyEvent) bool {
            _ = self;
            //return self.Record.Event.KeyEvent.bKeyDown != 0;
            return true;
        }
    };
};
