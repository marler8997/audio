const std = @import("std");

// TODO: move this
pub fn isValidCall(func: anytype, args: anytype) bool {
    return true;
}
pub fn enforceValidCall(func: anytype, args: anytype) void {
    if (!isValidCall(func, args))
        @compileError("function signature '" ++ @typeName(@TypeOf(func)) ++ "' cannot be called with the given args");
}

fn OpaqueFn(comptime T: type) type {
    switch (@typeInfo(T)) {
        .Fn => |info| return @Type(std.builtin.TypeInfo { .Fn = .{
            .calling_convention = info.calling_convention,
            .alignment = info.alignment,
            .is_generic = info.is_generic,
            .is_var_args = info.is_var_args,
            .return_type = info.return_type,
            .args = [_]std.builtin.TypeInfo.FnArg {.{
                .is_generic = false,
                .is_noalias = false,
                .arg_type = usize,
            }} ++ info.args[1..],
        }}),
        else => @compileError("expected an Fn but got " ++ @typeName(@TypeOf(func))),
    }
}

pub const RenderFormatFloat32 = struct {
    pub const Sample = f32;
    pub fn addPositiveWithWrap(lhs: Sample, rhs: Sample) Sample {
        std.debug.assert(lhs >= -1.0 and lhs <= 1.0);
        std.debug.assert(rhs >= 0.0 and rhs <= 1.0);
        const sum = lhs + rhs;
        return if (sum <= 1.0) sum else (sum - 2.0);
    }
    pub fn scaleSample(sample: Sample, scale: f32) Sample {
        return sample * scale;
    }
};

pub fn Template(comptime Format: type) type { return struct {
    const Sample = Format.Sample;

    pub const Mix = struct {
        channels: []const u8,
        buffer_start: [*]Sample,
        buffer_limit: [*]Sample,
        pub const SampleRef = struct {
            channels: []const u8,
            buffer: [*]Sample,
            pub fn add(self: SampleRef, sample: Sample) void {
                for (self.channels) |channel| {
                    self.buffer[channel] += sample;
                }
            }
        };
        const SampleIterator = struct {
            mix: *Mix,
            next_buffer: [*]Sample,
            pub fn next(self: *SampleIterator) ?SampleRef {
                if (@ptrToInt(self.next_buffer) >= @ptrToInt(self.mix.buffer_limit)) {
                    std.debug.assert(self.next_buffer == self.mix.buffer_limit);
                    return null;
                }
                var ref = SampleRef { .channels = self.mix.channels, .buffer = self.next_buffer };
                self.next_buffer += self.mix.channels.len;
                return ref;
            }
        };
        pub fn sampleIterator(self: *Mix) SampleIterator {
            return SampleIterator { .mix = self, .next_buffer = self.buffer_start };
        }
    };

    pub const singlestep = struct {
        pub const Saw = struct {
            next_sample: Sample,
            increment: Sample,
            pub fn init() @This() {
                return .{ .next_sample = 0, .increment = 0 };
            }
            pub fn renderOne(self: *@This()) Sample {
                const sample = self.next_sample;
                self.next_sample = Format.addPositiveWithWrap(sample, self.increment);
                return sample;
            }
        };
        pub fn Volume(comptime T: type) type { return struct {
            forward: T,
            volume: f32,
            pub fn renderOne(self: *@This()) Sample {
                return Format.scaleSample(self.forward.renderOne(), self.volume);
            }
        };}
    };

    pub fn renderSingleStepGenerator(comptime T: type, generator: *T, out: *Mix) void {
        comptime std.debug.assert(@typeInfo(@TypeOf(T.renderOne)).Fn.args[0].arg_type == *T);
        renderSingleStepGeneratorImpl(
            @ptrToInt(generator),
            @ptrCast(OpaqueFn(@TypeOf(T.renderOne)), T.renderOne),
            out);
    }
    fn renderSingleStepGeneratorImpl(context: usize, renderOneFn: fn(usize) align(1) Sample, out: *Mix) void {
        var it = out.sampleIterator();
        while (it.next()) |sample| {
            sample.add(renderOneFn(context));
        }
    }
    
    pub fn SingleStepTo(comptime RenderOne: type) type { return struct {
        render_one: RenderOne,
        pub fn render(self: *@This(), out: *Mix) void {
            var it = out.sampleIterator();
            while (it.next()) |sample| {
                sample.add(self.next_sample);
                self.next_sample = Render.addPositiveWithWrap(self.next_sample, self.increment);
            }
        }
    };}
};}

test "saw" {
    const S = Template(RenderFormatFloat32);
    var saw = S.singlestep.Saw {
        .next_sample = 0,
        .increment = 0.2,
    };
    var buffer = [_]f32 { 0 } ** 7;
    var mix = S.Mix {
        .channels = &[_]u8 { 0 },
        .buffer_start = &buffer,
        .buffer_limit = @as([*]f32, &buffer) + buffer.len,
     };
    S.renderSingleStepGenerator(@TypeOf(saw), &saw, &mix);
    std.debug.print("{any}\n", .{buffer});
    //std.testing.expectEqual(mix.samples,
    //    [_]f32 { 0.0, 2.0, 4.0, 6.0, 8.0, 1.0, -1.0 });
    var soft_saw = S.singlestep.Volume(S.singlestep.Saw) { 
        .volume = 0.1,
        .forward = .{
            .next_sample = 0,
            .increment = 0.2,
        }
    };
    buffer = [_]f32 { 0 } ** 7;
    S.renderSingleStepGenerator(@TypeOf(soft_saw), &soft_saw, &mix);
    std.debug.print("{any}\n", .{buffer});
    
}
