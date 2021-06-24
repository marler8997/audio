const std = @import("std");

const stdext = @import("stdext");
usingnamespace stdext.limitarray;

const audio = @import("../audio.zig");
usingnamespace audio.renderformat;
const OutputNode = audio.dag.OutputNode;
const AudioGenerator = audio.dag.AudioGenerator;

//////////////////////////////////////////////////////////////////
// TODO: make this stuff non-global, make render a normal struct
//////////////////////////////////////////////////////////////////
pub const global = struct {
    // Meant to lock access to the render node graph to keep nodes
    // or data inside it from being modified during a render.
    pub var renderLock = std.Thread.Mutex { };

    // The generators connected directly to the audio backend
    var rootAudioGenerators: std.ArrayList(*AudioGenerator) = undefined;

    var mainOutputNode = OutputNode {};

    var event_queue: std.ArrayList(Event) = undefined;
};

const Event = struct {
    timestamp: u16, // note: using u16 for now to make sure rolling works
    kind: union(enum) {
        midi: audio.midi.MidiMsg,
    },
};

pub fn init() anyerror!void {
    global.rootAudioGenerators = std.ArrayList(*AudioGenerator).init(audio.global.allocator);
    global.event_queue = std.ArrayList(Event).init(audio.global.allocator);
}
pub fn addRootAudioGenerator(generator: *AudioGenerator) !void {
    try generator.connectOutputNode(generator, &global.mainOutputNode);

    const locked = global.renderLock.acquire();
    defer locked.release();

    try global.rootAudioGenerators.append(generator);
}

pub fn renderThreadEntry(context: void) void {
    std.log.debug("renderThread started!", .{});
    const result = renderThread2();
    if (result) {
        std.log.info("renderThread is exiting with no error", .{});
    } else |err| {
        std.log.err("render thread failed with {}", .{err});
    }
}

fn renderThread2() !void {
    //// Set priority
    //if(!SetPriorityClass(GetCurrentProcess(), REALTIME_PRIORITY_CLASS)) {
    //    printf("SetPriorityClass failed\n");
    //    return 1;
    //}

    //{
    //    const thread = GetCurrentThread();
    //    const priority = GetThreadPriority(thread);
    //    logDebug("ThreadPriority={}", priority);
    //    if (priority < ThreadPriority.timeCritical)
    //    {
    //        logDebug("Setting thread priority to ", ThreadPriority.timeCritical);
    //        if (SetThreadPriority(thread, ThreadPriority.timeCritical).failed)
    //        {
    //            logError("Failed to set thread priority, e={}", GetLastError());
    //            return 1; // fail
    //        }
    //    }
    //}

    const renderBufferSampleCount = audio.global.bufferSampleFrameCount * audio.global.channelCount;
    std.log.debug("renderBufferSampleCount {}", .{renderBufferSampleCount});
    var renderBuffer = try audio.global.allocator.alloc(SamplePoint, renderBufferSampleCount);
    defer audio.global.allocator.free(renderBuffer);

    var channels = try audio.global.allocator.alloc(u8, audio.global.channelCount);
    defer audio.global.allocator.free(channels);
    {
        var i : u8 = 0;
        while (i < audio.global.channelCount)
        {
            channels[i] = i;
            i += 1;
        }
    }
    try audio.global.backendFuncs.startingRenderLoop();
    const renderLoopResult = renderLoop(channels, renderBuffer.ptr, renderBuffer.ptr + renderBuffer.len);
    try audio.global.backendFuncs.stoppingRenderLoop();
    return renderLoopResult;
}

