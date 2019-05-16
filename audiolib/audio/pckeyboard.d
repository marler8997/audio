module audiolib.audio.pckeyboard;

import mar.from;
import mar.passfail;

import audio.log;
import audio.renderformat;
import audio.dag : MidiInputNodeTemplate;
import audio.midi : MidiNote, MidiEvent;

alias PCKeyboardInputNode = MidiInputNodeTemplate!PCKeyboardMidiInputDevice;
struct PCKeyboardMidiInputDevice
{
    private bool running;

    static passfail startMidiDeviceInput(PCKeyboardInputNode* node)
    {
        if (node.inputDevice.running)
        {
            logError("this PCKeyboardMidiInputDevice is already running");
            return passfail.fail;
        }

        //logDebug("staring PCKeyboard input...");
        if (installKeyNoteHandlers(node).failed)
            return passfail.fail;

        if (startInputThread().failed)
            return passfail.fail;
        node.inputDevice.running = true;
        return passfail.pass;
    }
    static passfail stopMidiDeviceInput(PCKeyboardInputNode* node)
    {
        if (!node.inputDevice.running)
        {
            logError("cannot stop this MidiInputNode because it is not running");
            return passfail.fail;
        }

        passfail ret = passfail.pass;
        /*
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
        */
        if (ret.passed)
            node.inputDevice.running = false;
        return ret;
    }

    version (Windows)
    {
        import mar.windows.types : KeyEventRecord;
        static void keyHandler(PCKeyboardInputNode* node, KeyEventRecord* keyEvent)
        {
            // TODO: get Timestamp
            const timestamp = 0;
            if (keyEvent.keyCode >= keyToNoteMap.length)
            {
                // log something?
                return;
            }
            const note = keyToNoteMap[keyEvent.keyCode];
            const velocity = 63; // maybe change velocity with shift or something?
                                 // or the mouse could change velocity?
            if (keyEvent.down)
            {
                const result = node.tryAddMidiEvent(MidiEvent.makeNoteOn(timestamp, note, velocity));
                if (result.failed)
                {
                    logError("failed to add MIDI ON event: ", result);
                }
            }
            else
            {
                const result = node.tryAddMidiEvent(MidiEvent.makeNoteOff(timestamp, note));
                if (result.failed)
                {
                    logError("failed to add MIDI ON event: ", result);
                }
            }
        }
    }
}

// TODO: move these to mar
enum VK_RETURN = 0x000d;
enum VK_ESCAPE = 0x1b;
enum VK_OEM_COMMA = 0xbc;
enum VK_OEM_PERIOD = 0xbe;
enum VK_OEM_1 = 0xba;
enum VK_OEM_2 = 0xbf;
enum LEFT_CTRL_PRESSED = 0x0008;
enum RIGHT_CTRL_PRESSED = 0x0004;

immutable MidiNote[ubyte.max + 1] keyToNoteMap = [
    'Z'          : MidiNote.c4,
    'S'          : MidiNote.csharp4,
    'X'          : MidiNote.d4,
    'D'          : MidiNote.dsharp4,
    'C'          : MidiNote.e4,
    'V'          : MidiNote.f4,
    'G'          : MidiNote.fsharp4,
    'B'          : MidiNote.g4,
    'H'          : MidiNote.gsharp4,
    'N'          : MidiNote.a4,
    'J'          : MidiNote.asharp4,
    'M'          : MidiNote.b4,
    VK_OEM_COMMA : MidiNote.c5,
    'L'          : MidiNote.csharp5,
    VK_OEM_PERIOD: MidiNote.d5,
    VK_OEM_1     : MidiNote.dsharp5, // ';'
    VK_OEM_2     : MidiNote.e5,      // '/'
];
passfail installKeyNoteHandlers(PCKeyboardInputNode* node)
{
    enterGlobalCriticalSection();
    scope (exit) exitGlobalCriticalSection();
    for (ubyte keyCode = 0; ; keyCode++)
    {
        if (keyToNoteMap[keyCode] != 0)
        {
            //log("install keycode ", keyCode);
            if (global.keyHandlers[keyCode].isSet)
            {
                logError("handler already installed to keycode ", keyCode);
                return passfail.fail;
            }
            global.keyHandlers[keyCode].set(node, &PCKeyboardMidiInputDevice.keyHandler);
        }
        if (keyCode == ubyte.max)
            break;
    }
    return passfail.pass;
}


