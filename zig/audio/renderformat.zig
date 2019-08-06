
const stdext = @import("../stdext.zig");

const options = @import("./renderformat/options.zig");

pub const RenderFormatType  = enum {
    pcm16,
    float32,
};

pub const RenderFormatError = error {
    UnupportedRenderFormat,
};

//pub const RenderFormat = options.pcm16;
pub const RenderFormat = options.float32;
pub const SamplePoint = RenderFormat.SamplePoint;

//pub const RenderBuffer = struct {
//    array: stdext.LimitArray(SamplePoint),
//    pub fn fromArray(array: []SamplePoint) @This() {
//        return @This() {
//            .array = stdext.LimitArray.fromArray(array),
//        };
//    }
//    pub fn ptr(self: @This()) [*]SamplePoint { return array.ptr; }
//    pub fn empty(self: *const @This()) bool { return self.array.empty(); }
//    pub fn popFrame(self: *RenderBuffer, channelCount: u8) void {
//        array.ptr += channelCount;
//    }
//};
