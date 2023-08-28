pub const waveout = @import("./backend/waveout.zig");
//pub const wasapi = @import("./backend/wasapi.zig");
//pub const alsa = @import("./backend/alsa.zig");

const audio = @import("../audio.zig");
const SamplePoint = audio.renderformat.SamplePoint;

pub const BackendFuncs = struct {
    setup : fn() anyerror!void,
    startingRenderLoop : fn() anyerror!void,
    stoppingRenderLoop : fn() anyerror!void,
    writeFirstBuffer: fn(renderBuffer: [*]const SamplePoint) anyerror!void,
    writeBuffer: fn(renderBuffer: [*]const SamplePoint) anyerror!void,
};
