const builtin = @import("builtin");
const WINAPI = @import("std").os.windows.WINAPI;
const BOOL = i32;

// TODO: I don't think Zig supports dynamic extern strings, so for now I'm hardcoding to "teVirtualMIDI64"
//const te_virtual_lib = if (builtin.cpu.arch.ptrBitWidth() == 64) "teVirtualMIDI64" else "teVirtualMIDI32";

pub const TE_VM_LOGGING_MISC = 0x01;
pub const TE_VM_LOGGING_RX    = 0x02;
pub const TE_VM_LOGGING_TX = 0x04;
pub const TE_VM_DEFAULT_BUFFER_SIZE = 0x1fffe;

pub const TE_VM_FLAGS_PARSE_RX            = 0x01;
pub const TE_VM_FLAGS_PARSE_TX            = 0x02;
pub const TE_VM_FLAGS_INSTANTIATE_RX_ONLY = 0x04;
pub const TE_VM_FLAGS_INSTANTIATE_TX_ONLY = 0x08;
pub const TE_VM_FLAGS_INSTANTIATE_BOTH    = TE_VM_FLAGS_INSTANTIATE_TX_ONLY | TE_VM_FLAGS_INSTANTIATE_RX_ONLY;
pub const TE_VM_FLAGS_SUPPORTED           = TE_VM_FLAGS_PARSE_RX | TE_VM_FLAGS_PARSE_TX | TE_VM_FLAGS_INSTANTIATE_RX_ONLY | TE_VM_FLAGS_INSTANTIATE_TX_ONLY;

pub const VM_MIDI_PORT = opaque{};

pub const VM_MIDI_DATA_CB = fn(
    midi_port: *VM_MIDI_PORT,
    data: [*]u8,
    len: u32,
    callback: usize,
) callconv(WINAPI) void;

pub extern "teVirtualMIDI64" fn virtualMIDICreatePortEx2(
    port_name: [*:0]const u16,
    callback: ?VM_MIDI_DATA_CB,
    callback_data: usize,
    max_sysex_length: u32,
    flags: u32,
) callconv(WINAPI) ?*VM_MIDI_PORT;

//*VM_MIDI_PORT virtualMIDICreatePortEx3( LPCWSTR portName,  VM_MIDI_DATA_CB callback, DWORD_PTR dwCallbackInstance, DWORD maxSysexLength, DWORD flags, GUID *manufacturer, GUID *product );

pub extern "teVirtualMIDI64" fn virtualMIDIClosePort(port: *VM_MIDI_PORT) callconv(WINAPI) void;

pub extern "teVirtualMIDI64" fn virtualMIDISendData(
    midi_port: *VM_MIDI_PORT,
    data: [*]const u8,
    len: u32,
) callconv(WINAPI) BOOL;

pub extern "teVirtualMIDI64" fn virtualMIDIGetData(
    midi_port: *VM_MIDI_PORT,
    data: [*]u8,
    len: *u32,
) callconv(WINAPI) BOOL;

//BOOL virtualMIDIGetProcesses( *VM_MIDI_PORT midiPort, ULONG64 *processIds, PDWORD length );
//BOOL virtualMIDIShutdown( *VM_MIDI_PORT midiPort );

pub extern "teVirtualMIDI64" fn virtualMIDIGetVersion(
    major: *u16,
    minor: *u16,
    release: *u16,
    build: *u16,
) callconv(WINAPI) [*:0]u16;

pub extern "teVirtualMIDI64" fn virtualMIDIGetDriverVersion(
    major: *u16,
    minor: *u16,
    release: *u16,
    build: *u16,
) callconv(WINAPI) [*:0]u16;

//DWORD virtualMIDILogging( DWORD logMask );