//version = DebugDumpRender;
fn renderLoop(channels: []u8, bufferStart: [*]SamplePoint, bufferLimit: [*]SamplePoint) anyerror!void {

    // Temporary one-time setup
    global_render2_thing.generator.setFreq(audio.midi.getStdFreq(audio.midi.MidiNote.a4));
    global_render2_thing2.generator.setFreq(audio.midi.getStdFreq(audio.midi.MidiNote.csharp4));
    global_render2_thing3.component.generator.setFreq(audio.midi.getStdFreq(audio.midi.MidiNote.csharp4));
    global_render2_thing3.changer.event_sample_time = @floatToInt(usize, @intToFloat(f32, audio.global.sampleFramesPerSec) * 0.3);

    try render(channels, bufferStart, bufferLimit);
    //version (DebugDumpRender)
    //{
    //    for (auto p = renderBuffer; p < renderLimit; p += audio.global.channelCount)
    //    {
    //        // only log one channel right now
    //        if (audio.global.channelCount == 1)
    //            logDebug(p[0]);
    //        if (audio.global.channelCount == 2)
    //            logDebug(p[0], "    ", p[1]);
    //    }
    //    import mar.process : exit;
    //    exit(1);
    //}
    try audio.global.backendFuncs.writeFirstBuffer(bufferStart);

    while(true)
    {
        //logDebug("Rendering buffer ", bufferIndex);
        //renderStartTick.update();
        try render(channels, bufferStart, bufferLimit);
        try audio.global.backendFuncs.writeBuffer(bufferStart);
    }
}

fn render(channels: []u8, bufferStart: [*]SamplePoint, bufferLimit: [*]SamplePoint) !void {

    // TODO: if there are any generators that have a "set" function, then I
    //       could use that first and skip zeroing memory
    //

    // TODO: which one is faster????
    stdext.mem.set(limitPointersToSlice(bufferStart, bufferLimit), 0);
    //stdext.mem.secureZero(limitPointersToSlice(bufferStart, bufferLimit));

    const locked = global.renderLock.acquire();
    defer locked.release();
    //logDebug("render");
    for (global.rootAudioGenerators.items) |generator| {
        try generator.mix(generator, channels, bufferStart, bufferLimit);
    }
    for (global.rootAudioGenerators.items) |generator| {
        try generator.renderFinished(generator, &global.mainOutputNode);
    }

    {
        var mix = Render2.Mix {
            .channels = channels,
            .buffer_start = bufferStart,
            .buffer_limit = bufferLimit,
        };
        //Render2.renderSingleStepGenerator(@TypeOf(global_render2_thing), &global_render2_thing, mix);
        //Render2.renderSingleStepGenerator(@TypeOf(global_render2_thing2), &global_render2_thing2, mix);
        //Render2.renderSingleStepGenerator(@TypeOf(global_render2_thing3), &global_render2_thing3, mix);
        //Render2.renderSingleStepGenerator(@TypeOf(global_temp_midi_render2_instrument), &global_temp_midi_render2_instrument, mix);
        for (global_temp_midi_channel_voices) |*channel_voice| {
            for (channel_voice.getCurrentVoices()) |*voice| {
                Render2.renderSingleStepGenerator(@TypeOf(voice.renderer), &voice.renderer, mix);
            }
        }
    }
}

const renderv2 = @import("renderv2.zig");
const Render2 = renderv2.Template(renderv2.RenderFormatFloat32);
//var global_render2_thing = Render2.singlestep.Saw {
//    .next_sample = 0,
//    .increment = 0.005,
//};
var global_render2_thing = Render2.singlestep.Chain(Render2.singlestep.SawGenerator, &[_]type {Render2.singlestep.VolumeFilter}) {
    .generator = .{ .next_sample = 0, .increment = 0 },
    .filters = .{
        .{ .volume = 0.02 },
    },
};
var global_render2_thing2 = Render2.singlestep.Chain(Render2.singlestep.SawGenerator, &[_]type {Render2.singlestep.VolumeFilter}) {
    .generator = .{ .next_sample = 0, .increment = 0 },
    .filters = .{
        .{ .volume = 0.02 },
    },
};

