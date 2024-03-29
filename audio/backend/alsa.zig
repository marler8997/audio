const audio = @import("../../audio.zig");
const SamplePoint = audio.renderformat.SamplePoint;

pub const funcs = audio.backend.BackendFuncs {
    .setup = notImpl,
    .startingRenderLoop = notImpl,
    .stoppingRenderLoop = notImpl,
    .writeFirstBuffer = writeBufferNotImpl,
    .writeBuffer = writeBufferNotImpl,
};

fn notImpl() anyerror!void {
    return error.NotImplemented;
}
fn writeBufferNotImpl(renderBuffer: [*]const SamplePoint) anyerror!void {
    _ = renderBuffer;
    return error.NotImplemented;
}
