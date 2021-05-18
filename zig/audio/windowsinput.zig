const std = @import("std");
const inputlog = std.log.scoped(.input);

const win32 = @import("win32");
usingnamespace win32.system.diagnostics.debug;
usingnamespace win32.system.console;
usingnamespace win32.ui.windows_and_messaging;
const win32fix = @import("win32fix.zig");

const audio = @import("../audio.zig");


pub const KEY_ESCAPE = VK_ESCAPE;

pub const ConsoleMode = struct {
    oldValue: CONSOLE_MODE,
    pub fn setup() !ConsoleMode {
        var stdin = std.io.getStdIn();

        var mode : ConsoleMode = undefined;
        if(0 == GetConsoleMode(stdin.handle, &mode.oldValue))
        {
            inputlog.err("Error: GetConsoleMode failed, e={}", .{GetLastError()});
            return error.Unexpected;
        }
        var newMode = mode.oldValue;
        // workaround error: unable to perform binary not operation on type 'comptime_int'
        const flagsToDisable : u32 =
            @enumToInt(ENABLE_ECHO_INPUT)       // disable echo
            | @enumToInt(ENABLE_LINE_INPUT)       // disable line input, we want characters immediately
            | @enumToInt(ENABLE_PROCESSED_INPUT); // we'll handle CTL-C so we can cleanup and reset the console mode
        newMode = @intToEnum(CONSOLE_MODE, @enumToInt(newMode) & ~flagsToDisable);
        inputlog.info("Current console mode 0x{x}, setting to 0x{x}", .{mode.oldValue, newMode});

        if(0 == SetConsoleMode(stdin.handle, newMode))
        {
            inputlog.err("Error: SetConsoleMode failed, e={}", .{GetLastError()});
            return error.Unexpected;
        }
        return mode;
    }
    pub fn restore(self: *ConsoleMode) void {
        var stdin = std.io.getStdIn();
        if (0 == SetConsoleMode(stdin.handle, self.oldValue)) {
            inputlog.err("SetConsoleMode failed, e={}", .{GetLastError()});
            //return error.Unexpected;
        }
    }
};

pub fn InputEvents(comptime maxSize: comptime_int) type {
    return struct {
        // align(@typeInfo([*]win32fix.INPUT_RECORD).Pointer.alignment)
        buffer: [maxSize]InputEvent,
        pub fn init() @This() {
            return @This() {
                .buffer = undefined,
            };
        }
        pub fn read(self: *@This()) ![]InputEvent {
            var stdin = std.io.getStdIn();
            var inputCount : u32 = undefined;
            if(0 == ReadConsoleInputA(
                stdin.handle, @ptrCast([*]INPUT_RECORD, &self.buffer[0]), maxSize, &inputCount))
            {
                inputlog.err("Error: ReadConsoleInput failed, e={}", .{GetLastError()});
                return error.Unexpected;
            }
            inputlog.debug("got {} input events!", .{inputCount});
            return self.buffer[0 .. inputCount];
        }
    };
}

comptime {
    std.debug.assert(@sizeOf(InputEvent) == @sizeOf(win32fix.INPUT_RECORD));
    std.debug.assert(@sizeOf(InputEvent.KeyEvent) == @sizeOf(win32fix.INPUT_RECORD));
}
const InputEvent = extern union {
    Record: win32fix.INPUT_RECORD,
    KeyEvent : KeyEvent,

    pub fn getEventType(self: *const InputEvent) u32 {
        return self.Record.EventType;
    }
    pub fn isKeyEvent(self: *InputEvent) ?KeyEvent {
        return if (self.Record.EventType == KEY_EVENT)
            self.KeyEvent else null;
    }
    pub const KeyEvent = extern struct {
        Record: win32fix.INPUT_RECORD,
        pub fn getKeyCode(self: *const KeyEvent) u32 {
            return self.Record.Event.KeyEvent.wVirtualKeyCode;
        }
        pub fn getKeyDown(self: *const KeyEvent) bool {
            return self.Record.Event.KeyEvent.bKeyDown != 0;
        }
    };
};
