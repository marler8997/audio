const stdext = @import("stdext");

const audio = @import("../audio.zig");
const SamplePoint = audio.renderformat.SamplePoint;
const RenderFormat = audio.renderformat.RenderFormat;
const OutputNode = audio.dag.OutputNode;
const AudioGenerator = audio.dag.AudioGenerator;

fn sawFrequencyToIncrement(frequency: f32) f32 {
    return frequency / @intToFloat(f32, audio.global.sampleFramesPerSec);
}

pub const SawGenerator = struct {
    generator: AudioGenerator,
    //frequency : f32,
    volume : f32,
    nextSamplePoint : f32,
    increment : f32,
    pub fn init(frequency: f32, volume: f32) SawGenerator {
        return SawGenerator {
            .generator = AudioGenerator {
                .mix = mix,
                .connectOutputNode = connectOutputNode,
                .disconnectOutputNode = disconnectOutputNode,
                .renderFinished = renderFinished,
            },
            .volume = volume,
            .nextSamplePoint = 0,
            .increment = sawFrequencyToIncrement(frequency),
        };
    }
    fn connectOutputNode(base: *AudioGenerator, outputNode: *OutputNode) anyerror!void {
        //var self = @fieldParentPtr(SawGenerator, "generator", base);
        _ = base;
        _ = outputNode;
    }
    fn disconnectOutputNode(base: *AudioGenerator, outputNode: *OutputNode) anyerror!void {
        //var self = @fieldParentPtr(SawGenerator, "generator", base);
        _ = base;
        _ = outputNode;
    }
    fn mix(base: *AudioGenerator, channels: []u8, bufferStart: [*]SamplePoint, bufferLimit: [*]SamplePoint) anyerror!void {
        var self = @fieldParentPtr(SawGenerator, "generator", base);
        var buffer = bufferStart;
        while(stdext.limitarray.ptrLessThan(buffer, bufferLimit)) : (buffer += channels.len) {
            const samplePoint = RenderFormat.f32ToSamplePoint(
                self.volume * RenderFormat.MaxAmplitudeF32 * self.nextSamplePoint * 0.5);
            audio.render.addToEachChannel(channels, buffer, samplePoint);
            self.nextSamplePoint += self.increment;
            if (self.nextSamplePoint >= 0.99)
                self.nextSamplePoint = -0.99;
        }
    }
    fn renderFinished(base: *AudioGenerator, outputNode: *OutputNode) anyerror!void {
        //var self = @fieldParentPtr(SawGenerator, "generator", base);
        _ = base;
        _ = outputNode;
    }
};
