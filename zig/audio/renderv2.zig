const std = @import("std");
const audio = @import("../audio.zig");

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
    pub fn intToSample(int: anytype) f32 {
        switch (@TypeOf(int)) {
            i32, u32 => return @intToFloat(f32, int),
            else => @compileError("unsupported int: " ++ @typeName(@TypeOf(int))),
        }
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
            mix: *const Mix,
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
        pub fn sampleIterator(self: *const Mix) SampleIterator {
            return SampleIterator { .mix = self, .next_buffer = self.buffer_start };
        }
    };

    const Access = enum { get, set };
    const Knob = struct {
        name: []const u8,
        data: union {
            float_ref: struct {
                min: f32,
                max: f32,
                addr: *f32,
            },
            float_cb = struct {
                min: f32,
                max: f32,
                context: usize,
                cb: fn (usize, *f32, Access) void,
            },
            sample_ref: struct {
                addr: *Sample,
            },
        },
    };

    pub const singlestep = struct {
        pub const Saw = struct {
            next_sample: Sample,
            increment: Sample,
            pub fn init() @This() {
                return .{ .next_sample = 0, .increment = 0 };
            }
            pub fn getKnobs(self: *Saw) [1]Knob {
                return [_]Knob {
                    .{
                        .name = "increment",
                        .data = .{ .sample_ref = .{ .addr = &self.increment } },
                    },
                    .{
                        .name = "frequency",
                        .data = .{ .float_cb = .{
                            .min = 0,
                            .max = audio.global.sampleFramesPerSec,
                            .context = @ptrToInt(self),
                            .cb = freqCb,
                        } },
                    },
                };
            }
            pub fn freqToIncrement(frequency: f32) Sample {
                return frequency / Format.intToSample(audio.global.sampleFramesPerSec);
            }
            fn freqCb(context: usize, freq_ref: *f32, access: Access) void {
                const self = @intToPtr(*Saw, context);
                switch (access) {
                    .get => freq_ref.* = Format.sampleToFloat(f32, self.increment) * @intToFloat(f32, audio.global.sampleFramesPerSec),
                    .set => self.increment = freqToIncrement(freq_ref.*),
                }
            }
            pub fn setFreq(self: *@This(), freq: f32) void {
                self.increment = freqToIncrement(freq);
            }
            pub fn renderOne(self: *@This()) Sample {
                const sample = self.next_sample;
                self.next_sample = Format.addPositiveWithWrap(sample, self.increment);
                return sample;
            }
        };
        pub fn Volume(comptime Renderer: type) type { return struct {
            renderer: Renderer,
            volume: f32,
            pub fn renderOne(self: *@This()) Sample {
                return Format.scaleSample(self.renderer.renderOne(), self.volume);
            }
        };}
        pub const SawFreqChanger = struct {
            saw: Saw,

            event_sample_time: usize,
            event_tick: usize,

            note_start: audio.midi.MidiNote,
            note_end: audio.midi.MidiNote,
            note_inc: u7,
            note: audio.midi.MidiNote,

            pub const InitOptions = struct {
                event_sample_time: usize,
                note_start: audio.midi.MidiNote,
                note_end: audio.midi.MidiNote,
                note_inc: u7,
            };
            pub fn init(saw: Saw, opt: InitOptions) SawFreqChanger {
                return .{
                    .saw = saw,

                    .event_sample_time = opt.event_sample_time,
                    .event_tick = 0,

                    .note_start = opt.note_start,
                    .note_end = opt.note_end,
                    .note_inc = opt.note_inc,
                    .note = opt.note_start
                };
            }

            pub fn renderOne(self: *@This()) Sample {
                if (self.event_tick == self.event_sample_time) {
                    self.event_tick = 0;

                    const next_note: u8 = @enumToInt(self.note) + self.note_inc;
                    if (next_note >= @enumToInt(self.note_end)) {
                        self.note = self.note_start;
                    } else {
                        self.note = @intToEnum(audio.midi.MidiNote, @intCast(u7, next_note));
                    }
                    self.saw.setFreq(audio.midi.getStdFreq(self.note));
                } else {
                    self.event_tick += 1;
                }

                return self.saw.renderOne();
            }
        };
        //pub fn Automation(comptime Renderer: type, comptime Automater: type) type { return struct {
        //    renderer: Renderer,
        //    automater: Automater,
        //    pub fn renderOne(self: *@This()) Sample {
        //        self.automater.automate(&self.renderer);
        //        return self.renderer.renderOne();
        //    }
        //};}
        //pub const Midi(comptime T: type) type { return struct {
        //    voices: []T,
        //
        //};}
    };

    pub fn renderSingleStepGenerator(comptime T: type, generator: *T, out: Mix) void {
        comptime std.debug.assert(@typeInfo(@TypeOf(T.renderOne)).Fn.args[0].arg_type == *T);
        renderSingleStepGeneratorImpl(
            @ptrToInt(generator),
            @ptrCast(OpaqueFn(@TypeOf(T.renderOne)), T.renderOne),
            out);
    }
    fn renderSingleStepGeneratorImpl(context: usize, renderOneFn: fn(usize) align(1) Sample, out: Mix) void {
        var it = out.sampleIterator();
        while (it.next()) |sample| {
            sample.add(renderOneFn(context));
        }
    }
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
