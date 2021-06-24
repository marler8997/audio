const std = @import("std");

const stdext = @import("stdext");
usingnamespace stdext.limitarray;

const audio = @import("../audio.zig");
usingnamespace audio.renderformat;
usingnamespace audio.midi;


pub const OutputNode = struct {
};

pub const AudioGenerator = struct {
    // Some generators may need to know how many output nodes are connected
    connectOutputNode: fn(self: *AudioGenerator, outputNode: *OutputNode) anyerror!void,
    // Some generators may need to know how many output nodes are connected
    disconnectOutputNode: fn(self: *AudioGenerator, ouptutNode: *OutputNode) anyerror!void,

    mix : fn(self: *AudioGenerator, channels: []u8, bufferStart: [*]SamplePoint, bufferLimit: [*]SamplePoint) anyerror!void,
    // This let's the audio generator that is can clean up any state for this frame.
    // This function must be called after each buffer is done being rendered.
    // This function may be called more than once before the next mix/set call.
    renderFinished: fn(self: *AudioGenerator, outputNode: *OutputNode) anyerror!void,
};

//// A node that inputs midi notes
//struct MidiInstrument(T)
pub const MidiInstrument = struct {

    audioGenerator: AudioGenerator,
    inputNodes: std.ArrayList(*MidiGenerator),

    pub fn sendInputNodesRenderFinished() void {
        for (inputNodes) |inputNode| {
            inputNodes.renderFinished(inputNodes[i], &this);
        }
    }
    pub fn addInputNode(self: *MidiInstrument, inputNode: *MidiGenerator) !void {
        return self.inputNodes.append(inputNode);
    }
};
//

/// A node that inputs midi notes
//struct MidiGenerator(T)
pub const MidiGenerator = struct {
    // MidiInput nodes may or may not want to know all the instruments that are
    // going to request events from them.
    //void function(T* context, void* instrument) connectInstrument;

    //getMidiEvents: fn(self: *MidiGenerator, instrument: *MidiInstrument) []MidiEvent,

    // This let's the midi input node that it can now clean up all it's events.
    // This function must be called after each buffer is done being rendered.
    renderFinished: fn(self: *MidiGenerator, instrument: *MidiInstrument) void,
};

pub const MidiGeneratorTypeAImpl = struct {
};

//struct MidiGeneratorTemplate(InputDevice)
pub const MidiGeneratorTypeA = struct {
//    import mar.arraybuilder : ArrayBuilder;
//    import audio.midi : MidiNote, MidiNoteMap;
//
//    mixin InheritBaseTemplate!MidiGenerator;
    midiGenerator: MidiGenerator,
//    //bool[MidiNote.max + 1] onMap;
    midiEvents: std.ArrayList(MidiEvent),
//    InputDevice inputDevice;
//
    pub fn init() @This() {
        return @This() {
            .midiGenerator = MidiGenerator {
                .getMidiEvents = getMidiEvents,
                .renderFinished = renderFinished,
            },
            .midiEvents = std.ArrayList(MidiEvent).init(audio.global.allocator),
        };
    }

    pub fn addMidiEvent(self: *MidiGeneratorTypeA, event: MidiEvent) !void {
        const locked = audio.render.global.renderLock.acquire();
        defer locked.release();
        // TODO: make sure it is in order by timestamp
        try self.midiEvents.append(event);
    }

    fn getMidiEvents(base: *MidiGenerator, instrument: *MidiInstrument) []MidiEvent {
        var self = @fieldParentPtr(@This(), "midiGenerator", base);
        //if (self.midiEvents.len > 0) logDebug("returning {} midi events", self.midiEvents.len);
        return self.midiEvents.items;
    }
    fn renderFinished(base: *MidiGenerator, instrument: *MidiInstrument) void {
        var self = @fieldParentPtr(@This(), "midiGenerator", base);
        // NOTE: I'm not sure I want this to re-allocate
        self.midiEvents.shrinkRetainingCapacity(0);
    }
//    //
//    // Input Device forwarding functions
//    //
//    final passfail stopMidiDeviceInput(T...)(T args)
//    {
//        pragma(inline, true);
//        return InputDevice.stopMidiDeviceInput(&this, args);
//    }
//    final passfail startMidiDeviceInput(T...)(T args)
//    {
//        pragma(inline, true);
//        return InputDevice.startMidiDeviceInput(&this, args);
//    }
};

