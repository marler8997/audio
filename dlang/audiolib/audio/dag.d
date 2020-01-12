module audio.dag;

import mar.from;
import mar.passfail;

import audio.log;
import audio.inherits;
import audio.renderformat;
static import audio.global;
import audio.events : AudioEvent, createMidiEventRange;
import audio.midi : MidiNoteMapView, MidiEventType, MidiEvent;

struct AudioGenerator(T)
{
    // NOTE: this tree structure is probably not very cache friendly.
    //       mabye there's a way to flatten out the memory for the render node tree?

    void function(T* me, ubyte[] channels, AudioEvent[] events, RenderFormat.SamplePoint* buffer,
        const RenderFormat.SamplePoint* limit) mix;

    // Some generators may need to know how many output nodes are connected
    passfail function(T* me, void* outputNode) connectOutputNode;
    // Some generators may need to know how many output nodes are connected
    passfail function(T* me, void* outputNode) disconnectOutputNode;

    // This let's the audio generator that is can clean up any state for this frame.
    // This function must be called after each buffer is done being rendered.
    // This function may be called more than once before the next mix/set call.
    void function(T* me, void* outputNode) renderFinished;
}

// A node that inputs midi notes
struct MidiInstrument(T)
{
    import mar.arraybuilder;

    //
    // New Interface
    //
    mixin ForwardInheritBaseTemplate!(AudioGenerator, T);
    ArrayBuilder!(MidiSubAudioGenerator!void*) inputNodes;

    static if (is(T == void))
    {
        final void sendInputNodesRenderFinished()
        {
            foreach (i; 0 .. inputNodes.length)
            {
                inputNodes[i].renderFinished(inputNodes[i], &this);
            }
        }
        final passfail tryAddInputNode(MidiSubAudioGenerator!void* inputNode)
        {
            if (inputNodes.tryPut(inputNode).failed)
                return passfail.fail;

            return passfail.pass;
        }
    }
}

struct MidiSubAudioGenerator(T)
{
    // Some generators may need to know how many output nodes are connected
    passfail function(T* me, void* outputNode) connectOutputNode;
    // Some generators may need to know how many output nodes are connected
    passfail function(T* me, void* outputNode) disconnectOutputNode;

    // This let's the audio generator that is can clean up any state for this frame.
    // This function must be called after each buffer is done being rendered.
    // This function may be called more than once before the next mix/set call.
    void function(T* me, void* outputNode) renderFinished;

    void function(T* me, AudioEvent midiEvent) handleMidiEvent;

    void function(T* me, ubyte[] channels, RenderFormat.SamplePoint* buffer,
        const RenderFormat.SamplePoint* limit) mix;
}

// Takes a MidiAudioGenerator and takes midi events and forwards them to
// the underlying MidiAudioGenerator during the render
struct MidiAudioGenerator
{
    /*
    import audio.midi : MidiNote, MidiNoteMap;
    */
    mixin InheritBaseTemplate!AudioGenerator;
    MidiSubAudioGenerator!void* generator;


    void initialize(MidiSubAudioGenerator!void* generator)
    {
        this.base.mix = &mix;
        this.base.connectOutputNode = &connectOutputNode;
        this.base.disconnectOutputNode = &disconnectOutputNode;
        this.base.renderFinished = &renderFinished;

        this.generator = generator;
    }

    static passfail connectOutputNode(typeof(this)* me, void* outputNode)
    {
        return me.generator.connectOutputNode(me.generator, outputNode);
    }
    static passfail disconnectOutputNode(typeof(this)* me, void* outputNode)
    {
        return me.generator.disconnectOutputNode(me.generator, outputNode);
    }
    static void renderFinished(typeof(this)* me, void* outputNode)
    {
        return me.generator.renderFinished(me.generator, outputNode);
    }

    private static void mix(typeof(this)* me, ubyte[] channels, AudioEvent[] events,
        RenderFormat.SamplePoint* buffer, const RenderFormat.SamplePoint* limit)
    {
        RenderFormat.SamplePoint* nextBuffer = buffer;
        auto eventRange = createMidiEventRange(events);
        for (;;)
        {
            RenderFormat.SamplePoint* nextLimit;
            if (eventRange.empty)
                nextLimit = cast(typeof(nextLimit))limit;
            else
            {
                auto event = eventRange.front;
                nextLimit = buffer + (audio.global.channelCount * event.samplesSinceRender);
                assert(nextLimit >= nextBuffer && nextLimit <= limit);
                me.generator.handleMidiEvent(me.generator, event);
                eventRange.popFront;
            }
            me.generator.mix(me.generator, channels, nextBuffer, nextLimit);
            if (nextLimit == limit)
                break;
            nextBuffer = nextLimit;
        }
    }
}

