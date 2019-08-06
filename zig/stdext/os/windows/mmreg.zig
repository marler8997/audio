const std = @import("std");
usingnamespace std.os.windows;

const stdext = @import("../stdext.zig");

pub const WAVEFORMATEX = packed struct {
    wFormatTag: WORD,
    nChannels: WORD,
    nSamplesPerSec: DWORD,
    nAvgBytesPerSec: DWORD,
    nBlockAlign: WORD,
    wBitsPerSample: WORD,
    cbSize: WORD,
};
comptime {
    std.debug.assert(@sizeOf(WAVEFORMATEX) == 18);
}

pub const WAVEFORMATEXTENSIBLE  = extern struct {
    Format : WAVEFORMATEX,
    //Samples : extern union {
    //    wValidBitsPerSample : WORD,
    //    wSamplesPerBlock : WORD,
    //    wReserved : WORD,
    //},
    wValidBitsPerSample : WORD, // TODO: use the actual union
    dwChannelMask : DWORD,
    SubFormat : GUID,
};

pub const SPEAKER_FRONT_LEFT            = 0x00001;
pub const SPEAKER_FRONT_RIGHT           = 0x00002;
pub const SPEAKER_FRONT_CENTER          = 0x00004;
pub const SPEAKER_LOW_FREQUENCY         = 0x00008;
pub const SPEAKER_BACK_LEFT             = 0x00010;
pub const SPEAKER_BACK_RIGHT            = 0x00020;
pub const SPEAKER_FRONT_LEFT_OF_CENTER  = 0x00040;
pub const SPEAKER_FRONT_RIGHT_OF_CENTER = 0x00080;
pub const SPEAKER_BACK_CENTER           = 0x00100;
pub const SPEAKER_SIDE_LEFT             = 0x00200;
pub const SPEAKER_SIDE_RIGHT            = 0x00400;
pub const SPEAKER_TOP_CENTER            = 0x00800;
pub const SPEAKER_TOP_FRONT_LEFT        = 0x01000;
pub const SPEAKER_TOP_FRONT_CENTER      = 0x02000;
pub const SPEAKER_TOP_FRONT_RIGHT       = 0x04000;
pub const SPEAKER_TOP_BACK_LEFT         = 0x08000;
pub const SPEAKER_TOP_BACK_CENTER       = 0x10000;
pub const SPEAKER_TOP_BACK_RIGHT        = 0x20000;


//pub const KSDATAFORMAT_SUBTYPE_PCM = ???;
pub const KSDATAFORMAT_SUBTYPE_IEEE_FLOAT = GUID.parse("{00000003-0000-0010-8000-00AA00389B71}");
