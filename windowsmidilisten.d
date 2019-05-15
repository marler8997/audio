module audio.windowsmidi;

import mar.passfail;
import mar.windows.types : Handle, LOBYTE, HIBYTE, LOWORD, HIWORD;
import mar.windows.winmm;

import audio.log;

alias MIDI_STATUS = LOBYTE;
//#define MIDI_DATA(x) LOBYTE(HIWORD(x))

extern (Windows) void listenCallback(MidiInHandle midiHandle, uint msg, uint* instance,
			     uint* param1, uint* param2)
{
    import mar.print : formatHex;
    import audio.midi : MidiMsgCategory, MidiControlCode;

    switch(msg)
    {
    case MIM_OPEN:
        log("midi open");
        break;
    case MIM_CLOSE:
        log("midi close");
        break;
    case MIM_DATA: {
        // param1 (low byte) = midi event
        // param2            = timestamp
        const status = MIDI_STATUS(param1);
        const category = status & 0xF0;
        const timestamp = cast(size_t)param2;
        if(category == MidiMsgCategory.noteOff)
        {
            const note     = HIBYTE(LOWORD(param1));
            const velocity = LOBYTE(HIWORD(param1));
            log("time=", timestamp, " note ", note, " OFF, velocity=", velocity);
        }
        else if(category ==  MidiMsgCategory.noteOn)
        {
            const note     = HIBYTE(LOWORD(param1));
            const velocity = LOBYTE(HIWORD(param1));
            log("time=", timestamp, " note ", note, " ON,  velocity=", velocity);
        }
        else if(category ==  MidiMsgCategory.control)
        {
            const number = HIBYTE(LOWORD(param1));
            const value  = LOBYTE(HIWORD(param1));
            if (number == MidiControlCode.sustainPedal)
            {
                const on = value >= 64;
                log("time=", timestamp, " sustain: ", on ? "ON" : "OFF", " timestamp=", timestamp);
            }
            else
            {
                log("time=", timestamp, " control ", number, "=", value);
            }
        }
        else
        {
            log("time=", timestamp, " data, unknown category 0x", status.formatHex);
        }
        break;
    } case MIM_LONGDATA:
        log("longdata?");
        break;
    case MIM_ERROR:
        log("error?");
        break;
    case MIM_LONGERROR:
        log("longerror?");
        break;
    case MIM_MOREDATA:
        log("moredata?");
        break;
    default:
        log("msg=", msg, "?");
        break;
    }
    flushDebug();
}

passfail listen(uint deviceID)
{
    import mar.mem : malloc;

    auto ret = passfail.fail;
    MidiInHandle midiHandle;
    {
        const result = midiInOpen(&midiHandle, deviceID, &listenCallback, null, MuitlmediaOpenFlags.callbackFunction);
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

    log("Press Enter to quit...");
    flushLog();
    {
        import mar.stdio : stdin;
        ubyte[1] buffer;
        stdin.read(buffer);
    }

    //
    // Cleanup
    //
    ret = passfail.pass;

    {
        const result = midiInStop(midiHandle);
        if (result.failed)
        {
            logError("midiInStop failed, result=", result);
            ret = passfail.fail;
        }
    }
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

void usage()
{
    log("TODO: add a --list option");
    log("windowsmidilisten <input-device-id>");
}
int main(string[] args)
{
    args = args[1 .. $];
    uint deviceID;
    if(args.length == 0)
    {
        usage();
        return 0;
    }
    else if(args.length == 1)
    {
        auto deviceIDString = args[0];
        if (deviceIDString != "0")
        {
            logError("non zero device id not impl");
        }
        deviceID = 0;
        /*
        deviceID = atoi(deviceIDString);
        if(deviceID == 0 && deviceIDString[0] != '0')
        {
            printf("Invalid device id '%s'\n", deviceIDString);
        }
        */
    }
    else
    {
        logError("too many command line arguments");
        usage();
        return 1;
    }

    //
    // Print the info (just because)
    //
    /*
    {
        MIDIINCAPS info;
        result = midiInGetDevCaps(deviceID, &info, sizeof(info));
        if(result != MMSYSERR_NOERROR)
        {
            printf("  Device %d: midiInGetDevCaps failed\n", deviceID);
            return 1;
        }

        log("Mid           : ", info.wMid);
        log("Pid           : ", info.wPid);
        log("DriverVersion : ", info.vDriverVersion >> 8, ".", (byte)info.vDriverVersion);
        log("ProductName   : '", info.szPname, "'");
    }
    */
    if (listen(deviceID).failed)
        return 1; // fail
    return 0; // success
}
