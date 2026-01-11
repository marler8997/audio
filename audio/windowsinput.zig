const std = @import("std");
const inputlog = std.log.scoped(.input);

const win32 = @import("win32").everything;
const win32fix = @import("win32fix.zig");

const audio = @import("../audio.zig");

pub const KEY_ESCAPE = win32.VK_ESCAPE;

pub const ConsoleMode = struct {
    oldValue: win32.CONSOLE_MODE,
    pub fn setup() !ConsoleMode {
        const stdin = std.fs.File.stdin();

        var mode: ConsoleMode = undefined;
        if (0 == win32.GetConsoleMode(stdin.handle, &mode.oldValue)) {
            inputlog.err("Error: GetConsoleMode failed, e={f}", .{win32.GetLastError()});
            return error.Unexpected;
        }
        var newMode = mode.oldValue;
        const flags_to_disable: win32.CONSOLE_MODE = .{
            .ENABLE_ECHO_INPUT = 1, // disable echo
            .ENABLE_LINE_INPUT = 1, // disable line input, we want characters immediately
            .ENABLE_PROCESSED_INPUT = 1, // we'll handle CTL-C so we can cleanup and reset the console mode
        };
        newMode = @bitCast(@as(u32, @bitCast(newMode)) & ~@as(u32, @bitCast(flags_to_disable)));
        inputlog.info("Current console mode 0x{x}, setting to 0x{x}", .{
            @as(u32, @bitCast(mode.oldValue)),
            @as(u32, @bitCast(newMode)),
        });

        if (0 == win32.SetConsoleMode(stdin.handle, newMode)) {
            inputlog.err("Error: SetConsoleMode failed, error={f}", .{win32.GetLastError()});
            return error.Unexpected;
        }
        return mode;
    }
    pub fn restore(self: *ConsoleMode) void {
        const stdin = std.fs.File.stdin();
        if (0 == win32.SetConsoleMode(stdin.handle, self.oldValue)) {
            inputlog.err("SetConsoleMode failed, error={f}", .{win32.GetLastError()});
            //return error.Unexpected;
        }
    }
};

pub fn InputEvents(comptime maxSize: comptime_int) type {
    return struct {
        // align(@typeInfo([*]win32fix.INPUT_RECORD).Pointer.alignment)
        buffer: [maxSize]InputEvent,
        pub fn init() @This() {
            return @This(){
                .buffer = undefined,
            };
        }
        pub fn read(self: *@This()) ![]InputEvent {
            const stdin = std.fs.File.stdin();
            var inputCount: u32 = undefined;
            if (0 == win32.ReadConsoleInputA(stdin.handle, @ptrCast(&self.buffer[0]), maxSize, &inputCount)) {
                inputlog.err("Error: ReadConsoleInput failed, error={f}", .{win32.GetLastError()});
                return error.Unexpected;
            }
            inputlog.debug("got {} input events!", .{inputCount});
            return self.buffer[0..inputCount];
        }
    };
}

comptime {
    std.debug.assert(@sizeOf(InputEvent) == @sizeOf(win32fix.INPUT_RECORD));
    std.debug.assert(@sizeOf(InputEvent.KeyEvent) == @sizeOf(win32fix.INPUT_RECORD));
}
const InputEvent = extern union {
    record: win32fix.INPUT_RECORD,
    key_event: KeyEvent,

    pub fn getEventType(self: *const InputEvent) u32 {
        return self.record.EventType;
    }
    pub fn isKeyEvent(self: *InputEvent) ?KeyEvent {
        return if (self.record.EventType == win32.KEY_EVENT)
            self.key_event
        else
            null;
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
