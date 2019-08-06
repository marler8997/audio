const std = @import("std");

usingnamespace std.os.windows;

pub extern "kernel32" stdcallcc fn CreateEventA(
    lpSecurityAttributes: ?LPSECURITY_ATTRIBUTES,
    bManualReset: BOOL,
    bInitialState: BOOL,
    lpName: ?LPCSTR
) HANDLE;

pub extern "kernel32" stdcallcc fn ResetEvent(hEvent: HANDLE) BOOL;
pub extern "kernel32" stdcallcc fn SetEvent(hEvent: HANDLE) BOOL;

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

pub extern "kernel32" stdcallcc fn GetConsoleMode(
    hConsoleHandle : HANDLE,
    lpMode: *DWORD
) BOOL;
pub extern "kernel32" stdcallcc fn SetConsoleMode(
    hConsoleHandle : HANDLE,
    dwMode: DWORD
) BOOL;
pub extern "kernel32" stdcallcc fn ReadConsoleInputA(
    hConsoleInput : HANDLE,
    lpBuffer: [*]INPUT_RECORD,
    nLength: DWORD,
    lpNumberOfEventsRead: *DWORD,
) BOOL;