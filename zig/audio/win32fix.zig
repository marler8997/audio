const win32 = struct {
    usingnamespace @import("win32");
    usingnamespace @import("win32").foundation;
    usingnamespace @import("win32").system.system_services;
    usingnamespace @import("win32").media.audio;
};

// This type is not generated in zigwin32 yet because it uses a nested type
pub const KEY_EVENT_RECORD = extern struct {
    bKeyDown: win32.BOOL,
    wRepeatCount: u16,
    wVirtualKeyCode: u16,
    wVirtualScanCode: u16,
    uChar: extern union {
        UnicodeChar: u16,
        AsciiChar: win32.CHAR,
    },
    dwControlKeyState: u32,
};

pub const INPUT_RECORD = extern struct {
    EventType: u16,
    Event: extern union {
        KeyEvent: KEY_EVENT_RECORD,
        //MouseEvent: MOUSE_EVENT_RECORD,
        //WindowBufferSizeEvent: WINDOW_BUFFER_SIZE_RECORD,
        //MenuEvent: MENU_EVENT_RECORD,
        //FocusEvent: FOCUS_EVENT_RECORD,
    },
};

// This type is not generated in zigwin32 yet because it uses a nested type
pub const WAVEFORMATEXTENSIBLE  = extern struct {
    Format : win32.WAVEFORMATEX,
    //Samples : extern union {
    //    wValidBitsPerSample : u16,
    //    wSamplesPerBlock : u16,
    //    wReserved : u16,
    //},
    wValidBitsPerSample : u16, // TODO: use the actual union
    dwChannelMask : u32,
    SubFormat : win32.zig.Guid,
};