//void addToEachChannel(ubyte[] channels, SamplePoint* buffer, SamplePoint value)
//{
//    foreach (channel; channels)
//    {
//        buffer[channel] += value;
//    }
//}
//
//enum NoteControlState
//{
//    pressed, // the note is being pressed
//    releasedWithSustain, // the was released with the sustain pedal
//    releasedNoSustain, // the note was released and is no longer sustaining
//}
//
///*
//struct ChannelMapping
//{
//    private ubyte* mapping;
//    ubyte length;
//    this(ubyte* mapping, ubyte length)
//    {
//        this.mapping = mapping;
//        this.length = length;
//    }
//    this(ubyte[] mapping)
//    in { assert(mapping.length <= ubyte.max); } do
//    {
//        this.mapping = mapping.ptr;
//        this.length = cast(ubyte)mapping.length;
//    }
//    void addToChannel(SamplePoint* buffer, SamplePoint value, ubyte mappingIndex)
//    in { assert(mappingIndex < length); } do
//    {
//        buffer[mapping[mappingIndex]] += value;
//    }
//}
//*/
//
//struct NoteStateBase
//{
//    import audio.midi : MidiNote;
//
//    float currentVolume;
//    float targetVolume;
//    float releaseMultiplier;
//    MidiNote note; // save so we can easily remove the note from the MidiNoteMap
//    NoteControlState controlState;
//}
//
//struct OscillatorInstrumentData
//{
//    float volumeScale;
//}
//
//alias SinOscillatorMidiInstrument = MidiInstrumentTypeA!SinOscillatorMidiInstrumentTypeA;
//struct SinOscillatorMidiInstrumentTypeA
//{
//    import audio.midi : MidiNote, defaultFreq;
//
//    enum TWO_PI = 3.14159265358979 * 2;
//    alias InstrumentData = OscillatorInstrumentData;
//    struct NoteState
//    {
//        mixin Inherit!NoteStateBase;
//        float phaseIncrement;
//        float phase;
//    }
//    static void newNote(ref OscillatorInstrumentData instrument, MidiEvent* event, NoteState* state)
//    {
//        state.phaseIncrement = TWO_PI * defaultFreq[event.noteOn.note] / audio.global.sampleFramesPerSec;
//        state.phase = 0;
//    }
//    static void reattackNote(ref OscillatorInstrumentData instrument, MidiEvent* event, NoteState* state)
//    {
//    }
//    static void renderNote(ref OscillatorInstrumentData instrument, NoteState* state,
//        ubyte[] channels, SamplePoint* buffer)
//    {
//        pragma(inline, true);
//
//        import mar.math : sin;
//
//        addToEachChannel(channels, buffer, cast(SamplePoint)(
//                state.base.currentVolume * sin(state.phase) * instrument.volumeScale * RenderFormat.MaxAmplitude));
//
//        state.phase += state.phaseIncrement;
//        if(state.phase > TWO_PI)
//            state.phase -= TWO_PI;
//    }
//}
//
//private float sawFrequencyToIncrement(float frequency)
//{
//    return frequency / audio.global.sampleFramesPerSec;
//}

const MidiInstrumentTypeAImpl = struct {
    newNote: fn(self: *MidiInstrumentTypeAImpl) void,//, event: *MidiEvent, state: *NoteState) void,
    reattackNote: fn(self: *MidiInstrumentTypeAImpl) void,
    renderNote: fn(self: *MidiInstrumentTypeAImpl) void,
};