MidiAudioGenerator createMidiAudioGenerator(T)()
{
    MidiAudioGenerator generator = void;
    generator.initialize();
}


/// Generates midi events
struct MidiGenerator(T)
{
    // MidiInput nodes may or may not want to know all the instruments that are
    // going to request events from them.
    //void function(T* context, void* instrument) connectInstrument;

    //MidiEvent[] function(T* context, MidiInstrument!void* instrument) getMidiEvents;

    // This let's the midi input node that it can now clean up all it's events.
    // This function must be called after each buffer is done being rendered.
    void function(T* context, MidiInstrument!void* instrument) renderFinished;
}

struct MidiGeneratorTemplate(InputDevice)
{
    import mar.arraybuilder : ArrayBuilder;
    import audio.midi : MidiNote, MidiNoteMap;

    mixin InheritBaseTemplate!MidiGenerator;
    //bool[MidiNote.max + 1] onMap;
    //ArrayBuilder!MidiEvent midiEvents;
    InputDevice inputDevice;

    final void initialize()
    {
        //this.base.getMidiEvents = &getMidiEvents;
        this.base.renderFinished = &renderFinished;
    }

    // returns: false if it was already on
    final auto tryAddMidiEvent(MidiEvent event)
    {
        import audio.render : enterRenderCriticalSection, exitRenderCriticalSection;

        enterRenderCriticalSection();
        scope (exit) exitRenderCriticalSection();
        // TODO: make sure it is in order by timestamp
        const result = midiEvents.tryPut(event);
        return result;
        //return midiEvents.tryPut(event);
    }

    /*
    static MidiEvent[] getMidiEvents(typeof(this)* me, MidiInstrument!void* instrument)
    {
        //if (me.midiEvents.data.length > 0) logDebug("returning ", me.midiEvents.length, " midi events");
        return me.midiEvents.data;
    }
    */
    static void renderFinished(typeof(this)* me, MidiInstrument!void* instrument)
    {
        me.midiEvents.shrinkTo(0);
    }
    //
    // Input Device forwarding functions
    //
    final passfail stopMidiDeviceInput(T...)(T args)
    {
        pragma(inline, true);
        return InputDevice.stopMidiDeviceInput(&this, args);
    }
    final passfail startMidiDeviceInput(T...)(T args)
    {
        pragma(inline, true);
        return InputDevice.startMidiDeviceInput(&this, args);
    }
}

void addToEachChannel(ubyte[] channels, RenderFormat.SamplePoint* buffer, RenderFormat.SamplePoint value)
{
    foreach (channel; channels)
    {
        buffer[channel] += value;
    }
}

enum NoteControlState
{
    pressed, // the note is being pressed
    releasedWithSustain, // the was released with the sustain pedal
    releasedNoSustain, // the note was released and is no longer sustaining
}

/*
struct ChannelMapping
{
    private ubyte* mapping;
    ubyte length;
    this(ubyte* mapping, ubyte length)
    {
        this.mapping = mapping;
        this.length = length;
    }
    this(ubyte[] mapping)
    in { assert(mapping.length <= ubyte.max); } do
    {
        this.mapping = mapping.ptr;
        this.length = cast(ubyte)mapping.length;
    }
    void addToChannel(RenderFormat.SamplePoint* buffer, RenderFormat.SamplePoint value, ubyte mappingIndex)
    in { assert(mappingIndex < length); } do
    {
        buffer[mapping[mappingIndex]] += value;
    }
}
*/

struct NoteStateBase
{
    import audio.midi : MidiNote;

    float currentVolume;
    float targetVolume;
    float releaseMultiplier;
    MidiNote note; // save so we can easily remove the note from the MidiNoteMap
    NoteControlState controlState;
}

struct OscillatorInstrumentData
{
    float volumeScale;
}

alias SinOscillatorMidiInstrument = MidiInstrumentTypeA!SinOscillatorMidiInstrumentTypeA;
struct SinOscillatorMidiInstrumentTypeA
{
    import audio.midi : MidiNote, defaultFreq;

