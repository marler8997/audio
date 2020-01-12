module audio.events;

import audio.renderformat;

struct AudioEvent
{
    bool isMidi;
    uint samplesSinceRender;
    RenderFormat.SamplePoint* bufferPoint(RenderFormat.SamplePoint* lastEventBuffer)
    {
        assert(0, "not implemented");
    }
}

auto createMidiEventRange(AudioEvent[] events)
{
    return MidiEventRange(events);
}
struct MidiEventRange
{
    private AudioEvent[] events;
    private size_t index;
    this(AudioEvent[] events)
    {
        this.events = events;
        this.index = 0;
        next();
    }
    private void next()
    {
        for (; index < events.length; index++)
        {
            if (events[index].isMidi)
                break;
        }
    }
    bool empty() { return index >= events.length; }
    AudioEvent front() { return events[index]; }
    void popFront()
    {
        index++;
        next();
    }
}
