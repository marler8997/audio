const std = @import("std");

usingnamespace std.os.windows;

pub extern "kernel32" fn CreateEventA(
    lpSecurityAttributes: ?LPSECURITY_ATTRIBUTES,
    bManualReset: BOOL,
    bInitialState: BOOL,
    lpName: ?LPCSTR
) callconv(WINAPI) HANDLE;

pub extern "kernel32" fn ResetEvent(hEvent: HANDLE) callconv(WINAPI) BOOL;
pub extern "kernel32" fn SetEvent(hEvent: HANDLE) callconv(WINAPI) BOOL;

pub const FOCUS_EVENT = 0x0010;
pub const KEY_EVENT   = 0x0001;
pub const MENU_EVENT  = 0x0008;
pub const MOUSE_EVENT = 0x0002;
pub const WINDOW_BUFFER_SIZE_EVENT = 0x0004;

pub const KEY_EVENT_RECORD = extern struct {
    bKeyDown: BOOL,
    wRepeatCount: WORD,
    wVirtualKeyCode: WORD,
    wVirtualScanCode: WORD,
    uChar: extern union {
        UnicodeChar: WCHAR,
        AsciiChar: CHAR,
    },
    dwControlKeyState: DWORD,
};

pub const INPUT_RECORD = extern struct {
    EventType: WORD,
    Event: extern union {
        KeyEvent: KEY_EVENT_RECORD,
        //MouseEvent: MOUSE_EVENT_RECORD,
        //WindowBufferSizeEvent: WINDOW_BUFFER_SIZE_RECORD,
        //MenuEvent: MENU_EVENT_RECORD,
        //FocusEvent: FOCUS_EVENT_RECORD,
    },
};

pub extern "kernel32" fn GetConsoleMode(
    hConsoleHandle : HANDLE,
    lpMode: *DWORD
) callconv(WINAPI) BOOL;
pub extern "kernel32" fn SetConsoleMode(
    hConsoleHandle : HANDLE,
    dwMode: DWORD
) callconv(WINAPI) BOOL;
pub extern "kernel32" fn ReadConsoleInputA(
    hConsoleInput : HANDLE,
    lpBuffer: [*]INPUT_RECORD,
    nLength: DWORD,
    lpNumberOfEventsRead: *DWORD,
) callconv(WINAPI) BOOL;