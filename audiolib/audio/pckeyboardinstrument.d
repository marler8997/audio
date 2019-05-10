module audio.pckeyboardinstrument;

import audio.log;


// 0 = success
char readNotes(Format)()
{
    import mar.print : formatHex;
    import mar.stdio : stdin;
    import mar.windows.types : ConsoleFlag, EventType, InputRecord;
    import mar.windows.kernel32 :
        GetLastError,
        GetConsoleMode, SetConsoleMode, ReadConsoleInputA;

    import audio.render : RenderState, addRenderer, render;
    import audio.midi : MidiNote;
    import audio.oscillatorinstrument : globalOscillator;

    // TODO: move these to mar
    enum VK_ESCAPE = 0x1b;
    enum VK_OEM_COMMA = 0xbc;
    enum VK_OEM_PERIOD = 0xbe;
    enum VK_OEM_1 = 0xba;
    enum VK_OEM_2 = 0xbf;
    enum LEFT_CTRL_PRESSED = 0x0008;
    enum RIGHT_CTRL_PRESSED = 0x0004;

    InputRecord[128] inputBuffer;

    if(!stdin.isValid)
    {
        logError("Error: failed to get stdin handle");
        return 1;
    }

    // Save old input mode
    uint oldMode;
    if(GetConsoleMode(stdin.asHandle, &oldMode).failed)
    {
        logError("Error: GetConsoleMode failed, e=", GetLastError());
        return 1;
    }
    auto newMode = oldMode;
    newMode &= ~(
          ConsoleFlag.enableEchoInput      // disable echo
        | ConsoleFlag.enableLineInput      // disable line input, we want characters immediately
        | ConsoleFlag.enableProcessedInput // we'll handle CTL-C so we can cleanup and reset the console mode
    );
    log("Current console mode 0x", oldMode.formatHex, ", setting so 0x", newMode.formatHex);

    if(SetConsoleMode(stdin.asHandle, newMode).failed)
    {
        logError("Error: SetConsoleMode failed, e=", GetLastError());
        return 1;
    }

    __gshared static MidiNote[256] keyToNoteMap;
    for(ushort i = 0; i < 256; i++)
    {
        keyToNoteMap[i] = MidiNote.none;
    }
    keyToNoteMap['Z'          ] = MidiNote.c4;
    keyToNoteMap['S'          ] = MidiNote.csharp4; 
    keyToNoteMap['X'          ] = MidiNote.d4;
    keyToNoteMap['D'          ] = MidiNote.dsharp4; 
    keyToNoteMap['C'          ] = MidiNote.e4;
    keyToNoteMap['V'          ] = MidiNote.f4;
    keyToNoteMap['G'          ] = MidiNote.fsharp4;
    keyToNoteMap['B'          ] = MidiNote.g4;
    keyToNoteMap['H'          ] = MidiNote.gsharp4;
    keyToNoteMap['N'          ] = MidiNote.a4;
    keyToNoteMap['J'          ] = MidiNote.asharp4;
    keyToNoteMap['M'          ] = MidiNote.b4;
    keyToNoteMap[VK_OEM_COMMA ] = MidiNote.c5;
    keyToNoteMap['L'          ] = MidiNote.csharp5; 
    keyToNoteMap[VK_OEM_PERIOD] = MidiNote.d5;
    keyToNoteMap[VK_OEM_1     ] = MidiNote.dsharp5; // ';'
    keyToNoteMap[VK_OEM_2     ] = MidiNote.e5;      // '/'

    log("Use keyboard for sounds (ESC to exit)");
    flushLog();

LinputLoop:
    while(true)
    {
        uint inputCount;
        if(ReadConsoleInputA(stdin.asHandle, inputBuffer.ptr, inputBuffer.length, &inputCount).failed)
        {
            logError("Error: ReadConsoleInput failed, e=", GetLastError());
            SetConsoleMode(stdin.asHandle, oldMode);
            return 1;
        }

        //logDebug("Handling ", inputCount, " input events...");
        foreach(i; 0 .. inputCount)
        {
            switch(inputBuffer[i].type)
            {
            case EventType.key: {
                /*
                logDebug("KeyEvent code=", inputBuffer[i].key.keyCode
                    , " ", inputBuffer[i].key.down ? "down" : "up"
                );
                printf("KeyEvent code=%d 0x%x ascii=%c '%s' state=%d\n",
                inputBuffer[i].key.keyCode,
                inputBuffer[i].key.keyCode,
                inputBuffer[i].key.asciiChar,
                inputBuffer[i].key.down ? "down" : "up",
                inputBuffer[i].key.controlKeyState);
                */
                const code = inputBuffer[i].key.keyCode;

                // Quit from ESCAPE or CTL-C
                if((code == VK_ESCAPE) ||
                    (code == 'C' &&
                    (inputBuffer[i].key.controlKeyState & (LEFT_CTRL_PRESSED |
                    RIGHT_CTRL_PRESSED))))
                {
                    break LinputLoop;
                }

                if(inputBuffer[i].key.down)
                    globalOscillator.play!Format(keyToNoteMap[code]);
                else
                    globalOscillator.release(keyToNoteMap[code]);

            }
            break;
            case EventType.mouse:
                //printf("mouse event!\n");
                break;
            case EventType.focus:
                break;
            default:
                logDebug("unhandled event: ", inputBuffer[i].type);
                break;
            }
        }
    }

    return 0;
}
