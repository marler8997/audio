const std = @import("std");
usingnamespace std.os.windows;

const stdext = @import("../stdext.zig");
usingnamespace stdext.os.windows.consoleapi;
usingnamespace stdext.os.windows.winuser;
const INPUT_RECORD = stdext.os.windows.kernel32.INPUT_RECORD;

const audio = @import("../audio.zig");
usingnamespace audio.log;

pub const KEY_ESCAPE = VK_ESCAPE;

pub const ConsoleMode = struct {
    oldValue: DWORD,
    pub fn setup() !ConsoleMode {
        var stdin = try std.io.getStdIn();

        var mode : ConsoleMode = undefined;
        if(0 == stdext.os.windows.kernel32.GetConsoleMode(stdin.handle, &mode.oldValue))
        {
            logError("Error: GetConsoleMode failed, e={}", kernel32.GetLastError());
            return error.Unexpected;
        }
        var newMode = mode.oldValue;
        // workaround error: unable to perform binary not operation on type 'comptime_int'
        const flagsToDisable : DWORD =
            ENABLE_ECHO_INPUT       // disable echo
            | ENABLE_LINE_INPUT       // disable line input, we want characters immediately
            | ENABLE_PROCESSED_INPUT; // we'll handle CTL-C so we can cleanup and reset the console mode
        newMode &= ~flagsToDisable;
        log("Current console mode 0x{x}, setting to 0x{x}", mode.oldValue, newMode);

        if(0 == stdext.os.windows.kernel32.SetConsoleMode(stdin.handle, newMode))
        {
            logError("Error: SetConsoleMode failed, e={}", kernel32.GetLastError());
            return error.Unexpected;
        }
        return mode;
    }
    pub fn restore(self: *ConsoleMode) void {
        var stdin = std.io.getStdIn() catch unreachable;
        if (0 == stdext.os.windows.kernel32.SetConsoleMode(stdin.handle, self.oldValue)) {
            logError("SetConsoleMode failed, e={}", kernel32.GetLastError());
            //return error.Unexpected;
        }
    }
};

pub fn InputEvents(comptime maxSize: comptime_int) type {
    return struct {
        buffer: [maxSize]InputEvent,
        pub fn init() @This() {
            return @This() {
                .buffer = undefined,
            };
        }
        pub fn read(self: *@This()) ![]InputEvent {
            var stdin = try std.io.getStdIn();
            var inputCount : DWORD = undefined;
            if(0 == stdext.os.windows.kernel32.ReadConsoleInputA(
                stdin.handle, @ptrCast([*]INPUT_RECORD, &self.buffer), maxSize, &inputCount))
            {
                logError("Error: ReadConsoleInput failed, e={}", kernel32.GetLastError());
                return error.Unexpected;
            }
            logDebug("got {} input events!", inputCount);
            return self.buffer[0 .. inputCount];
        }
    };
}

comptime {
    std.debug.assert(@sizeOf(InputEvent) == @sizeOf(INPUT_RECORD));
    std.debug.assert(@sizeOf(InputEvent.KeyEvent) == @sizeOf(INPUT_RECORD));
}
const InputEvent = packed union {
    Record: INPUT_RECORD,
    KeyEvent : KeyEvent,

    pub fn getEventType(self: *const InputEvent) DWORD {
        return self.Record.EventType;
    }
    pub fn isKeyEvent(self: *InputEvent) ?KeyEvent {
        return if (self.Record.EventType == stdext.os.windows.kernel32.KEY_EVENT)
            self.KeyEvent else null;
    }
    pub const KeyEvent = struct {
        Record: INPUT_RECORD,
        pub fn getKeyCode(self: *const KeyEvent) DWORD {
            return self.Record.Event.KeyEvent.wVirtualKeyCode;
        }
        pub fn getKeyDown(self: *const KeyEvent) bool {
            return self.Record.Event.KeyEvent.bKeyDown != 0;
        }
    };
};
