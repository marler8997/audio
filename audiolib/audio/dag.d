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


struct MidiInputNode
{
    import mar.arraybuilder : ArrayBuilder;
    import audio.render : RenderState;
    import audio.midi : MidiNote, MidiNoteMap;

    RootRenderNode!MidiInputNode base;
    private ArrayBuilder!(MidiInstrument!void*) instruments;
    //bool[MidiNote.max + 1] onMap;

    ArrayBuilder!MidiEvent midiEvents;
    void initialize()
    {
        this.base.renderNextBuffer = &renderNextBuffer;
    }
    final auto asBase() inout { return cast(RootRenderNode!void*)&this; }

    passfail tryAddInstrument(MidiInstrument!void* instrument)
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
    auto tryAddMidiEvent(MidiEvent event)
    {
        import audio.render : enterRenderCriticalSection, exitRenderCriticalSection;

        enterRenderCriticalSection();
        scope (exit) exitRenderCriticalSection();
        // TODO: make sure it is in order by timestamp
        return midiEvents.tryPut(event);
    }

    static void renderNextBuffer(MidiInputNode* me, ubyte[] channels, void* renderBuffer, const void* limit)
    {
        foreach (instrument; me.instruments.data)
        {
            instrument.renderNextBuffer(instrument, channels, renderBuffer, limit, me.midiEvents.data);
        }
        me.midiEvents.shrinkTo(0);
    }

    version (Windows)
    {
        import mar.windows.winmm;

        private static extern (Windows) void midiInputCallback(MidiInHandle midiHandle, uint msg, uint* instance,
                        uint* param1, uint* param2)
        {
            import mar.print : formatHex;
            import mar.windows.types : LOBYTE, HIBYTE, LOWORD, HIWORD;

            import audio.midi : MidiNote, MidiMsgCategory, MidiControlCode;
            import audio.oscillatorinstrument : globalOscillator;

            alias MIDI_STATUS = LOBYTE;

            switch(msg)
            {
            case MIM_OPEN:
                logDebug("[MidiListenCallback] open");
                break;
            case MIM_CLOSE:
                logDebug("[MidiListenCallback] close");
                break;
            case MIM_DATA: {
                // param1 (low byte) = midi event
                // param2            = timestamp
                const status = MIDI_STATUS(param1);
                const category = status & 0xF0;
                if(category == MidiMsgCategory.noteOff)
                {
                    const note     = HIBYTE(LOWORD(param1));
                    const velocity = LOBYTE(HIWORD(param1));
                    const timestamp = cast(size_t)param2;

                    if (note & 0x80)
                        logError("Bad MIDI note 0x", note.formatHex, ", the MSB is set");
                    else if (velocity & 0x80)
                        logError("Bad MIDI velocity 0x", note.formatHex, ", the MSB is set");
                    else
                    {
                        //logDebug("[MidiListenCallback] note ", note, " OFF, velocity=", velocity, " timestamp=", timestamp);
                        const result = (cast(typeof(this)*)instance).tryAddMidiEvent(
                            MidiEvent.makeNoteOff(timestamp, cast(MidiNote)note));
                        if (result.failed)
                        {
                            logError("failed to add MIDI OFF event: ", result);
                        }
                    }
                }
                else if(category == MidiMsgCategory.noteOn)
                {
                    const note     = HIBYTE(LOWORD(param1));
                    const velocity = LOBYTE(HIWORD(param1));
                    const timestamp = cast(size_t)param2;
                    //logDebug("[MidiListenCallback] note ", note, " ON,  velocity=", velocity, " timestamp=", timestamp);
                    if (note & 0x80)
                        logError("Bad MIDI note 0x", note.formatHex, ", the MSB is set");
                    else if (velocity & 0x80)
                        logError("Bad MIDI velocity 0x", note.formatHex, ", the MSB is set");
                    else
                    {
                        const result = (cast(typeof(this)*)instance).tryAddMidiEvent(
                            MidiEvent.makeNoteOn(timestamp, cast(MidiNote)note, velocity));
                        if (result.failed)
                        {
                            logError("failed to add MIDI ON event: ", result);
                        }
                    }
                }
                else if (category == MidiMsgCategory.control)
                {
                    const number = HIBYTE(LOWORD(param1));
                    const value  = LOBYTE(HIWORD(param1));
                    const timestamp = cast(size_t)param2;
                    if (number == MidiControlCode.sustainPedal)
                    {
                        bool on = value >= 64;
                        //logDebug("[MidiListenCallback] sustain: ", on ? "ON" : "OFF");
                        const result = (cast(typeof(this)*)instance).tryAddMidiEvent(
                            MidiEvent.makeSustainPedal(timestamp,on));
                        if (result.failed)
                        {
                            logError("failed to add MIDI event: ", result);
                        }
                    }
                    else
                    {
                        //logDebug("[MidiListenCallback] control ", number, "=", value);
                    }
                }
                else
                {
                    logDebug("[MidiListenCallback] data, unknown category 0x", status.formatHex);
                }
                //printf("[MidiListenCallback] data (event=%d, timestampe=%d)\n",
                //(byte)param1, param2);
                break;
            } case MIM_LONGDATA:
                logDebug("[MidiListenCallback] longdata");
                break;
            case MIM_ERROR:
                logDebug("[MidiListenCallback] error");
                break;
            case MIM_LONGERROR:
                logDebug("[MidiListenCallback] longerror");
                break;
            case MIM_MOREDATA:
                logDebug("[MidiListenCallback] moredata");
                break;
            default:
                logDebug("[MidiListenCallback] msg=", msg);
                break;
            }
            flushDebug();
        }
        private bool midiDeviceInputRunning;
        private MidiInHandle midiHandle;
    }


