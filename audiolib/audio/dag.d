module audio.dag;

import mar.from;
import mar.passfail;

import audio.log;
import audio.renderformat;
static import audio.global;
import audio.midi : MidiNoteMapView;

// TODO: move this?
mixin template Inherit(T)
{
    T base;
    static assert(base.offsetof == 0, "Inherit!(" ~ T.stringof ~ ") needs to be the first field with offset 0");
    final auto asBase() inout { return cast(T*)&this; }
}

//
// A "BaseTemplate" is a pattern where the base type is a template that takes a
// type that will only be referenced as a pointer. This means that every template instance
// should have the same binary implementation. So:
//     BaseTemplate!void should be equivalent to any BaseTemplate!T
//
mixin template InheritBaseTemplate(alias Template)
{
    // verify this is a valid BaseTemplate
    static assert(Template!void.sizeof == Template!(typeof(this)).sizeof);

    Template!(typeof(this)) base;
    static assert(base.offsetof == 0, "InheritTemplateVoidBase!(" ~ T.stringof ~ ") needs to be the first field with offset 0");
    final auto asBase() inout { return cast(Template!void*)&this; }
}

/*
struct AudioGenerator(T)
{
    // NOTE: this tree structure is not very cache friendly
    //       should flatten out the memory for the render node tree
    //ArrayBuilder!(Node!void) children;
    void function(T* context, ubyte[] channels, void* renderBuffer, const void* limit) mix;
}
*/


// A node with no inputs
struct RootRenderNode(T)
{
    // NOTE: this tree structure is not very cache friendly
    //       should flatten out the memory for the render node tree
    //ArrayBuilder!(Node!void) children;
    void function(T* context, ubyte[] channels, void* renderBuffer, const void* limit) renderNextBuffer;
}


enum MidiEventType : ubyte
{
    noteOn = 0,
    noteOff = 1,
    sustainPedal = 2,
}
struct MidiEvent
{
    import audio.midi : MidiNote;

    size_t timestamp;
    MidiEventType type;
    union
    {
        private static struct NoteOn
        {
            MidiNote note;
            ubyte velocity;
        }
        NoteOn noteOn;
        private static struct NoteOff
        {
            MidiNote note;
            ubyte velocity;
        }
        NoteOff noteOff;
        bool sustainPedal;
    }
    static makeNoteOn(size_t timestamp, MidiNote note, ubyte velocity)
    {
        MidiEvent event = void;
        event.timestamp = timestamp;
        event.type = MidiEventType.noteOn;
        event.noteOn.note = note;
        event.noteOn.velocity = velocity;
        return event;
    }
    static makeNoteOff(size_t timestamp, MidiNote note)
    {
        MidiEvent event = void;
        event.timestamp = timestamp;
        event.type = MidiEventType.noteOff;
        event.noteOff.note = note;
        return event;
    }
    static makeSustainPedal(size_t timestamp, bool on)
    {
        MidiEvent event = void;
        event.timestamp = timestamp;
        event.type = MidiEventType.sustainPedal;
        event.sustainPedal = on;
        return event;
    }
}

// A node that inputs midi notes
struct MidiInstrument(T)
{
    void function(T* context, ubyte[] channels, void* renderBuffer, const void* limit, MidiEvent[] midiEvents) renderNextBuffer;
}

