const std = @import("std");
const audio = @import("../audio.zig");

// TODO: move this
pub fn isValidCall(func: anytype, args: anytype) bool {
    _ = func;
    _ = args;
    // TODO: implement this maybe?
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
        else => @compileError("expected an Fn but got " ++ @typeName(T)),
    }
}

pub const RenderFormatFloat32 = struct {
    pub const Sample = f32;
    pub fn trigUnitToSample(unit: TrigUnit) Sample {
        std.debug.assert(unit.val >= -1.0 and unit.val <= 1.0);
        return unit.val;
    }
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
            i32, u32 => return @floatFromInt(int),
            else => @compileError("unsupported int: " ++ @typeName(@TypeOf(int))),
        }
    }
    pub fn sampleToF32(sample: Sample) f32 {
        return sample;
    }
    pub fn f32ToSample(f: f32) Sample {
        return f;
    }
};

// A TrigUnit goes from -1.0 to 1.0
pub const TrigUnit = struct { val: f32 };

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
                if (@intFromPtr(self.next_buffer) >= @intFromPtr(self.mix.buffer_limit)) {
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
    const NamedKnob = struct { name: []const u8, knob: Knob };
    const Knob = union(enum) {
        float_field: struct {
            min: f32,
            max: f32,
            field_offset: u32,
        },
        float_cb: struct {
            min: f32,
            max: f32,
            cb: fn (usize, *f32, Access) void,
        },
        sample_field: struct {
            field_offset: u32,
        },

        pub fn setF32(self: Knob, context: usize, value: f32) void {
            switch (self) {
                .float_field => |k| @as(*f32, @ptrFromInt(context + k.field_offset)).* = std.math.clamp(value, k.min, k.max),
                .float_cb => |k| {
                    var set_value = std.math.clamp(value, k.min, k.max);
                    k.cb(context, &set_value, .set);
                },
                .sample_field => |k| @as(*Sample, @ptrFromInt(context + k.field_offset)).* = Format.f32ToSample(value),
            }
        }
    };

    /// Runtime Interfaces (maybe I'll do this, but using Comptie Interfaces for now)
    /// -------------------------------------------------
    /// 1. Component:
    ///      fn queryKnobs(knobs: std.ArrayList(Knob)) void;
    /// 2. Generator inherits Component:
    ///      fn renderOneSample(self: *Generator) Sample;
    /// 2. Filter inherits Component:
    ///      fn filterOne(self: *Filter) Sample;
    ///
    /// Comptime Interfaces
    /// -------------------------------------------------
    /// 1. Component:
    ///      fn getKnobs() [N]Knob;
    /// 2. SampleGenerator inherits Component:
    //       fn setFreq(self: *@This(), freq: f32) void;
    ///      fn renderOneSample(self: *@This()) Sample;
    /// 3. TrigUnitGenerator inherits Component:
    //       fn setFreq(self: *@This(), freq: f32) void;
    ///      fn renderOneTrigUnit(self: *@This()) TrigUnit;
    /// 4. Filter inherits Component:
    ///      fn filterOne(self: *@This()) Sample;
    /// 5. KnobChanger inherits Component:
    //       fn nextSample(self: *@This(), knob: Knob, knob_context: usize) void;
    pub const singlestep = struct {
        // These are the Runtime Interfaces I may or may not use
        // I might create code that turns the Comptime Interfaces into Runtime Interfaces autmoatically.
        //pub const Component = struct {
        //    queryKnobs: *const fn(knobs: std.ArrayList(Knob)) void,
        //};
        //pub const Generator = struct {
        //    component: Component,
        //    setFreq: *const fn(self: *Generator) void
        //    renderOne: *const fn(self: *Generator) Sample,
        //};
        //pub const Filter = struct {
        //    component: Component,
        //    filterOne: *const fn(self: *Filter, sample: Sample) Sample,
        //};

        /// Chains a Generator and one or more Filters into a new Generator.
        pub fn Chain(comptime Generator: type, comptime filter_types: []const type) type { return struct {
            pub const FilterTuple = std.meta.Tuple(filter_types);

            generator: Generator,
            filters: FilterTuple,

            pub fn getKnobs() []Knob {
                // TODO: implement this
            }

            pub fn renderOneSample(self: *@This()) Sample {
                var sample = self.generator.renderOneSample();
                inline for (std.meta.fields(FilterTuple)) |field| {
                    sample = @field(self.filters, field.name).filterOne(sample);
                }
                return sample;
            }

            pub usingnamespace ForwardSetFreq(*@This(), "generator");
        };}

        pub fn ForwardSetFreq(comptime T: type, comptime field: []const u8) type { return struct {
            pub fn setFreq(self: T, freq: f32) void { @field(self, field).setFreq(freq); }
        }; }

        /// Attach a KnobChanger to a componenet
        pub fn AttachedKnob(comptime Component: type, comptime KnobChanger: type, comptime knob: Knob) type { return struct {
            const Self = @This();

            component: Component,
            changer: KnobChanger,
            //knob: Knob,

            pub fn getKnobs() []Knob {
                // TODO: implement this
            }

            pub usingnamespace if (@hasDecl(Component, "renderOneSample")) struct {
                pub fn renderOneSample(self: *Self) Sample {
                    self.changer.nextSample(knob, @intFromPtr(&self.component));
                    return self.component.renderOneSample();
                }
            } else @compileError("unknown component type or not implemented: " ++ @typeName(Component));
        };}


        //pub const SineGenerator = struct {
        //    phase: f32 = 0,
        //    phase_increment: f32,
        //    pub fn initFreq(freq: f32) @This() {
        //        return .{ .phase_increment = freqToPhaseIncrement(freq) };
        //    }
        //    pub const frequency_knob = Knob {
        //        .float_cb = .{
        //            .min = 0.00001,
        //            //.max = audio.global.sampleFramesPerSec,
        //            .max = 999999999999999999,
        //            .cb = freqCb,
        //        }
        //    };
        //    pub fn freqToPhaseIncrement(freq: f32) f32 {
        //        return std.math.tau * freq / @intToFloat(f32, audio.global.sampleFramesPerSec);
        //    }
        //    pub fn setFreq(self: *@This(), freq: f32) void {
        //        self.phase_increment = freqToPhaseIncrement(freq);
        //    }
        //
        //    // TODO: I should modify this not to return a sample, but instead, return
        //    //       some sort of UnitScale value (from -1 to 1).
        //    //       So this would be a UnitScalarGenerator?
        //    //       I could create a type that takes a UnitScalarGenerator type and turns it into
        //    //       a SampleGenerator.
        //    pub fn renderOneSample(self: *@This()) Sample {
        //        const sample = std.math.sin(self.phase);
        //        self.phase += self.phase_increment;
        //        if (self.phase > std.math.tau) {
        //            self.phase -= std.math.tau;
        //        }
        //        return sample; // TODO: how do we know what range this signal returns?
        //                       //       we could say it returns -1.0 to 1.0 for floats?
        //                       //       what about for integers?
        //    }
        //};
        pub const SawTrigUnitGenerator = struct {
            next_unit: TrigUnit = .{ .val = 0 },
            increment: TrigUnit,
            pub fn init() @This() {
                return .{ .increment = 0 };
            }
            pub fn initFreq(freq: f32) @This() {
                return .{ .increment = freqToIncrement(freq) };
            }

            pub const frequency_knob = Knob {
                .float_cb = .{
                    .min = 0.00001,
                    //.max = audio.global.sampleFramesPerSec,
                    .max = 999999999999999999,
                    .cb = freqCb,
                }
            };

            pub fn getKnobs() [2]NamedKnob {
                return [_]Knob {
                    .{
                        .name = "increment",
                        .data = .{ .sample_field = .{ .field_offset = @offsetOf(@This(), "increment") } },
                    },
                    .{ .name = "frequency", .knob = frequency_knob },
                };
            }
            pub fn freqToIncrement(frequency: f32) TrigUnit {
                // TODO: what to do if frequency ratio is greater than 2.0 ???
                return .{ .val = frequency / @as(f32, @floatFromInt(audio.global.sampleFramesPerSec)) };
            }
            fn freqCb(context: usize, freq_ref: *f32, access: Access) void {
                const self: *SawTrigUnitGenerator = @ptrFromInt(context);
                switch (access) {
                    .get => freq_ref.* = self.increment.val * @as(f32, @floatFromInt(audio.global.sampleFramesPerSec)),
                    .set => self.increment = freqToIncrement(freq_ref.*),
                }
            }
            pub fn setFreq(self: *@This(), freq: f32) void {
                self.increment = freqToIncrement(freq);
            }
            pub fn renderOneTrigUnit(self: *@This()) TrigUnit {
                const unit = self.next_unit;
                self.next_unit = .{ .val = unit.val + self.increment.val };
                while (self.next_unit.val > 1.0) {
                    self.next_unit.val -= 2.0;
                }
                return unit;
            }
        };
        pub const SawFullSampleGenerator = TrigUnitToFullSampleGenerator(SawTrigUnitGenerator);

        pub fn TrigUnitToFullSampleGenerator(comptime TrigUnitGenerator: type) type { return struct {
            unit_generator: TrigUnitGenerator,
            pub fn renderOneSample(self: *@This()) Sample {
                return Format.trigUnitToSample(self.unit_generator.renderOneTrigUnit());
            }
            pub usingnamespace ForwardSetFreq(*@This(), "unit_generator");
        }; }




        pub const VolumeFilter = struct {
            volume: f32,
            pub fn getKnobs() [1]Knob {
                return [_]Knob {
                    .{
                        .name = "volume",
                        .data = .{ .float_field = .{
                            .field_offset = @offsetOf(@This(), "volume"),
                        } },
                    },
                };
            }
            pub fn filterOne(self: *@This(), sample: Sample) Sample {
                return Format.scaleSample(sample, self.volume);
            }
        };
        pub const BypassFilter = struct {
            pub fn filterOne(self: *@This(), sample: Sample) Sample {
                _ = self;
                return sample;
            }
        };
        pub const SimpleLowPassFilter = struct {
            last_input_sample: Sample = 0,
            pub fn filterOne(self: *@This(), sample: Sample) Sample {
                const out_sample = self.last_input_sample + sample;
                self.last_input_sample = sample;
                return out_sample;
            }
        };

        // NOTE: can I split the in/out parts into their own componets?
        //       not sure if I can because the second one in the chain won't
        //       have the original signal
        pub fn CombFilter(comptime FeedforwardDelay: comptime_int, comptime FeedbackDelay: comptime_int) type { return struct {
            const InCursor = std.math.IntFittingRange(0, FeedforwardDelay-1);
            const OutCursor = std.math.IntFittingRange(0, FeedbackDelay-1);

            feedforward_gain: f32,
            feedback_gain: f32,
            // TODO: maybe I should provide an interface to request sample context?
            in_samples: [FeedforwardDelay]Sample = [_]Sample {0} ** FeedforwardDelay,
            in_cursor: InCursor = 0,
            out_samples: [FeedbackDelay]Sample = [_]Sample {0} ** FeedbackDelay,
            out_cursor: OutCursor = 0,

            pub fn filterOne(self: *@This(), sample: Sample) Sample {
                self.in_samples[self.in_cursor] = sample;
                const in_component = self.in_samples[self.in_cursor];
                self.in_cursor = wrapIncrement(InCursor, self.in_cursor, FeedforwardDelay-1);

                const out_component = self.out_samples[self.out_cursor];
                const out_sample = sample +
                    (self.feedforward_gain * in_component) -
                    (self.feedback_gain * out_component);
                self.out_samples[self.out_cursor] = out_sample;
                self.out_cursor = wrapIncrement(OutCursor, self.out_cursor, FeedbackDelay-1);
                return out_sample;
            }
        };}


        pub fn MidiVoice(comptime Renderer: type) type { return struct {
            renderer: Renderer,
            note: audio.midi.MidiNote,
            pub fn renderOneSample(self: *@This()) Sample {
                return self.renderer.renderOneSample();
            }
        };}


        pub const NoteFreqF32KnobChanger = struct {
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
            pub fn init(opt: InitOptions) NoteFreqF32KnobChanger {
                return .{
                    .event_sample_time = opt.event_sample_time,
                    .event_tick = 0,

                    .note_start = opt.note_start,
                    .note_end = opt.note_end,
                    .note_inc = opt.note_inc,
                    .note = opt.note_start
                };
            }

            pub fn nextSample(self: *@This(), knob: Knob, knob_context: usize) void {
                if (self.event_tick == self.event_sample_time) {
                    self.event_tick = 0;

                    const next_note: u8 = @intFromEnum(self.note) + self.note_inc;
                    if (next_note >= @intFromEnum(self.note_end)) {
                        self.note = self.note_start;
                    } else {
                        self.note = @enumFromInt(next_note);
                    }
                    knob.setF32(knob_context, audio.midi.getStdFreq(self.note));
                } else {
                    self.event_tick += 1;
                }
            }
        };
        //pub fn Automation(comptime Renderer: type, comptime Automater: type) type { return struct {
        //    renderer: Renderer,
        //    automater: Automater,
        //    pub fn renderOneSample(self: *@This()) Sample {
        //        self.automater.automate(&self.renderer);
        //        return self.renderer.renderOneSample();
        //    }
        //};}
        //pub const Midi(comptime T: type) type { return struct {
        //    voices: []T,
        //
        //};}

        pub fn renderGenerator(comptime T: type, generator: *T, out: Mix) void {
            comptime std.debug.assert(@typeInfo(@TypeOf(T.renderOneSample)).Fn.params[0].type == *T);
            renderGeneratorImpl(
                @intFromPtr(generator),
                @ptrCast(&T.renderOneSample),
                out);
        }
        fn renderGeneratorImpl(context: usize, renderOneSampleFn: *const fn(usize) align(1) Sample, out: Mix) void {
            var it = out.sampleIterator();
            while (it.next()) |sample| {
                sample.add(renderOneSampleFn(context));
            }
        }
    };
};}

fn wrapIncrement(comptime T: type, x: T, max: T) T {
    return if (x == max) 0 else (x+1);
}
fn wrapDecrement(comptime T: type, x: T, max: T) T {
    return if (x == 0) max else (x-1);
}

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