pub fn createSawMidiInstrument(allocator: *std.mem.Allocator) !*MidiInstrument {
    var sawImpl = try allocator.create(SawOscillatorMidiInstrumentTypeA);
    errdefer allocator.destroy(sawImpl);

    sawImpl.* = SawOscillatorMidiInstrumentTypeA.init();

    var instrument = try allocator.create(MidiInstrumentTypeA);
    errdefer allocator.destroy(instrument);

    instrument.* = MidiInstrumentTypeA.init(&sawImpl.midiInstrumentTypeAImpl);
    return &instrument.midiInstrument;
}
//alias SawOscillatorMidiInstrument = MidiInstrumentTypeA!SawOscillatorMidiInstrumentTypeA;
const SawOscillatorMidiInstrumentTypeA = struct {
    //import audio.midi : MidiNote, defaultFreq;

    midiInstrumentTypeAImpl: MidiInstrumentTypeAImpl,
    next_sample_point: f32,
    increment: f32,

    //alias InstrumentData = OscillatorInstrumentData;
    pub fn init() @This() {
        return @This() {
            .midiInstrumentTypeAImpl = MidiInstrumentTypeAImpl {
                .newNote = newNote,
                .reattackNote = reattackNote,
                .renderNote = renderNote,
            },
            .next_sample_point = 0, // TODO: undefined?
            .increment = 0, // TODO: undefined?
        };
    }
    //struct NoteState
    //{
    //    mixin Inherit!NoteStateBase;
    //    float nextSamplePoint;
    //    float increment;
    //}
    fn newNote(base: *MidiInstrumentTypeAImpl) void {//, event: *MidiEvent) void {
        //const self = @fieldParentPtr(SawOscillatorMidiInstrumentTypeA, "midiInstrumentTypeAImpl", base);
        //self.next_sample_point = 0;
        //self.increment = audio.oscillators.sawFrequencyToIncrement(defaultFreq[event.noteOn.note]);
    }
    //static void newNote(ref OscillatorInstrumentData instrument, MidiEvent* event, NoteState* state)
    //{
    //    state.nextSamplePoint = 0;
    //    state.increment = sawFrequencyToIncrement(defaultFreq[event.noteOn.note]);
    //}
    fn reattackNote(base: *MidiInstrumentTypeAImpl) void { }
    //static void reattackNote(ref OscillatorInstrumentData instrument, MidiEvent* event, NoteState* state)
    //{
    //}
    fn renderNote(base: *MidiInstrumentTypeAImpl) void { }
    //static void renderNote(ref OscillatorInstrumentData instrument, NoteState* state,
    //    ubyte[] channels, SamplePoint* buffer)
    //{
    //    pragma(inline, true);

    //    const point = cast(SamplePoint)(
    //        state.base.currentVolume * state.nextSamplePoint * instrument.volumeScale * RenderFormat.MaxAmplitude);
    //    //log(point);
    //    addToEachChannel(channels, buffer, point);

    //    state.nextSamplePoint += state.increment;
    //    if (state.nextSamplePoint >= 1.0)
    //        state.nextSamplePoint -= 2.0;
    //}
};