/**
BUG
The program won't compile unless I leave the following import in.
Even though this import is not used at all, when I remove it I get these errors:
    D:\git\mar\src\mar\array.d(326): Error: variable `mar.array.StaticArray!(NoteState, 128u).StaticArray.opIndex.this` inout variables can only be declared inside inout functions
    D:\git\audio\audiolib\audio\midi\package.d(307): Error: struct `mar.array.StaticArray!(NoteState, 128u).StaticArray` member opIndex is not accessible
    D:\git\audio\audiolib\audio\midi\package.d(311): Error: struct `mar.array.StaticArray!(NoteState, 128u).StaticArray` member length is not accessible
    D:\git\mar\src\mar\array.d(331): Error: size of type MemoryResult is not known
    D:\git\mar\src\mar\array.d(331): Error: size of type MemoryResult is not known
    D:\git\mar\src\mar\array.d(334): Error: forward reference to type MemoryResult
    D:\git\mar\src\mar\array.d(337): Error: forward reference to type MemoryResult
    D:\git\audio\audiolib\audio\midi\package.d(313): Error: struct `mar.array.StaticArray!(NoteState, 128u).StaticArray` member tryPut is not accessible
    D:\git\audio\audiolib\audio\midi\package.d(287): Error: struct `mar.array.StaticArray!(NoteState, 128u).StaticArray` member length is not accessible
    D:\git\mar\src\mar\array.d(327): Error: forward reference to type T[]
    D:\git\audio\audiolib\audio\midi\package.d(288): Error: struct `mar.array.StaticArray!(NoteState, 128u).StaticArray` member data is not accessible
    D:\git\audio\audiolib\audio\midi\package.d(323): Error: struct `mar.array.StaticArray!(NoteState, 128u).StaticArray` member removeAt is not accessible
    D:\git\audio\audiolib\audio\midi\package.d(324): Error: struct `mar.array.StaticArray!(NoteState, 128u).StaticArray` member length is not accessible
    D:\git\audio\audiolib\audio\midi\package.d-mixin-326(326): Error: struct `mar.array.StaticArray!(NoteState, 128u).StaticArray` member opIndex is not accessible
    D:\git\audio\audiolib\audio\midi\package.d(297): Error: struct `mar.array.StaticArray!(NoteState, 128u).StaticArray` member opIndex is not accessible
    D:\git\audio\audiolib\audio\midi\package.d-mixin-337(337): Error: struct `mar.array.StaticArray!(NoteState, 128u).StaticArray` member opIndex is not accessible
    D:\git\audio\audiolib\audio\midi\package.d(338): Error: struct `mar.array.StaticArray!(NoteState, 128u).StaticArray` member removeAt is not accessible
    D:\git\audio\audiolib\audio\midi\package.d(339): Error: struct `mar.array.StaticArray!(NoteState, 128u).StaticArray` member length is not accessible
    D:\git\audio\audiolib\audio\midi\package.d-mixin-341(341): Error: struct `mar.array.StaticArray!(NoteState, 128u).StaticArray` member opIndex is not accessible
    D:\git\audio\audiolib\audio\midi\package.d(333): Error: struct `mar.array.StaticArray!(NoteState, 128u).StaticArray` member length is not accessible
*/
import audio.windowsmidi : WindowsMidiInputDevice;
struct MidiInputNodeTemplate(InputDevice)
{
    import mar.arraybuilder : ArrayBuilder;
    import audio.render : RenderState;
    import audio.midi : MidiNote, MidiNoteMap;

    mixin InheritBaseTemplate!RootRenderNode;
    private ArrayBuilder!(MidiInstrument!void*) instruments;
    //bool[MidiNote.max + 1] onMap;
    ArrayBuilder!MidiEvent midiEvents;
    InputDevice inputDevice;

    final void initialize()
    {
        this.base.renderNextBuffer = &renderNextBuffer;
    }

    final passfail tryAddInstrument(MidiInstrument!void* instrument)
    {
        if (instruments.tryPut(instrument).failed)
            return passfail.fail;
        // Forward the current state
        /*
        foreach (note; 0 .. onMap.length)
        {
            if (onMap[note])
                instrument.midiEvent(instrument, cast(MidiNote)note, true);
        }
        */
        return passfail.pass;
    }

    // returns: false if it was already on
    final auto tryAddMidiEvent(MidiEvent event)
    {
        import audio.render : enterRenderCriticalSection, exitRenderCriticalSection;

        enterRenderCriticalSection();
        scope (exit) exitRenderCriticalSection();
        // TODO: make sure it is in order by timestamp
        return midiEvents.tryPut(event);
    }

