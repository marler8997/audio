module audio.oscillatorinstrument;

import audio.log;

struct UniqueSinOscillator
{
    import audio.render : SinOscillator;

    SinOscillator oscillator;
    float frequency;
}

struct OscillatorInstrument
{
    import audio.render : RenderState;
    import audio.midi : MidiNote;

    UniqueSinOscillator[MidiNote.max + 1] oscillators;
    this(bool placeholder)
    {
        import audio.midi : stdFreq;

        for(ubyte note = 0; note < oscillators.length; note++)
        {
            oscillators[note].frequency = stdFreq[note];
            oscillators[note].oscillator.base.state = RenderState.off;
        }
    }
    void play(Format)(MidiNote note)
    {
        static import audio.global;
        import audio.render : addRenderer;

        if (note >= oscillators.length)
        {
            log("Midi note ", note, " it too high");
            return;
        }
        // TODO: handle when it is in release state
        if(oscillators[note].oscillator.base.state == RenderState.off)
        {
            //printf("Key code %d 0x%x '%c' has frequency %f\n", code, code, (char)code,
            //oscillators[code].frequency);
            oscillators[note].oscillator.initialize!Format(audio.global.samplesPerSec, oscillators[note].frequency, .2);
            addRenderer(&(oscillators[note].oscillator.base));
        }
    }
    void release(MidiNote note)
    {
        if (note >= oscillators.length)
        {
            log("Midi note ", note, " it too high");
            return;
        }
        //logDebug("release ", note, ": current state ", oscillators[note].oscillator.base.state);
        if (oscillators[note].oscillator.base.state > RenderState.off)
            oscillators[note].oscillator.base.state = RenderState.release;
    }
}

__gshared OscillatorInstrument globalOscillator = OscillatorInstrument(true);