var global_render2_thing3 = Render2.singlestep.AttachedKnob(
    Render2.singlestep.Chain(Render2.singlestep.SawGenerator, &[_]type {Render2.singlestep.VolumeFilter}),
    Render2.singlestep.NoteFreqF32KnobChanger,
    Render2.singlestep.SawGenerator.frequency_knob
) {
    .component = .{
        .generator = Render2.singlestep.SawGenerator {
            .next_sample = 0,
            .increment = 0,
        },
        .filters = .{
            Render2.singlestep.VolumeFilter { .volume = 0.02 },
        },
    },
    .changer = Render2.singlestep.NoteFreqF32KnobChanger.init(.{
        .event_sample_time = 0,
        .note_start = audio.midi.MidiNote.a2,
        .note_end = audio.midi.MidiNote.a7,
        .note_inc = 3,
    }),
};

pub fn MidiVoices(comptime count: comptime_int, comptime Renderer: type) type { return struct {
    const Index = std.math.IntFittingRange(0, count - 1);
    const Voice = struct {
        renderer: Renderer,
        note: audio.midi.MidiNote
    };

    count: std.math.IntFittingRange(0, count) = 0,
    available_voices: [count]Voice = undefined,

    pub fn getCurrentVoices(self: *@This()) []Voice {
        return self.available_voices[0..self.count];
    }
    pub fn addAssumeCapacity(self:*@This(), note: audio.midi.MidiNote, renderer: Renderer) void {
        std.debug.assert(self.count < self.available_voices.len);
        self.available_voices[self.count] = .{ .note = note, .renderer = renderer };
        self.count += 1;
    }
    pub fn find(self: *@This(), note: audio.midi.MidiNote) ?Index {
        var i: Index = 0;
        while (i < self.count) : (i += 1) {
            if (self.available_voices[i].note == note)
                return i;
        }
        return null;
    }
    pub fn remove(self: *@This(), voice_index: Index) void {
        std.debug.assert(voice_index < self.count);
        var i: std.math.IntFittingRange(0, count) = voice_index;
        while (i + 1 < self.count) : (i += 1) {
            self.available_voices[i] = self.available_voices[i+1];
        }
        self.count -= 1;
    }
};}
var global_temp_midi_channel_voices = [16]MidiVoices(10, Render2.singlestep.Chain(
    Render2.singlestep.SawGenerator, &[_]type {
        Render2.singlestep.VolumeFilter,
    }
)) { .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}, .{}};