    enum TWO_PI = 3.14159265358979 * 2;
    alias InstrumentData = OscillatorInstrumentData;
    struct NoteState
    {
        mixin Inherit!NoteStateBase;
        float phaseIncrement;
        float phase;
    }
    static void newNote(ref OscillatorInstrumentData instrument, MidiEvent* event, NoteState* state)
    {
        state.phaseIncrement = TWO_PI * defaultFreq[event.noteOn.note] / audio.global.sampleFramesPerSec;
        state.phase = 0;
    }
    static void reattackNote(ref OscillatorInstrumentData instrument, MidiEvent* event, NoteState* state)
    {
    }
    static void renderNote(ref OscillatorInstrumentData instrument, NoteState* state,
        ubyte[] channels, RenderFormat.SamplePoint* buffer)
    {
        pragma(inline, true);

        import mar.math : sin;

        addToEachChannel(channels, buffer, cast(RenderFormat.SamplePoint)(
                state.base.currentVolume * sin(state.phase) * instrument.volumeScale * RenderFormat.MaxAmplitude));

        state.phase += state.phaseIncrement;
        if(state.phase > TWO_PI)
            state.phase -= TWO_PI;
    }
}

private float sawFrequencyToIncrement(float frequency)
{
    return frequency / audio.global.sampleFramesPerSec;
}

alias SawOscillatorMidiInstrument = MidiInstrumentTypeA!SawOscillatorMidiInstrumentTypeA;
struct SawOscillatorMidiInstrumentTypeA
{
    import audio.midi : MidiNote, defaultFreq;

    alias InstrumentData = OscillatorInstrumentData;
    struct NoteState
    {
        mixin Inherit!NoteStateBase;
        float nextSamplePoint;
        float increment;
    }
    static void newNote(ref OscillatorInstrumentData instrument, MidiEvent* event, NoteState* state)
    {
        state.nextSamplePoint = 0;
        state.increment = sawFrequencyToIncrement(defaultFreq[event.noteOn.note]);
    }
    static void reattackNote(ref OscillatorInstrumentData instrument, MidiEvent* event, NoteState* state)
    {
    }
    static void renderNote(ref OscillatorInstrumentData instrument, NoteState* state,
        ubyte[] channels, RenderFormat.SamplePoint* buffer)
    {
        pragma(inline, true);

        const point = cast(RenderFormat.SamplePoint)(
            state.base.currentVolume * state.nextSamplePoint * instrument.volumeScale * RenderFormat.MaxAmplitude);
        //log(point);
        addToEachChannel(channels, buffer, point);

        state.nextSamplePoint += state.increment;
        if (state.nextSamplePoint >= 1.0)
            state.nextSamplePoint -= 2.0;
    }
}

struct MidiControlledSample
{
    RenderFormat.SamplePoint[] points;
    float skew;
    ubyte velocityRangeLength;
}

struct SamplerInstrumentData
{
    import audio.midi : MidiNote;

    MidiControlledSample[][] velocitySortedSamplesByNote;
    float volumeScale;
    // should I support this?  or maybe even a function?
    //float midiVelocityScale;
    ubyte channelCount;
    this(MidiControlledSample[][] velocitySortedSamplesByNote, float volumeScale, byte channelCount)
    in { assert(velocitySortedSamplesByNote.length == MidiNote.max + 1); } do
    {
        foreach (note, velocitySortedSamples; velocitySortedSamplesByNote)
        {
            //logDebug("NOTE ", note, " samplesLength=", velocitySortedSamples.length);
            ubyte total = 0;
            foreach (sample; velocitySortedSamples)
            {
                /*
                logDebug("  array.length=", sample.array.length,
                    " skew=", sample.skew,
                    " velocityRangeLength=", sample.velocityRangeLength);
                */
                ushort next = cast(ushort)total + sample.velocityRangeLength;
                if (next > ubyte.max)
                {
                    logError("velocity samples for note ", note, " range is too large: ", next);
                    foreach (sample2; velocitySortedSamples)
                    {
                        logError("  ", sample2.velocityRangeLength);
                    }
                    assert(0, "bad velocity ranges");
                }
                total = cast(ubyte)next;
            }
        }
        this.velocitySortedSamplesByNote = velocitySortedSamplesByNote;
        this.volumeScale = volumeScale;
        this.channelCount = channelCount;
    }
    // returns ubyte.max if there is no samples
    ubyte getVelocityRangeIndex(MidiNote note, ubyte velocity) const
    {
        auto velocitySortedSamples = velocitySortedSamplesByNote[note];
        if (velocitySortedSamples.length == 0)
            return ubyte.max;
        ubyte rangeStart = 0;
        ubyte index = 0;
        for (; ; index++)
        {
            rangeStart += velocitySortedSamples[index].velocityRangeLength;
            if (velocity <= rangeStart || index + 1 >= velocitySortedSamples.length)
                break;
        }
        return index;
    }
}