struct KeyHandler(T)
{
    import mar.windows.types : KeyEventRecord;
    bool down; // stop multiple down events
    private T* context;
    private void function(T*, KeyEventRecord*) handler;
    bool isSet() const { return context !is null; }
    void set(U)(U* context, void function(U*, KeyEventRecord*) handler)
    {
        this.context = cast(T*)context;
        this.handler = cast(typeof(this.handler))handler;
    }
    void call(KeyEventRecord* keyEvent)
    {
        if (keyEvent.down)
        {
            if (this.down)
                return;
            this.down = true;
        }
        else
        {
            this.down = false;
        }
        handler(context, keyEvent);
    }
}

struct Global
{
    version (Windows)
    {
        import mar.windows.types : Handle, SRWLock;
        SRWLock lock;
        Handle inputThread;
    }
    bool inputThreadRunning;
    KeyHandler!void[256] keyHandlers;
}
__gshared Global global;
passfail pckeyboardInit()
{
    version (Windows)
    {
        import mar.windows.kernel32 : InitializeSRWLock;
        InitializeSRWLock(&global.lock);
    }
    return passfail.pass;
}
final void enterGlobalCriticalSection()
{
    pragma(inline, true);
    version (Windows)
    {
        import mar.windows.kernel32 : AcquireSRWLockExclusive;
        AcquireSRWLockExclusive(&global.lock);
    }
}
final void exitGlobalCriticalSection()
{
    pragma(inline, true);
    version (Windows)
    {
        import mar.windows.kernel32 : ReleaseSRWLockExclusive;
        ReleaseSRWLockExclusive(&global.lock);
    }
}
passfail startInputThread()
{
    import mar.thread : startThread;

    enterGlobalCriticalSection();
    scope (exit) exitGlobalCriticalSection();
    if (!global.inputThreadRunning)
    {
        auto result = startThread(&inputThreadEntry);
        if (result.failed)
        {
            logError("failed to start thread for pc keyboard input: ", result);
            return passfail.fail;
        }
        global.inputThread = result.val;
        global.inputThreadRunning = true;
    }
    return passfail.pass;
}
passfail joinInputThread()
{
    version (Windows)
    {
        import mar.windows.types : Handle, INFINITE;
    }

    Handle threadHandleCopy;
    {
        enterGlobalCriticalSection();
        scope (exit) exitGlobalCriticalSection();
        if (!global.inputThreadRunning)
            return passfail.pass;
        threadHandleCopy = global.inputThread;
    }
    version (Windows)
    {
        import mar.windows.kernel32 : GetLastError, WaitForSingleObject;
        //logDebug("waiting for input thread to exit");
        const result = WaitForSingleObject(threadHandleCopy, INFINITE);
        if (result != 0)
        {
            logError("WaitForSingleObject on inputThread handle failed, result=", result, ", e=", GetLastError());
            return passfail.fail;
        }
        return passfail.pass;
    }
}


mixin from!"mar.thread".threadEntryMixin!("inputThreadEntry", q{
    import mar.print : formatHex;
    import mar.stdio : stdin;
    import mar.windows.types : ConsoleFlag, EventType, InputRecord;
    import mar.windows.kernel32 :
        GetLastError,
        GetConsoleMode, SetConsoleMode, ReadConsoleInputA;

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

LinputLoop:
    while(true)
    {
        uint inputCount;
        InputRecord[128] inputBuffer = void;
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

                if (code > global.keyHandlers.length)
                {
                    // log something?
                }
                else
                {
                    enterGlobalCriticalSection();
                    scope (exit) exitGlobalCriticalSection();
                    if (global.keyHandlers[code].isSet)
                    {
                        global.keyHandlers[code].call(&inputBuffer[i].key);
                    }
                    else
                    {
                        //logDebug("keycode ", code, " has no handler");
                    }
                }

                // Quit from ESCAPE, ENTER, or CTL-C
                if((code == VK_ESCAPE) ||// (code == VK_RETURN) ||
                    (code == 'C' &&
                    (inputBuffer[i].key.controlKeyState & (LEFT_CTRL_PRESSED |
                    RIGHT_CTRL_PRESSED))))
                {
                    if (code == VK_ESCAPE)
                        log("ESC key pressed");
                    else if (code == VK_RETURN)
                        log("Enter key pressed");
                    else
                        log("CTL-C pressed");
                    break LinputLoop;
                }
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
    log("stdin input thread exiting...");
    return 0;
});
