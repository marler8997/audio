const win32 = @import("win32");

// This type is not generated in zigwin32 yet because it uses a nested type
pub const WAVEFORMATEXTENSIBLE  = extern struct {
    Format : win32.media.multimedia.WAVEFORMATEX,
    //Samples : extern union {
    //    wValidBitsPerSample : u16,
    //    wSamplesPerBlock : u16,
    //    wReserved : u16,
    //},
    wValidBitsPerSample : u16, // TODO: use the actual union
    dwChannelMask : u32,
    SubFormat : win32.zig.Guid,
};