//version = DropSampleInterpolation;
//version = LinearInterpolation;
//version = ParabolicInterpolation;
//version = CatmullRomSpline;
//version = HermiteInterpolation;
version = OlliOptimal6po5o;
alias SamplerMidiInstrument = MidiInstrumentTypeA!SamplerMidiInstrumentTypeA;
struct SamplerMidiInstrumentTypeA
{
    import audio.midi : MidiNote;

    alias InstrumentData = SamplerInstrumentData;
    struct NoteState
    {
        mixin Inherit!NoteStateBase;
        size_t pointsOffset;
        float timeOffset;
        float reattackRestoreVolume;
        ubyte currentSampleVelocityIndex;
        ubyte reattackVelocity;
    }
    static void newNote(ref SamplerInstrumentData data, MidiEvent* event, NoteState* state)
    {
        state.pointsOffset = 0;
        state.timeOffset = 0;
        state.reattackRestoreVolume = float.nan;
        state.currentSampleVelocityIndex = data.getVelocityRangeIndex(event.noteOn.note, event.noteOn.velocity);
    }
    static void reattackNote(ref SamplerInstrumentData data, MidiEvent* event, NoteState* state)
    {
        state.reattackRestoreVolume = state.base.targetVolume;
        state.reattackVelocity = event.noteOn.velocity;
        state.base.targetVolume = 0;
    }
    static void renderNote(ref SamplerInstrumentData data,
        NoteState* state, ubyte[] channels, RenderFormat.SamplePoint* buffer)
    {
        pragma(inline, true);

        if (state.reattackRestoreVolume !is float.nan)
        {
            if (state.base.currentVolume == 0)
            {
                state.pointsOffset = 0;
                state.timeOffset = 0;
                state.base.currentVolume = state.reattackRestoreVolume;
                state.base.targetVolume = state.reattackRestoreVolume;
                state.reattackRestoreVolume = float.nan;
                state.currentSampleVelocityIndex = data.getVelocityRangeIndex(state.base.note, state.reattackVelocity);
            }
        }

        if (state.currentSampleVelocityIndex == ubyte.max)
            return;
        const sampleStruct = data.velocitySortedSamplesByNote[state.base.note][state.currentSampleVelocityIndex];
        const points = sampleStruct.points;
        if (state.pointsOffset + channels.length >= points.length)
            return; // no sample left to render

            // just do one channel for now
        if (sampleStruct.skew is float.nan)
        {
            foreach (ubyte channel; channels)
            {
                //logDebug("no skew");
                //logDebug(points[state.pointsOffset]);
                const point = cast(RenderFormat.SamplePoint)(
                    state.base.currentVolume * data.volumeScale * points[state.pointsOffset + channel]);
                buffer[channel] += point;
            }
            state.pointsOffset += data.channelCount;
        }
        else
        {
            foreach (ubyte channel; channels)
            {
                //logDebug("skew ", data.points[state.note].skew);
                const ss0 = points[state.pointsOffset + channel];
                const t = state.timeOffset;
                version (DropSampleInterpolation)
                    const newSamplePoint = from!"audio.interpolate".DropSample.interpolate(points, state.pointsOffset + channel);
                else version (LinearInterpolation)
                    const newSamplePoint = from!"audio.interpolate".Linear.
                        interpolate(points, state.pointsOffset + channel, state.timeOffset, data.channelCount);
                else version (ParabolicInterpolation)
                    const newSamplePoint = from!"audio.interpolate".Parabolic.
                        interpolate(points, state.pointsOffset + channel, state.timeOffset, data.channelCount);
                else version (CatmullRomSpline)
                {
                    // There is a problem with this,
                    // it doesn't sound as good as parabolic
                    /+
                    // TODO: need to adjust pointsOffset with channel count
                    const ssneg1 = (state.pointsOffset!!!!!!! > 0) ?
                        points[state.pointsOffset!!!!!!! - 1] : ss0;
                    +/
                    const ss1 = (state.pointsOffset + data.channelCount < points.length) ?
                        points[state.pointsOffset + data.channelCount] : ss0;
                    const ss2 = (state.pointsOffset + 2*data.channelCount < points.length) ?
                        points[state.pointsOffset + 2*data.channelCount] : ss1;
                    const newSamplePoint = ss0 + 0.5 * t * (
                        ss1 - ssneg1 + t * (
                            (2.0*ssneg1 - 5.0*ss0 + 4.0*ss1 - ss2) + t * (
                                3.0*(ss0 - ss1) + ss2 - ssneg1
                            )
                        )
                    );
                }
                else version (HermiteInterpolation)
                {
                    // There is a problem with this,
                    // it doesn't sound as good as parabolic
                    /+
                    // TODO: need to adjust pointsOffset with channel count
                    const ssneg1 = (state.pointsOffset !!!!!!!> 0) ?
                        points[state.pointsOffset!!!!!!! - 1] : ss0;
                    +/
                    const ss1 = (state.pointsOffset + data.channelCount < points.length) ?
                        points[state.pointsOffset + data.channelCount] : ss0;
                    const ss2 = (state.pointsOffset + 2*data.channelCount < points.length) ?
                        points[state.pointsOffset + 2*data.channelCount] : ss1;
                    const c1 = 0.5 * (ss1 - ssneg1);
                    const c2 = ssneg1 - 2.5*ss0 + 2*ss1 - 0.5*ss2;
                    const c3 = 0.5*(ss2 - ssneg1) + 1.5*(ss0 - ss1);
                    const newSamplePoint = ss0 + t * ( c1 + t * ( c2 + (t * c3)));
                }
                else version (OlliOptimal6po5o)
                {
                    const newSamplePoint = from!"audio.interpolate".OlliOptimal6po5o.
                        interpolate(points, state.pointsOffset + channel, state.timeOffset, data.channelCount);
                }
                else static assert(0, "no interpolation version selected");
                //log(newSamplePoint);
                const newSamplePointScaled = cast(RenderFormat.SamplePoint)(
                    state.base.currentVolume * data.volumeScale * newSamplePoint);
                //logDebug("channel ", channel, " value ", newSamplePointScaled);
                buffer[channel] += newSamplePointScaled;
            }
            auto nextTimeOffset = state.timeOffset + sampleStruct.skew;
            for (; nextTimeOffset >= 1.0; nextTimeOffset -= 1.0)
            {
                state.pointsOffset += data.channelCount;
            }
            state.timeOffset = nextTimeOffset;
        }
    }
}

