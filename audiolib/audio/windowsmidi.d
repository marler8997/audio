module audio.windowsmidi;

import mar.passfail;

import audio.log;
import audio.dag : MidiEvent, MidiInputNodeTemplate;

alias WindowsMidiInputNode = MidiInputNodeTemplate!WindowsMidiInputDevice;
struct WindowsMidiInputDevice
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
                    const result = (cast(WindowsMidiInputNode*)instance).tryAddMidiEvent(
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
                    const result = (cast(WindowsMidiInputNode*)instance).tryAddMidiEvent(
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
                    const result = (cast(WindowsMidiInputNode*)instance).tryAddMidiEvent(
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
    private bool running;
    private MidiInHandle midiHandle;

    static passfail startMidiDeviceInput(WindowsMidiInputNode* node, uint midiDeviceID)
    {
        if (node.inputDevice.running)
        {
            logError("this MidiInputNode is already running");
            return passfail.fail;
        }

        passfail ret = passfail.fail; // fail by default
        {
            const result = midiInOpen(&node.inputDevice.midiHandle, midiDeviceID,
                &midiInputCallback, node, MuitlmediaOpenFlags.callbackFunction);
            if(result.failed)
            {
                logError("midiInOpen failed, result=", result);
                goto LopenFailed;
            }
        }
        {
            const result = midiInStart(node.inputDevice.midiHandle);
            if(result.failed)
            {
                logError("midiInStart failed, result=", result);
                goto LstartFailed;
            }
        }
        node.inputDevice.running = true;
        return passfail.pass;
    LstartFailed:
        {
            const result = midiInClose(node.inputDevice.midiHandle);
            if (result.failed)
            {
                logError("midiInClose failed, result=", result);
                ret = passfail.fail;
            }
        }
    LopenFailed:
        return ret;
    }
    static passfail stopMidiDeviceInput(WindowsMidiInputNode* node)
    {
        if (!node.inputDevice.running)
        {
            logError("cannot stop this MidiInputNode because it is not running");
            return passfail.fail;
        }

        passfail ret = passfail.pass;
        {
            const result = midiInStop(node.inputDevice.midiHandle);
            if (result.failed)
            {
                logError("midiInStop failed, result=", result);
                ret = passfail.fail;
            }
        }
        {
            const result = midiInClose(node.inputDevice.midiHandle);
            if (result.failed)
            {
                logError("midiInClose failed, result=", result);
                ret = passfail.fail;
            }
        }
        if (ret.passed)
            node.inputDevice.running = false;
        return ret;
    }
}
