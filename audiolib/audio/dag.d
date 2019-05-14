module audio.dag;

import mar.from;
import mar.passfail;

import audio.log;
import audio.renderformat;
static import audio.global;


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
    import audio.render : RenderState;
    import audio.midi : MidiNote;

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

    RootRenderNode!(typeof(this)) base;
    private ArrayBuilder!(MidiInstrument!void*) instruments;
    //bool[MidiNote.max + 1] onMap;
    ArrayBuilder!MidiEvent midiEvents;
    InputDevice inputDevice;

    final void initialize()
    {
        this.base.renderNextBuffer = &renderNextBuffer;
    }
    final auto asBase() inout { return cast(RootRenderNode!void*)&this; }

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
        float currentVolume;
        float targetVolume;
        float phaseIncrement;
        float phase;
        MidiNote note; // save so we can easily remove the note from the MidiNoteMap
        bool released;
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
        float currentVolume;
        float targetVolume;
        float nextSample;
        float increment;
        MidiNote note; // save so we can easily remove the note from the MidiNoteMap
        bool released;
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

struct SkewedSample
{
    RenderFormat.SampleType[] array;
    float skew;
}
struct SampleInstrumentData
{
    import audio.midi : MidiNote;

    // Bug: can't use static array here with -betterC, pulls in TypeInfo
    SkewedSample[/*MidiNote.max + 1*/] samples;
    float volumeScale;
    ubyte channelCount;
    this(SkewedSample[/*MidiNote.max + 1*/] samples, float volumeScale, ubyte channelCount)
    {
        this.samples = samples;
        this.volumeScale = volumeScale;
        this.channelCount = channelCount;
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
    import audio.midi : MidiNote, stdFreq;

    alias FormatAlias = RenderFormat;
    alias InstrumentData = SampleInstrumentData;
    struct NoteState
    {
        size_t sampleIndex;
        float currentVolume;
        float targetVolume;
        float timeOffset;
        MidiNote note; // save so we can easily remove the note from the MidiNoteMap
        bool released;
        float reattackRestoreVolume;
    }
    static void newNote(ref SampleInstrumentData data, MidiEvent* event, NoteState* state)
    {
        state.sampleIndex = 0;
        state.timeOffset = 0;
        state.reattackRestoreVolume = float.nan;
    }
    static void reattackNote(ref SampleInstrumentData data, MidiEvent* event, NoteState* state)
    {
        import mar.math : abs;

        const samples = data.samples[state.note].array;
        if (state.reattackRestoreVolume is float.nan)
        {
            state.reattackRestoreVolume = state.targetVolume;
            state.targetVolume = 0;
        }
    }
    static void renderNote(ref SampleInstrumentData data,
        NoteState* state, ubyte[] channels, RenderFormat.SampleType* buffer)
    {
        pragma(inline, true);

        if (state.reattackRestoreVolume !is float.nan)
        {
            if (state.currentVolume == 0)
            {
                state.sampleIndex = 0;
                state.timeOffset = 0;
                state.currentVolume = state.reattackRestoreVolume;
                state.targetVolume = state.reattackRestoreVolume;
                state.reattackRestoreVolume = float.nan;
            }
        }

        const samples = data.samples[state.note].array;
        if (state.sampleIndex < samples.length)
        {
            // just do one channel for now
            if (data.samples[state.note].skew is float.nan)
            {
                //logDebug("no skew");
                //logDebug(samples[state.sampleIndex]);
                addToEachChannel(channels, buffer, cast(RenderFormat.SampleType)(
                    state.currentVolume * data.volumeScale * samples[state.sampleIndex]));
                state.sampleIndex += data.channelCount;
            }
            else
            {
                //logDebug("skew ", data.samples[state.note].skew);
                RenderFormat.SampleType ss0 = samples[state.sampleIndex];
                const t = state.timeOffset;
                version (DropSampleInterpolation)
                    const newSample = from!"audio.interpolate".DropSample.interpolate(samples, state.sampleIndex);
                else version (LinearInterpolation)
                    const newSample = from!"audio.interpolate".Linear.
                        interpolate(samples, state.sampleIndex, state.timeOffset, data.channelCount);
                else version (ParabolicInterpolation)
                    const newSample = from!"audio.interpolate".Parabolic.
                        interpolate(samples, state.sampleIndex, state.timeOffset, data.channelCount);
                else version (CatmullRomSpline)
                {
                    // There is a problem with this,
                    // it doesn't sound as good as parabolic
                    const ssneg1 = (state.sampleIndex > 0) ?
                        samples[state.sampleIndex - 1] : ss0;
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
                    const ssneg1 = (state.sampleIndex > 0) ?
                        samples[state.sampleIndex - 1] : ss0;
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
                        interpolate(samples, state.sampleIndex, state.timeOffset, data.channelCount);
                }
                else static assert(0, "no interpolation version selected");
                //log(newSample);
                addToEachChannel(channels, buffer, cast(RenderFormat.SampleType)(
                    state.currentVolume * data.volumeScale * newSample));
                auto nextTimeOffset = state.timeOffset + data.samples[state.note].skew;
                for (; nextTimeOffset >= 1.0; nextTimeOffset -= 1.0)
                {
                    state.sampleIndex += data.channelCount;
                }
                state.timeOffset = nextTimeOffset;
            }
        }
    }
}

struct MidiInstrumentTypeA(Renderer)
{
    import audio.midi : MidiNote, MidiNoteMap;
    import audio.render : RenderState;

    MidiInstrument!(typeof(this)) base;
    static assert(base.offsetof == 0);

    MidiNoteMap!(Renderer.NoteState, ".note") notes;
    Renderer.InstrumentData instrumentData;
    bool sustainPedal;

    void initialize(Renderer.InstrumentData instrumentData)
    {
        this.base.renderNextBuffer = &renderNextBuffer;
        this.notes.initialize();
        this.instrumentData = instrumentData;
    }
    final auto asBase() inout { return cast(MidiInstrument!void*)&this; }

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
                    state.targetVolume = (event.noteOn.velocity / 127f) * 1.0;
                    state.released = false;
                    Renderer.reattackNote(me.instrumentData, &event, state);
                }
                else
                {
                    Renderer.NoteState newNoteState = void;
                    newNoteState.currentVolume = event.noteOn.velocity / 127.0 * 1.0;
                    newNoteState.targetVolume = newNoteState.currentVolume;
                    newNoteState.note = event.noteOn.note;
                    newNoteState.released = false;
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
                    state.released = true;
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
                if (note.released && !me.sustainPedal)
                {
                    note.currentVolume -= .0001;
                    if (note.currentVolume <= 0)
                    {
                        removeNote = true;
                        break;
                    }
                }
                else if (note.targetVolume != note.currentVolume)
                {
                    enum VolumeChangeVelocity = .001; // Note: should take frequency into account
                    if (note.targetVolume > note.currentVolume)
                    {
                        note.currentVolume += VolumeChangeVelocity;
                        if (note.currentVolume > note.targetVolume)
                            note.currentVolume = note.targetVolume;
                    }
                    else
                    {
                        note.currentVolume -= VolumeChangeVelocity;
                        if (note.currentVolume < note.targetVolume)
                            note.currentVolume = note.targetVolume;
                    }
                }

                Renderer.renderNote(me.instrumentData, &note, channels, cast(RenderFormat.SampleType*)next);
            }

            if (removeNote)
            {
                const result = me.notes.remove(note.note);
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