//struct MidiControlledSample
//{
//    SamplePoint[] points;
//    float skew;
//    ubyte velocityRangeLength;
//}
//
//struct SamplerInstrumentData
//{
//    import audio.midi : MidiNote;
//
//    MidiControlledSample[][] velocitySortedSamplesByNote;
//    float volumeScale;
//    // should I support this?  or maybe even a function?
//    //float midiVelocityScale;
//    ubyte channelCount;
//    this(MidiControlledSample[][] velocitySortedSamplesByNote, float volumeScale, byte channelCount)
//    in { assert(velocitySortedSamplesByNote.length == MidiNote.max + 1); } do
//    {
//        foreach (note, velocitySortedSamples; velocitySortedSamplesByNote)
//        {
//            //logDebug("NOTE ", note, " samplesLength=", velocitySortedSamples.length);
//            ubyte total = 0;
//            foreach (sample; velocitySortedSamples)
//            {
//                /*
//                logDebug("  array.length=", sample.array.length,
//                    " skew=", sample.skew,
//                    " velocityRangeLength=", sample.velocityRangeLength);
//                */
//                ushort next = cast(ushort)total + sample.velocityRangeLength;
//                if (next > ubyte.max)
//                {
//                    logError("velocity samples for note ", note, " range is too large: ", next);
//                    foreach (sample2; velocitySortedSamples)
//                    {
//                        logError("  ", sample2.velocityRangeLength);
//                    }
//                    assert(0, "bad velocity ranges");
//                }
//                total = cast(ubyte)next;
//            }
//        }
//        this.velocitySortedSamplesByNote = velocitySortedSamplesByNote;
//        this.volumeScale = volumeScale;
//        this.channelCount = channelCount;
//    }
//    // returns ubyte.max if there is no samples
//    ubyte getVelocityRangeIndex(MidiNote note, ubyte velocity) const
//    {
//        auto velocitySortedSamples = velocitySortedSamplesByNote[note];
//        if (velocitySortedSamples.length == 0)
//            return ubyte.max;
//        ubyte rangeStart = 0;
//        ubyte index = 0;
//        for (; ; index++)
//        {
//            rangeStart += velocitySortedSamples[index].velocityRangeLength;
//            if (velocity <= rangeStart || index + 1 >= velocitySortedSamples.length)
//                break;
//        }
//        return index;
//    }
//}
//
//
////version = DropSampleInterpolation;
////version = LinearInterpolation;
////version = ParabolicInterpolation;
////version = CatmullRomSpline;
////version = HermiteInterpolation;
//version = OlliOptimal6po5o;
//alias SamplerMidiInstrument = MidiInstrumentTypeA!SamplerMidiInstrumentTypeA;
//struct SamplerMidiInstrumentTypeA
//{
//    import audio.midi : MidiNote;
//
//    alias InstrumentData = SamplerInstrumentData;
//    struct NoteState
//    {
//        mixin Inherit!NoteStateBase;
//        size_t pointsOffset;
//        float timeOffset;
//        float reattackRestoreVolume;
//        ubyte currentSampleVelocityIndex;
//        ubyte reattackVelocity;
//    }
//    static void newNote(ref SamplerInstrumentData data, MidiEvent* event, NoteState* state)
//    {
//        state.pointsOffset = 0;
//        state.timeOffset = 0;
//        state.reattackRestoreVolume = float.nan;
//        state.currentSampleVelocityIndex = data.getVelocityRangeIndex(event.noteOn.note, event.noteOn.velocity);
//    }
//    static void reattackNote(ref SamplerInstrumentData data, MidiEvent* event, NoteState* state)
//    {
//        state.reattackRestoreVolume = state.base.targetVolume;
//        state.reattackVelocity = event.noteOn.velocity;
//        state.base.targetVolume = 0;
//    }
//    static void renderNote(ref SamplerInstrumentData data,
//        NoteState* state, ubyte[] channels, SamplePoint* buffer)
//    {
//        pragma(inline, true);
//
//        if (state.reattackRestoreVolume !is float.nan)
//        {
//            if (state.base.currentVolume == 0)
//            {
//                state.pointsOffset = 0;
//                state.timeOffset = 0;
//                state.base.currentVolume = state.reattackRestoreVolume;
//                state.base.targetVolume = state.reattackRestoreVolume;
//                state.reattackRestoreVolume = float.nan;
//                state.currentSampleVelocityIndex = data.getVelocityRangeIndex(state.base.note, state.reattackVelocity);
//            }
//        }
//
//        if (state.currentSampleVelocityIndex == ubyte.max)
//            return;
//        const sampleStruct = data.velocitySortedSamplesByNote[state.base.note][state.currentSampleVelocityIndex];
//        const points = sampleStruct.points;
//        if (state.pointsOffset + channels.length >= points.length)
//            return; // no sample left to render
//
//            // just do one channel for now
//        if (sampleStruct.skew is float.nan)
//        {
//            foreach (ubyte channel; channels)
//            {
//                //logDebug("no skew");
//                //logDebug(points[state.pointsOffset]);
//                const point = cast(SamplePoint)(
//                    state.base.currentVolume * data.volumeScale * points[state.pointsOffset + channel]);
//                buffer[channel] += point;
//            }
//            state.pointsOffset += data.channelCount;
//        }
//        else
//        {
//            foreach (ubyte channel; channels)
//            {
//                //logDebug("skew ", data.points[state.note].skew);
//                const ss0 = points[state.pointsOffset + channel];
//                const t = state.timeOffset;
//                version (DropSampleInterpolation)
//                    const newSamplePoint = from!"audio.interpolate".DropSample.interpolate(points, state.pointsOffset + channel);
//                else version (LinearInterpolation)
//                    const newSamplePoint = from!"audio.interpolate".Linear.
//                        interpolate(points, state.pointsOffset + channel, state.timeOffset, data.channelCount);
//                else version (ParabolicInterpolation)
//                    const newSamplePoint = from!"audio.interpolate".Parabolic.
//                        interpolate(points, state.pointsOffset + channel, state.timeOffset, data.channelCount);
//                else version (CatmullRomSpline)
//                {
//                    // There is a problem with this,
//                    // it doesn't sound as good as parabolic
//                    /+
//                    // TODO: need to adjust pointsOffset with channel count
//                    const ssneg1 = (state.pointsOffset!!!!!!! > 0) ?
//                        points[state.pointsOffset!!!!!!! - 1] : ss0;
//                    +/
//                    const ss1 = (state.pointsOffset + data.channelCount < points.length) ?
//                        points[state.pointsOffset + data.channelCount] : ss0;
//                    const ss2 = (state.pointsOffset + 2*data.channelCount < points.length) ?
//                        points[state.pointsOffset + 2*data.channelCount] : ss1;
//                    const newSamplePoint = ss0 + 0.5 * t * (
//                        ss1 - ssneg1 + t * (
//                            (2.0*ssneg1 - 5.0*ss0 + 4.0*ss1 - ss2) + t * (
//                                3.0*(ss0 - ss1) + ss2 - ssneg1
//                            )
//                        )
//                    );
//                }
//                else version (HermiteInterpolation)
//                {
//                    // There is a problem with this,
//                    // it doesn't sound as good as parabolic
//                    /+
//                    // TODO: need to adjust pointsOffset with channel count
//                    const ssneg1 = (state.pointsOffset !!!!!!!> 0) ?
//                        points[state.pointsOffset!!!!!!! - 1] : ss0;
//                    +/
//                    const ss1 = (state.pointsOffset + data.channelCount < points.length) ?
//                        points[state.pointsOffset + data.channelCount] : ss0;
//                    const ss2 = (state.pointsOffset + 2*data.channelCount < points.length) ?
//                        points[state.pointsOffset + 2*data.channelCount] : ss1;
//                    const c1 = 0.5 * (ss1 - ssneg1);
//                    const c2 = ssneg1 - 2.5*ss0 + 2*ss1 - 0.5*ss2;
//                    const c3 = 0.5*(ss2 - ssneg1) + 1.5*(ss0 - ss1);
//                    const newSamplePoint = ss0 + t * ( c1 + t * ( c2 + (t * c3)));
//                }
//                else version (OlliOptimal6po5o)
//                {
//                    const newSamplePoint = from!"audio.interpolate".OlliOptimal6po5o.
//                        interpolate(points, state.pointsOffset + channel, state.timeOffset, data.channelCount);
//                }
//                else static assert(0, "no interpolation version selected");
//                //log(newSamplePoint);
//                const newSamplePointScaled = cast(SamplePoint)(
//                    state.base.currentVolume * data.volumeScale * newSamplePoint);
//                //logDebug("channel ", channel, " value ", newSamplePointScaled);
//                buffer[channel] += newSamplePointScaled;
//            }
//            auto nextTimeOffset = state.timeOffset + sampleStruct.skew;
//            for (; nextTimeOffset >= 1.0; nextTimeOffset -= 1.0)
//            {
//                state.pointsOffset += data.channelCount;
//            }
//            state.timeOffset = nextTimeOffset;
//        }
//    }
//}
//
//T stepCloserTo(T)(T value, T target, T increment)
//in { assert(increment > 0); } do
//{
//    if (value < target)
//    {
//        value += increment;
//        if (value > target)
//            value = target;
//    }
//    else
//    {
//        value -= increment;
//        if (value < target)
//            value = target;
//    }
//    return value;
//}
//


