module windowsmidiinstrument;

import mar.passfail;
import mar.windows.types : LOBYTE, HIBYTE, LOWORD, HIWORD;
import mar.windows.winmm;

import audio.log;

alias MIDI_STATUS = LOBYTE;
//#define MIDI_DATA(x) LOBYTE(HIWORD(x))

extern (Windows) void listenCallback(Format)(MidiInHandle midiHandle, uint msg, uint* instance,
			     uint* param1, uint* param2)
{
    import mar.print : formatHex;
    import audio.midi : MidiNote;
    import audio.oscillatorinstrument : globalOscillator;

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
            //logDebug("[MidiListenCallback] note ", note, " OFF, velocity=", velocity);
            globalOscillator.release(cast(MidiNote)note);
        }
        else if(category == 0x90)
        {
            const note     = HIBYTE(LOWORD(param1));
            const velocity = LOBYTE(HIWORD(param1));
            //logDebug("[MidiListenCallback] note ", note, " ON,  velocity=", velocity);
            globalOscillator.play!Format(cast(MidiNote)note);
        }
        else
        {
            //logDebug("[MidiListenCallback] data, unknown category 0x", status.formatHex);
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

passfail readNotes(Format)(uint deviceID)
{
    import mar.mem : malloc, free;

    passfail ret = passfail.fail; // fail by default

    MidiInHandle midiHandle;
    {
        const result = midiInOpen(&midiHandle, deviceID, &listenCallback!Format, null, MuitlmediaOpenFlags.callbackFunction);
        if(result.failed)
        {
            logError("midiInOpen failed, result=", result);
            goto LopenFailed;
        }
    }

/*
    MidiHeader midiHeader = 0;
    zero(&midiHeader, midiHeader.sizeof);
    enum MidiBufferSize = 512;
    midiHeader.data = cast(ubyte*)malloc(MidiBufferSize);
    if (midiHeader.data is null)
    {
        logError("malloc failed");
        goto LmallocFailed;
    }
    midiHeader.size = MidiBufferSize;

    {
        const result = midiInPrepareHeader(midiHandle, &midiHeader, midiHeader.sizeof);
        if(result.failed)
        {
            logError("midiInPrepareHeader failed, result=", result);
            goto LprepareFailed;
        }
    }

    {
        const result = midiInAddBuffer(midiHandle, &midiHeader, midiHeader.sizeof);
        if(result.failed)
        {
            logError("midiInAddBuffer failed, result=", result);
            goto LaddBufferFailed;
        }
    }
    */
    {
        const result = midiInStart(midiHandle);
        if(result.failed)
        {
            logError("midiInStart failed, result=", result);
            goto LstartFailed;
        }
    }

    log("Press enter to quit...");
    flushLog();

    // just wait for some input and then quit
    {
        import mar.stdio;
        import mar.windows.kernel32 : ReadFile;
        char[8] buffer;
        uint bytesRead;
        ReadFile(stdin.asHandle, buffer.ptr, 1, &bytesRead, null);
    }


    ret = passfail.pass;
    //
    // Cleanup
    //
    {
        const result = midiInStop(midiHandle);
        if (result.failed)
        {
            logError("midiInStop failed, result=", result);
            ret = passfail.fail;
        }
    }
LstartFailed:
    /*
LaddBufferFailed:
    {
        const result = midiInUnprepareHeader(midiHandle, &midiHeader, midiHeader.sizeof);
        if (result.failed)
        {
            logError("midiInUnprepareHeader failed, result=", result);
            ret = passfail.fail;
        }
    }
LprepareFailed:
    free(midiHeader.data);
LmallocFailed:
    */
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
