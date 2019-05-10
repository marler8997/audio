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
        if(category == 0x80)
        {
            const note     = HIBYTE(LOWORD(param1));
            const velocity = LOBYTE(HIWORD(param1));
            logDebug("[MidiListenCallback] note ", note, " OFF, velocity=", velocity);
        }
        else if(category == 0x90)
        {
            const note     = HIBYTE(LOWORD(param1));
            const velocity = LOBYTE(HIWORD(param1));
            logDebug("[MidiListenCallback] note ", note, " ON,  velocity=", velocity);
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

passfail listen(uint deviceID)
{
    import mar.mem : malloc;

    enum MidiBufferSize = 512;
    MidiInHandle midiHandle;
    MidiHeader midiHeader;

    {
        const result = midiInOpen(&midiHandle, deviceID, &listenCallback, null, MuitlmediaOpenFlags.callbackFunction);
        if(result.failed)
        {
            logError("midiInOpen failed, result=", result);
            return passfail.fail;
        }
    }
    scope (exit) midiInClose(midiHandle);

    midiHeader.data = cast(ubyte*)malloc(MidiBufferSize);
    midiHeader.size = MidiBufferSize;

    {
        const result = midiInPrepareHeader(midiHandle, &midiHeader, midiHeader.sizeof);
        if(result.failed)
        {
            logError("midiInPrepareHeader failed, result=", result);
            return passfail.fail;
        }
    }
    {
        const result = midiInAddBuffer(midiHandle, &midiHeader, midiHeader.sizeof);
        if(result.failed)
        {
            logError("midiInAddBuffer failed, result=", result);
            return passfail.fail;
        }
    }
    {
        const result = midiInStart(midiHandle);
        if(result.failed)
        {
            logError("midiInStart failed, result=", result);
            return passfail.fail;
        }
    }

    log("Press enter to quit...");
    flushLog();

    {
        import mar.stdio;
        import mar.windows.kernel32 : ReadFile;
        char[8] buffer;
        uint bytesRead;
        ReadFile(stdin.asHandle, buffer.ptr, 1, &bytesRead, null);
    }
    return passfail.pass;
}

void usage()
{
    log("listen <input-device-id>");
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
