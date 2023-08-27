pub const waveout = @import("./backend/waveout.zig");
//pub const wasapi = @import("./backend/wasapi.zig");
//pub const alsa = @import("./backend/alsa.zig");

const audio = @import("../audio.zig");
const SamplePoint = audio.renderformat.SamplePoint;

pub const BackendFuncs = struct {
    setup : *const fn() anyerror!void,
    startingRenderLoop : *const fn() anyerror!void,
    stoppingRenderLoop : *const fn() anyerror!void,
    writeFirstBuffer: *const fn(renderBuffer: [*]const SamplePoint) anyerror!void,
    writeBuffer: *const fn(renderBuffer: [*]const SamplePoint) anyerror!void,
};