//struct MidiInstrumentTypeA(Renderer)
//const MidiInstrumentTypeA = struct {
//fn MidiInstrumentTypeA(comptime Renderer: type) type { return struct {
//};}

const MidiInstrumentTypeA = struct {

//    mixin InheritBaseTemplate!MidiInstrument;
    midiInstrument : MidiInstrument,
//
//    MidiNoteMap!(Renderer.NoteState, ".base.note") notes;
//    Renderer.InstrumentData instrumentData;
    sustainPedal : bool,
    impl: *MidiInstrumentTypeAImpl,
//
    //pub fn init(Renderer.InstrumentData instrumentData) void {
    pub fn init(impl: *MidiInstrumentTypeAImpl) MidiInstrumentTypeA {
        return MidiInstrumentTypeA {
            .midiInstrument = MidiInstrument {
                .audioGenerator = AudioGenerator {
                    .connectOutputNode = connectOutputNode,
                    .disconnectOutputNode = disconnectOutputNode,
                    .renderFinished = renderFinished,
                    .mix = mix,
                },
                .inputNodes = std.ArrayList(*MidiGenerator).init(audio.global.allocator),
            },
            .sustainPedal = false,
            .impl = impl,
        };
//        this.base.base.mix = &mix;
//        this.base.base.connectOutputNode = &connectOutputNode;
//        this.base.base.disconnectOutputNode = &disconnectOutputNode;
//        this.base.base.renderFinished = &renderFinished;
//
//        this.notes.initialize();
//        this.instrumentData = instrumentData;
    }
//
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    // TODO: this function is probably too large to be in a template
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    fn connectOutputNode(base: *AudioGenerator, outputNode: *OutputNode) anyerror!void { }
    fn disconnectOutputNode(base: *AudioGenerator, outputNode: *OutputNode) anyerror!void { }
    fn renderFinished(base: *AudioGenerator, outputNode: *OutputNode) anyerror!void {
//        //logDebug(typeof(this).stringof, " renderFinished ", outputNode);
//        me.asBase.sendInputNodesRenderFinished();
    }
    fn mix(base: *AudioGenerator, channels: []u8, bufferStart: [*]SamplePoint, bufferLimit: [*]SamplePoint) anyerror!void {
        var buffer = bufferStart;
        var frameIndex : u32 = 0;
        while (ptrLessThan(buffer, bufferLimit)) : ({buffer += channels.len; frameIndex += 1;}) {

        }


//    private static void mix(typeof(this)* me, ubyte[] channels, SamplePoint* buffer,
//        const SamplePoint* limit)
//    {
//        foreach (i; 0 .. me.base.inputNodes.length)
//        {
//            auto events = me.base.inputNodes[i].getMidiEvents(me.base.inputNodes[i], me.asBase);
//            if (events.length > 0)
//            handleMidiEvents(me, events);
//        }
//        render(me, channels, buffer, limit);
//    }
//
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    // TODO: this function is probably too large to be in a template
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    private static void handleMidiEvents(typeof(this)* me, MidiEvent[] midiEvents)
//    {
//        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//        // TODO: don't ignore timestamps
//        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//        foreach (event; midiEvents)
//        {
//            switch (event.type)
//            {
//            case MidiEventType.noteOn:
//                // check if it is being released
//                auto state = me.notes.tryGetRef(event.noteOn.note);
//                if (state !is null)
//                {
//                    // TODO: change should be gradual, not immediate
//                    state.base.targetVolume = (event.noteOn.velocity / 127f) * 1.0;
//                    state.base.controlState = NoteControlState.pressed;
//                    Renderer.reattackNote(me.instrumentData, &event, state);
//                }
//                else
//                {
//                    Renderer.NoteState newNoteState = void;
//                    newNoteState.base.currentVolume = event.noteOn.velocity / 127.0 * 1.0;
//                    newNoteState.base.targetVolume = newNoteState.base.currentVolume;
//                    newNoteState.base.releaseMultiplier = 0.9999;// default value
//                    newNoteState.base.note = event.noteOn.note;
//                    newNoteState.base.controlState = NoteControlState.pressed;
//                    Renderer.newNote(me.instrumentData, &event, &newNoteState);
//                    me.notes.set(newNoteState);
//                }
//                break;
//            case MidiEventType.noteOff:
//                auto state = me.notes.tryGetRef(event.noteOff.note);
//                if (state is null)
//                {
//                    logError("note off event for ", event.noteOff.note, " but note is not on? !!!!!!!!!!!!!!");
//                }
//                else
//                {
//                    if (me.sustainPedal)
//                    {
//                        state.base.controlState = NoteControlState.releasedWithSustain;
//                    }
//                    else
//                    {
//                        state.base.controlState = NoteControlState.releasedNoSustain;
//                    }
//                }
//                break;
//            case MidiEventType.sustainPedal:
//                me.sustainPedal = event.sustainPedal;
//                break;
//            default:
//                assert(0, "codebug");
//            }
//        }
    }
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    // TODO: this function is probably too large to be in a template
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//    private static void render(typeof(this)* me, ubyte[] channels, SamplePoint* buffer,
//        const SamplePoint* limit)
//    {
//        // TODO: maybe the buffer loop should be the outer one?
//        //       maybe loop through each cache line, then through each note?
//        for (size_t noteIndex = 0; noteIndex < me.notes.length; noteIndex++)
//        {
//            auto note = me.notes.asArray[noteIndex];
//            bool removeNote = false;
//            //log("Rendering note ", note.note);
//            for (auto next = buffer; next < limit; next += audio.global.channelCount)
//            {
//                // Adjust volume
//                switch (note.base.controlState)
//                {
//                    case NoteControlState.pressed:
//                        if (note.base.targetVolume != note.base.currentVolume)
//                        {
//                            enum VolumeChangeVelocity = 0.001; // note: should take frequency into account
//                            note.base.currentVolume = note.base.currentVolume.stepCloserTo(
//                                note.base.targetVolume, VolumeChangeVelocity);
//                        }
//                        break;
//                    case NoteControlState.releasedWithSustain:
//                        if (!me.sustainPedal)
//                        {
//                            note.base.controlState = NoteControlState.releasedNoSustain;
//                            goto case NoteControlState.releasedNoSustain;
//                        }
//                        break;
//                    case NoteControlState.releasedNoSustain:
//                        note.base.currentVolume *= note.base.releaseMultiplier;
//                        // lower notes don't sound as good when they are released early
//                        enum ReleaseVolumeThreshold = 0.001; // TODO: make this configurable?
//                        if (note.base.currentVolume <= ReleaseVolumeThreshold)
//                        {
//                            //logDebug("release");
//                            removeNote = true;
//                            break;
//                        }
//                        break;
//                    default: assert(0, "codebug");
//                }
//
//                Renderer.renderNote(me.instrumentData, &note, channels, next);
//            }
//
//            if (removeNote)
//            {
//                const result = me.notes.remove(note.base.note);
//                if (result != noteIndex)
//                {
//                    logError("removed note at index ", noteIndex, " but it returned ", result);
//                    assert(0, "codebug");
//                }
//                noteIndex--; // rewind
//            }
//            else
//            {
//                me.notes.set(note); // write back to the array
//            }
//        }
//    }
};