T stepCloserTo(T)(T value, T target, T increment)
in { assert(increment > 0); } do
{
    if (value < target)
    {
        value += increment;
        if (value > target)
            value = target;
    }
    else
    {
        value -= increment;
        if (value < target)
            value = target;
    }
    return value;
}

struct MidiInstrumentTypeA(Renderer)
{
    import audio.midi : MidiNote, MidiNoteMap;

    mixin InheritBaseTemplate!MidiSubAudioGenerator;

    MidiNoteMap!(Renderer.NoteState, ".base.note") notes;
    Renderer.InstrumentData instrumentData;
    bool sustainPedal;

    void initialize(Renderer.InstrumentData instrumentData)
    {
        this.base.base.mix = &mix;
        this.base.base.connectOutputNode = &connectOutputNode;
        this.base.base.disconnectOutputNode = &disconnectOutputNode;
        this.base.base.renderFinished = &renderFinished;

        this.notes.initialize();
        this.instrumentData = instrumentData;
    }

    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // TODO: this function is probably too large to be in a template
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    static passfail connectOutputNode(typeof(this)* me, void* outputNode)
    {
        logDebug(typeof(this).stringof, " connectOutputNode ", outputNode);
        return passfail.pass;
    }
    static passfail disconnectOutputNode(typeof(this)* me, void* outputNode)
    {
        logDebug(typeof(this).stringof, " disconnectOutputNode ", outputNode);
        return passfail.pass;
    }
    static void renderFinished(typeof(this)* me, void* outputNode)
    {
        //logDebug(typeof(this).stringof, " renderFinished ", outputNode);
        me.asBase.sendInputNodesRenderFinished();
    }