    static void renderNextBuffer(typeof(this)/*!InputDevice*/* me, ubyte[] channels, void* renderBuffer, const void* limit)
    {
        foreach (instrument; me.instruments.data)
        {
            instrument.renderNextBuffer(instrument, channels, renderBuffer, limit, me.midiEvents.data);
        }
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

void addToEachChannel(ubyte[] channels, RenderFormat.SampleType* buffer, RenderFormat.SampleType value)
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
    void addToChannel(RenderFormat.SampleType* buffer, RenderFormat.SampleType value, ubyte mappingIndex)
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

alias SinOscillatorMidiInstrument(Format) = MidiInstrumentTypeA!(SinOscillatorMidiInstrumentTypeA!Format);
struct SinOscillatorMidiInstrumentTypeA(Format)
{
    import audio.midi : MidiNote, stdFreq;

    enum TWO_PI = 3.14159265358979 * 2;
    alias FormatAlias = Format;
    alias InstrumentData = OscillatorInstrumentData;
    struct NoteState
    {
        mixin Inherit!NoteStateBase;
        float phaseIncrement;
        float phase;
    }
    static void newNote(ref OscillatorInstrumentData instrument, MidiEvent* event, NoteState* state)
    {
        state.phaseIncrement = TWO_PI * stdFreq[event.noteOn.note] / audio.global.samplesPerSec;
        state.phase = 0;
    }
    static void reattackNote(ref OscillatorInstrumentData instrument, MidiEvent* event, NoteState* state)
    {
    }
    static void renderNote(ref OscillatorInstrumentData instrument, NoteState* state,
        ubyte[] channels, RenderFormat.SampleType* buffer)
    {
        pragma(inline, true);

        import mar.math : sin;

        addToEachChannel(channels, buffer, cast(Format.SampleType)(
                state.currentVolume * sin(state.phase) * instrument.volumeScale * Format.MaxAmplitude));

        state.phase += state.phaseIncrement;
        if(state.phase > TWO_PI)
            state.phase -= TWO_PI;
    }
}
alias SawOscillatorMidiInstrument(Format) = MidiInstrumentTypeA!(SawOscillatorMidiInstrumentTypeA!Format);
struct SawOscillatorMidiInstrumentTypeA(Format)
{
    import audio.midi : MidiNote, stdFreq;

    alias FormatAlias = Format;
    alias InstrumentData = OscillatorInstrumentData;
    struct NoteState
    {
        mixin Inherit!NoteStateBase;
        float nextSample;
        float increment;
    }
    static void newNote(ref OscillatorInstrumentData instrument, MidiEvent* event, NoteState* state)
    {
        state.nextSample = 0;
        state.increment = stdFreq[event.noteOn.note] / audio.global.samplesPerSec;
    }
    static void reattackNote(ref OscillatorInstrumentData instrument, MidiEvent* event, NoteState* state)
    {
    }
    static void renderNote(ref OscillatorInstrumentData instrument, NoteState* state,
        ubyte[] channels, RenderFormat.SampleType* buffer)
    {
        pragma(inline, true);

        addToEachChannel(channels, buffer, cast(Format.SampleType)(
            state.currentVolume * state.nextSample * instrument.volumeScale * Format.MaxAmplitude));

        state.nextSample += state.increment;
        if (state.nextSample >= 1.0)
            state.nextSample -= 2.0;
    }
}

struct MidiControlledSample
{
    RenderFormat.SampleType[] array;
    float skew;
    ubyte velocityRangeLength;
}

struct SampleInstrumentData
{
    import audio.midi : MidiNote;

    MidiControlledSample[][] velocitySortedSamplesByNote;
    float volumeScale;
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
                assert(cast(ushort)total + sample.velocityRangeLength <= ubyte.max);
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

    alias FormatAlias = RenderFormat;
    alias InstrumentData = SampleInstrumentData;
    struct NoteState
    {
        mixin Inherit!NoteStateBase;
        size_t sampleIndex;
        float timeOffset;
        float reattackRestoreVolume;
        ubyte currentSampleVelocityIndex;
        ubyte reattackVelocity;
    }
    static void newNote(ref SampleInstrumentData data, MidiEvent* event, NoteState* state)
    {
        state.sampleIndex = 0;
        state.timeOffset = 0;
        state.reattackRestoreVolume = float.nan;
        state.currentSampleVelocityIndex = data.getVelocityRangeIndex(event.noteOn.note, event.noteOn.velocity);
    }
    static void reattackNote(ref SampleInstrumentData data, MidiEvent* event, NoteState* state)
    {
        import mar.math : abs;

        if (state.reattackRestoreVolume is float.nan)
        {
            state.reattackRestoreVolume = state.base.targetVolume;
            state.reattackVelocity = event.noteOn.velocity;
            state.base.targetVolume = 0;
        }
    }
    static void renderNote(ref SampleInstrumentData data,
        NoteState* state, ubyte[] channels, RenderFormat.SampleType* buffer)
    {
        pragma(inline, true);

        if (state.reattackRestoreVolume !is float.nan)
        {
            if (state.base.currentVolume == 0)
            {
                state.sampleIndex = 0;
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
        const samples = sampleStruct.array;
        if (state.sampleIndex + channels.length >= samples.length)
            return; // no sample left to render

            // just do one channel for now
        if (sampleStruct.skew is float.nan)
        {
            foreach (ubyte channel; channels)
            {
                //logDebug("no skew");
                //logDebug(samples[state.sampleIndex]);
                const value = cast(RenderFormat.SampleType)(
                    state.base.currentVolume * data.volumeScale * samples[state.sampleIndex + channel]);
                buffer[channel] += value;
                /*
                addToEachChannel(channels, buffer, cast(RenderFormat.SampleType)(
                    state.currentVolume * data.volumeScale * samples[state.sampleIndex]));
                */
            }
            state.sampleIndex += data.channelCount;
        }
        else
        {
            foreach (ubyte channel; channels)
            {
                //logDebug("skew ", data.samples[state.note].skew);
                const ss0 = samples[state.sampleIndex + channel];
                const t = state.timeOffset;
                version (DropSampleInterpolation)
                    const newSample = from!"audio.interpolate".DropSample.interpolate(samples, state.sampleIndex + channel);
                else version (LinearInterpolation)
                    const newSample = from!"audio.interpolate".Linear.
                        interpolate(samples, state.sampleIndex + channel, state.timeOffset, data.channelCount);
                else version (ParabolicInterpolation)
                    const newSample = from!"audio.interpolate".Parabolic.
                        interpolate(samples, state.sampleIndex + channel, state.timeOffset, data.channelCount);
                else version (CatmullRomSpline)
                {
                    // There is a problem with this,
                    // it doesn't sound as good as parabolic
                    /+
                    // TODO: need to adjust sampleIndex with channel count
                    const ssneg1 = (state.sampleIndex!!!!!!! > 0) ?
                        samples[state.sampleIndex!!!!!!! - 1] : ss0;
                    +/
                    const ss1 = (state.sampleIndex + data.channelCount < samples.length) ?
                        samples[state.sampleIndex + data.channelCount] : ss0;
                    const ss2 = (state.sampleIndex + 2*data.channelCount < samples.length) ?
                        samples[state.sampleIndex + 2*data.channelCount] : ss1;
                    const newSample = ss0 + 0.5 * t * (
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
                    // TODO: need to adjust sampleIndex with channel count
                    const ssneg1 = (state.sampleIndex !!!!!!!> 0) ?
                        samples[state.sampleIndex!!!!!!! - 1] : ss0;
                    +/
                    const ss1 = (state.sampleIndex + data.channelCount < samples.length) ?
                        samples[state.sampleIndex + data.channelCount] : ss0;
                    const ss2 = (state.sampleIndex + 2*data.channelCount < samples.length) ?
                        samples[state.sampleIndex + 2*data.channelCount] : ss1;
                    const c1 = 0.5 * (ss1 - ssneg1);
                    const c2 = ssneg1 - 2.5*ss0 + 2*ss1 - 0.5*ss2;
                    const c3 = 0.5*(ss2 - ssneg1) + 1.5*(ss0 - ss1);
                    const newSample = ss0 + t * ( c1 + t * ( c2 + (t * c3)));
                }
                else version (OlliOptimal6po5o)
                {
                    const newSample = from!"audio.interpolate".OlliOptimal6po5o.
                        interpolate(samples, state.sampleIndex + channel, state.timeOffset, data.channelCount);
                }
                else static assert(0, "no interpolation version selected");
                //log(newSample);
                const newSampleScaled = cast(RenderFormat.SampleType)(
                    state.base.currentVolume * data.volumeScale * newSample);
                //logDebug("channel ", channel, " value ", newSampleScaled);
                buffer[channel] += newSampleScaled;
                /*
                addToEachChannel(channels, buffer, cast(RenderFormat.SampleType)(
                    state.currentVolume * data.volumeScale * newSample));
                */
            }
            auto nextTimeOffset = state.timeOffset + sampleStruct.skew;
            for (; nextTimeOffset >= 1.0; nextTimeOffset -= 1.0)
            {
                state.sampleIndex += data.channelCount;
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
    import audio.render : RenderState;

    mixin InheritBaseTemplate!MidiInstrument;

    MidiNoteMap!(Renderer.NoteState, ".base.note") notes;
    Renderer.InstrumentData instrumentData;
    bool sustainPedal;

    void initialize(Renderer.InstrumentData instrumentData)
    {
        this.base.renderNextBuffer = &renderNextBuffer;
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
    static void renderNextBuffer(typeof(this)* me, ubyte[] channels, void* buffer, const void* limit, MidiEvent[] midiEvents)
    {
        // update notes
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
        
        // TODO: maybe the buffer loop should be the outer one?
        //       maybe loop through each cache line, then through each note?
        for (size_t noteIndex = 0; noteIndex < me.notes.length; noteIndex++)
        {
            auto note = me.notes.asArray[noteIndex];
            bool removeNote = false;
            //log("Rendering note ", note.note);
            for (auto next = buffer; next < limit;
                next += (audio.global.channelCount * Renderer.FormatAlias.SampleType.sizeof))
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

                Renderer.renderNote(me.instrumentData, &note, channels, cast(RenderFormat.SampleType*)next);
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

