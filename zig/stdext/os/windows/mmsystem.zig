const std = @import("std");
usingnamespace std.os.windows;

const stdext = @import("../../../stdext.zig");
usingnamespace stdext.os.windows.mmreg;

pub const HWAVEOUT = HANDLE;
pub const HMIDIIN = HANDLE;

pub const MMRESULT = UINT;

pub const MMSYSERR_NOERROR       : MMRESULT =  0;
pub const MMSYSERR_ERROR         : MMRESULT =  1;
pub const MMSYSERR_BADDEVICEID   : MMRESULT =  2;
pub const MMSYSERR_NOTENABLED    : MMRESULT =  3;
pub const MMSYSERR_ALLOCATED     : MMRESULT =  4;
pub const MMSYSERR_INVALHANDLE   : MMRESULT =  5;
pub const MMSYSERR_NODRIVER      : MMRESULT =  6;
pub const MMSYSERR_NOMEM         : MMRESULT =  7;
pub const MMSYSERR_NOTSUPPORTED  : MMRESULT =  8;
pub const MMSYSERR_BADERRNUM     : MMRESULT =  9;
pub const MMSYSERR_INVALFLAG     : MMRESULT = 10;
pub const MMSYSERR_INVALPARAM    : MMRESULT = 11;
pub const MMSYSERR_HANDLEBUSY    : MMRESULT = 12;
pub const MMSYSERR_INVALIDALIAS  : MMRESULT = 13;
pub const MMSYSERR_BADDB         : MMRESULT = 14;
pub const MMSYSERR_KEYNOTFOUND   : MMRESULT = 15;
pub const MMSYSERR_READERROR     : MMRESULT = 16;
pub const MMSYSERR_WRITEERROR    : MMRESULT = 17;
pub const MMSYSERR_DELETEERROR   : MMRESULT = 18;
pub const MMSYSERR_VALNOTFOUND   : MMRESULT = 19;
pub const MMSYSERR_NODRIVERCB    : MMRESULT = 20;
pub const WAVERR_BADFORMAT       : MMRESULT = 32;
pub const WAVERR_STILLPLAYING    : MMRESULT = 33;
pub const WAVERR_UNPREPARED      : MMRESULT = 34;

pub const WAVEHDR = extern struct {
    lpData: [*]u8,
    dwBufferLength: DWORD,
    dwBytesRecorded: DWORD,
    dwUser: DWORD_PTR,
    dwFlags: DWORD,
    dwLoops: DWORD,
    lpNext: *WAVEHDR,
    reserved: DWORD_PTR,
};

// TODO: use this type if I need a UINT* that can be assigned -1
//const OPTIONAL_UINTPTR = extern union {
//    ptr : *UINT,
//    value : isize,
//    fn initNull() @This() {
//        return @This() {
//            .value = -1,
//        };
//    }
//    fn init(ptr: *UINT) @This() {
//        return @This() {
//            .ptr = ptr,
//        };
//    }
//};

pub const WAVE_MAPPER : UINT = 0xFFFFFFFF;

pub const CALLBACK_FUNCTION = 0x30000;

pub const WOM_OPEN  = 0x3bb;
pub const WOM_CLOSE = 0x3bc;
pub const WOM_DONE  = 0x3bd;

pub const WIM_OPEN  = 0x3be;
pub const WIM_CLOSE = 0x3bf;
pub const WIM_DONE  = 0x3b0;

pub const MIM_OPEN      = 961;
pub const MIM_CLOSE     = 962;
pub const MIM_DATA      = 963;
pub const MIM_LONGDATA  = 964;
pub const MIM_ERROR     = 965;
pub const MIM_LONGERROR = 966;
pub const MIM_MOREDATA  = 972;

pub const MOM_OPEN      = 967;
pub const MOM_CLOSE     = 968;
pub const MOM_DONE      = 969;

pub extern "winmm" fn waveOutOpen(
    phwo: *HWAVEOUT,
    uDeviceID: UINT,
    pwfx: *WAVEFORMATEX,
    dwCallback: *const DWORD,
    dwCallbackInstance: ?*DWORD,
    fdwOpen: DWORD,
) callconv(.Stdcall) MMRESULT;

pub extern "winmm" fn waveOutClose(
    hwo: HWAVEOUT,
) callconv(.Stdcall) MMRESULT;

pub extern "winmm" fn waveOutPrepareHeader(
    hwo: HWAVEOUT,
    pwh: *const WAVEHDR,
    cbwh: UINT,
) callconv(.Stdcall) MMRESULT;

pub extern "winmm" fn waveOutUnprepareHeader(
    hwo: HWAVEOUT,
    pwh: *const WAVEHDR,
    cbwh: UINT,
) callconv(.Stdcall) MMRESULT;

pub extern "winmm" fn waveOutWrite(
    hwo: HWAVEOUT,
    pwh: *const WAVEHDR,
    cbwh: UINT,
) callconv(.Stdcall) MMRESULT;

pub extern "winmm" fn midiInOpen(
    lphMidiIn: *HMIDIIN,
    uDeviceID: UINT,
    dwCallback: *const DWORD,
    dwCallbackInstance: *DWORD,
    dwFlags: DWORD,
) callconv(.Stdcall) MMRESULT;

pub extern "winmm" fn midiInClose(
    hMidiIn: HMIDIIN,
) callconv(.Stdcall) MMRESULT;

pub extern "winmm" fn midiInStart(
    hMidiIn: HMIDIIN,
) callconv(.Stdcall) MMRESULT;

pub extern "winmm" fn midiInStop(
    hMidiIn: HMIDIIN,
) callconv(.Stdcall) MMRESULT;