    passfail startMidiDeviceInput(uint midiDeviceID)
    {
        version (Windows)
        {
            if (midiDeviceInputRunning)
            {
                logError("this MidiInputNode is already running");
                return passfail.fail;
            }

            passfail ret = passfail.fail; // fail by default
            {
                const result = midiInOpen(&midiHandle, midiDeviceID, &midiInputCallback, &this, MuitlmediaOpenFlags.callbackFunction);
                if(result.failed)
                {
                    logError("midiInOpen failed, result=", result);
                    goto LopenFailed;
                }
            }
            {
                const result = midiInStart(midiHandle);
                if(result.failed)
                {
                    logError("midiInStart failed, result=", result);
                    goto LstartFailed;
                }
            }
            this.midiDeviceInputRunning = true;
            return passfail.pass;
        LstartFailed:
            {
                const result = midiInClose(midiHandle);
                if (result.failed)
                {
                    logError("midiInClose failed, result=", result);
                    ret = passfail.fail;
                }
            }
        LopenFailed:
            return ret;
        }
        else
        {
            logError("midi not implemented on this platform");
            return passfail.fail;
        }
    }
    passfail stopMidiDeviceInput()
    {
        version (Windows)
        {
            if (!midiDeviceInputRunning)
            {
                logError("cannot stop this MidiInputNode because it is not running");
                return passfail.fail;
            }

            passfail ret = passfail.pass;
            {
                const result = midiInStop(midiHandle);
                if (result.failed)
                {
                    logError("midiInStop failed, result=", result);
                    ret = passfail.fail;
                }
            }
            {
                const result = midiInClose(midiHandle);
                if (result.failed)
                {
                    logError("midiInClose failed, result=", result);
                    ret = passfail.fail;
                }
            }
            if (ret.passed)
                midiDeviceInputRunning = false;
            return ret;
        }
        else
        {
            logError("midi not implemented on this platform");
            return passfail.fail;
        }
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
    import audio.midi : MidiNote, standardFrequencies;

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
        state.phaseIncrement = TWO_PI * standardFrequencies[event.noteOn.note] / audio.global.samplesPerSec;
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
    import audio.midi : MidiNote, standardFrequencies;

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
        state.increment = standardFrequencies[event.noteOn.note] / audio.global.samplesPerSec;
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

struct SampleWithSkipPattern
{
    RenderFormat.SampleType[] array;
    const(ubyte)[] skipPattern;
}
struct SampleInstrumentData
{
    import audio.midi : MidiNote;

    // Bug: can't use static array here with -betterC, pulls in TypeInfo
    SampleWithSkipPattern[/*MidiNote.max + 1*/] samples;
    float volumeScale;
    ubyte channelCount;
    this(SampleWithSkipPattern[/*MidiNote.max + 1*/] samples, float volumeScale, ubyte channelCount)
    {
        this.samples = samples;
        this.volumeScale = volumeScale;
        this.channelCount = channelCount;
    }
}

alias SamplerMidiInstrument = MidiInstrumentTypeA!SamplerMidiInstrumentTypeA;
struct SamplerMidiInstrumentTypeA
{
    import audio.midi : MidiNote, standardFrequencies;

    alias FormatAlias = RenderFormat;
    alias InstrumentData = SampleInstrumentData;
    struct NoteState
    {
        float currentVolume;
        float targetVolume;
        size_t nextSampleIndex;
        ubyte nextSkipPatternIndex;
        MidiNote note; // save so we can easily remove the note from the MidiNoteMap
        bool released;
    }
    static void newNote(ref SampleInstrumentData data, MidiEvent* event, NoteState* state)
    {
        state.nextSampleIndex = 0;
        state.nextSkipPatternIndex = 0;
    }
    static void reattackNote(ref SampleInstrumentData data, MidiEvent* event, NoteState* state)
    {
        state.nextSampleIndex = 0;
        state.nextSkipPatternIndex = 0;
    }
    static void renderNote(ref SampleInstrumentData data,
        NoteState* state, ubyte[] channels, RenderFormat.SampleType* buffer)
    {
        pragma(inline, true);
        if (state.nextSampleIndex < data.samples[state.note].array.length)
        {
            //logDebug("sample ", data.samples[state.note][state.nextSampleIndex]);
            // just do one channel for now
            addToEachChannel(channels, buffer, cast(RenderFormat.SampleType)(
                state.currentVolume * data.volumeScale * data.samples[state.note].array[state.nextSampleIndex]));
            if (data.samples[state.note].skipPattern.length == 0)
                state.nextSampleIndex += data.channelCount;
            else
            {
                //logDebug("skip ", data.samples[state.note].skipPattern[state.nextSkipPatternIndex]);
                state.nextSampleIndex += data.channelCount *
                    (1 + data.samples[state.note].skipPattern[state.nextSkipPatternIndex++]);
                if (state.nextSkipPatternIndex >= data.samples[state.note].skipPattern.length)
                    state.nextSkipPatternIndex = 0;
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
                    enum VolumeChangeVelocity = .001;
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