    private static void mix(typeof(this)* me, ubyte[] channels, AudioEvent[] events,
        RenderFormat.SamplePoint* buffer, const RenderFormat.SamplePoint* limit)
    {
        assert(0, "REMOVE THIS CODE, HANDLING EVENTS DIFFERENTLY NOW!");
        /*
        foreach (i; 0 .. me.base.inputNodes.length)
        {
            auto events = me.base.inputNodes[i].getMidiEvents(me.base.inputNodes[i], me.asBase);
            if (events.length > 0)
            handleMidiEvents(me, events);
        }
        render(me, channels, buffer, limit);
        */
    }

    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // TODO: this function is probably too large to be in a template
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    private static void handleMidiEvents(typeof(this)* me, MidiEvent[] midiEvents)
    {
        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        // TODO: don't ignore timestamps
        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        foreach (event; midiEvents)
        {
            switch (event.type)
            {
            case MidiEventType.noteOn:
                // check if it is being released
                auto state = me.notes.tryGetRef(event.noteOn.note);
                if (state !is null)
                {
                    // TODO: change should be gradual, not immediate
                    state.base.targetVolume = (event.noteOn.velocity / 127f) * 1.0;
                    state.base.controlState = NoteControlState.pressed;
                    Renderer.reattackNote(me.instrumentData, &event, state);
                }
                else
                {
                    Renderer.NoteState newNoteState = void;
                    newNoteState.base.currentVolume = event.noteOn.velocity / 127.0 * 1.0;
                    newNoteState.base.targetVolume = newNoteState.base.currentVolume;
                    newNoteState.base.releaseMultiplier = 0.9999;// default value
                    newNoteState.base.note = event.noteOn.note;
                    newNoteState.base.controlState = NoteControlState.pressed;
                    Renderer.newNote(me.instrumentData, &event, &newNoteState);
                    me.notes.set(newNoteState);
                }
                break;
            case MidiEventType.noteOff:
                auto state = me.notes.tryGetRef(event.noteOff.note);
                if (state is null)
                {
                    logError("note off event for ", event.noteOff.note, " but note is not on? !!!!!!!!!!!!!!");
                }
                else
                {
                    if (me.sustainPedal)
                    {
                        state.base.controlState = NoteControlState.releasedWithSustain;
                    }
                    else
                    {
                        state.base.controlState = NoteControlState.releasedNoSustain;
                    }
                }
                break;
            case MidiEventType.sustainPedal:
                me.sustainPedal = event.sustainPedal;
                break;
            default:
                assert(0, "codebug");
            }
        }
    }
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // TODO: this function is probably too large to be in a template
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    private static void render(typeof(this)* me, ubyte[] channels, RenderFormat.SamplePoint* buffer,
        const RenderFormat.SamplePoint* limit)
    {
        // TODO: maybe the buffer loop should be the outer one?
        //       maybe loop through each cache line, then through each note?
        for (size_t noteIndex = 0; noteIndex < me.notes.length; noteIndex++)
        {
            auto note = me.notes.asArray[noteIndex];
            bool removeNote = false;
            //log("Rendering note ", note.note);
            for (auto next = buffer; next < limit; next += audio.global.channelCount)
            {
                // Adjust volume
                switch (note.base.controlState)
                {
                    case NoteControlState.pressed:
                        if (note.base.targetVolume != note.base.currentVolume)
                        {
                            enum VolumeChangeVelocity = 0.001; // note: should take frequency into account
                            note.base.currentVolume = note.base.currentVolume.stepCloserTo(
                                note.base.targetVolume, VolumeChangeVelocity);
                        }
                        break;
                    case NoteControlState.releasedWithSustain:
                        if (!me.sustainPedal)
                        {
                            note.base.controlState = NoteControlState.releasedNoSustain;
                            goto case NoteControlState.releasedNoSustain;
                        }
                        break;
                    case NoteControlState.releasedNoSustain:
                        note.base.currentVolume *= note.base.releaseMultiplier;
                        // lower notes don't sound as good when they are released early
                        enum ReleaseVolumeThreshold = 0.001; // TODO: make this configurable?
                        if (note.base.currentVolume <= ReleaseVolumeThreshold)
                        {
                            //logDebug("release");
                            removeNote = true;
                            break;
                        }
                        break;
                    default: assert(0, "codebug");
                }

                Renderer.renderNote(me.instrumentData, &note, channels, next);
            }

            if (removeNote)
            {
                const result = me.notes.remove(note.base.note);
                if (result != noteIndex)
                {
                    logError("removed note at index ", noteIndex, " but it returned ", result);
                    assert(0, "codebug");
                }
                noteIndex--; // rewind
            }
            else
            {
                me.notes.set(note); // write back to the array
            }
        }
    }
}