//var global_temp_midi_render2_instrument = Render2.singlestep.MidiVoice(Render2.singlestep.Volume(Render2.singlestep.Saw)) {
//    .note = .none,
//    .renderer = .{
//        .volume = 0.02,
//        .renderer = .{
//            .next_sample = 0,
//            .increment = 0,
//        },
//    },
//};
pub fn tempMidiInstrumentHandler(timestamp: usize, msg: audio.midi.MidiMsg) void {
    audio.midi.checkMidiMsg(msg) catch |e| {
        std.log.err("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!", .{});
        std.log.err("Midi Message Error: {}", .{e});
    };
    audio.midi.logMidiMsg(msg);
    const volume_scale = 0.2;

    switch (msg.kind) {
        .note_off, .note_on => {
            const off = (msg.kind == .note_off);

            const channel_voices = &global_temp_midi_channel_voices[msg.status_arg];

            {
                const note = @intToEnum(audio.midi.MidiNote, msg.data.note_on.note);
                if (channel_voices.find(note)) |voice_index| {
                    if (off or msg.data.note_on.velocity == 0) {
                        std.log.debug("!!!! removing note={s} i={}", .{@tagName(note), voice_index});
                        channel_voices.remove(voice_index);
                    } else {
                        std.log.debug("!!!! setting volume note={s} i={}", .{@tagName(note), voice_index});
                        channel_voices.available_voices[voice_index].renderer.filters[0].volume = @intToFloat(f32, msg.data.note_on.velocity) / 127 * volume_scale;
                    }
                } else if (!off and msg.data.note_on.velocity > 0) {
                    if (channel_voices.count == channel_voices.available_voices.len) {
                        std.log.warn("out of voices! note={s}", .{@tagName(note)});
                    } else {
                        std.log.debug("!!!! adding note={s}", .{@tagName(note)});
                        channel_voices.addAssumeCapacity(note, .{
                            .generator = Render2.singlestep.SawGenerator.initFreq(audio.midi.defaultFreq[@enumToInt(note)]),
                            .filters = .{
                                .{ .volume =  @intToFloat(f32, msg.data.note_on.velocity) / 127 * volume_scale },
                            },
                        });
                    }
                }
            }

            //if (off or msg.data.note_on.velocity == 0) {
            //    if (@enumToInt(global_temp_midi_render2_instrument.note) == msg.data.note_off.note) {
            //        global_temp_midi_render2_instrument.renderer.volume = 0;
            //    }
            //} else {
            //    global_temp_midi_render2_instrument.note = @intToEnum(audio.midi.MidiNote, msg.data.note_on.note);
            //    global_temp_midi_render2_instrument.renderer.volume = @intToFloat(f32, msg.data.note_on.velocity) / 127;
            //    global_temp_midi_render2_instrument.renderer.renderer.setFreq(
            //        audio.midi.getStdFreq(@intToEnum(audio.midi.MidiNote, msg.data.note_on.note)));
            //}
        },
        .pitch_bend => {
            const channel_voices = &global_temp_midi_channel_voices[msg.status_arg];

            const bend_value = msg.data.pitch_bend.getValue();
            //const bend_ratio = getBendRatio(bend_value);
            //const bend_distance = 28; // I think the Seaboard rise assumes this to be 24?
            for (channel_voices.getCurrentVoices()) |*voice| {
                const note_freq = audio.midi.defaultFreq[@enumToInt(voice.note)];
                //if (bend_ratio >= 1.0) {
                //    const next_freq = audio.midi.defaultFreq[@enumToInt(voice.note)+bend_distance];
                //    const diff = next_freq - note_freq;
                //    voice.renderer.generator.setFreq(note_freq + (diff * (bend_ratio-1)));
                //} else {
                //    const prev_freq = audio.midi.defaultFreq[@enumToInt(voice.note)-bend_distance];
                //    const diff = note_freq - prev_freq;
                //    voice.renderer.generator.setFreq(prev_freq + (diff * bend_ratio));
                //}
                voice.renderer.generator.setFreq(note_freq * getPitchBendRatio(bend_value));
            }
        },
        .channel_pressure => {
            const channel_voices = &global_temp_midi_channel_voices[msg.status_arg];
            for (channel_voices.getCurrentVoices()) |*voice| {
                voice.renderer.filters[0].volume = @intToFloat(f32, msg.data.channel_pressure.pressure) / 127 * volume_scale;
            }

        },
        else => {},
    }
}

fn getPitchBendRatio(bend_value: u14) f32 {
    //const pitch_bend_dist = 4096 * 12; // normal?
    const pitch_bend_dist = 4096 / 2; // seaboard?
    return std.math.pow(f32, 2.0, @intToFloat(f32, @intCast(i15, bend_value) - 8192) / pitch_bend_dist);
}

//    0 maps to 0
//    1 maps to (1/8192) (about 0.000122)
// 8191 maps to (8191/8192) (about 0.99988)
// 8192 maps to 1
// 8193 maps to (1 + 1/8191) (about 1.000122)
// 16382 maps to (1 + 8190/8191) (about 0.99988)
// 16383 maps to 2
fn getBendRatio(bend_value: u14) f32 {
    return
        if (bend_value >= 8192) 1.0 + (@intToFloat(f32, bend_value - 8192) / 8191.0)
        else @intToFloat(f32, bend_value) / 8192.0;
}

pub fn addToEachChannel(channels: []u8, buffer: [*]SamplePoint, value: SamplePoint) void {
    for (channels) |channel| {
        buffer[channel] += value;
    }
}
