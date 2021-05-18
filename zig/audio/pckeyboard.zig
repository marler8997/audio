const builtin = @import("builtin");
const std = @import("std");
const inputlog = std.log.scoped(.input);

const audio = @import("../audio.zig");


const global = struct {
    var inputThreadMutex = std.Thread.Mutex {};
    var inputThreadRunning = false;
    var inputThread : *std.Thread = undefined;
    //KeyHandler!void[256] keyHandlers;
};

//alias PCKeyboardInputNode = MidiGeneratorTemplate!PCKeyboardMidiInputDevice;
//struct PCKeyboardMidiInputDevice
//{
//    private bool running;
//
//    static passfail startMidiDeviceInput(PCKeyboardInputNode* node)
//    {
//        if (node.inputDevice.running)
//        {
//            logError("this PCKeyboardMidiInputDevice is already running");
//            return passfail.fail;
//        }
//
//        //logDebug("staring PCKeyboard input...");
//        if (installKeyNoteHandlers(node).failed)
//            return passfail.fail;
//
//        if (startInputThread().failed)
//            return passfail.fail;
//        node.inputDevice.running = true;
//        return passfail.pass;
//    }
//    static passfail stopMidiDeviceInput(PCKeyboardInputNode* node)
//    {
//        if (!node.inputDevice.running)
//        {
//            logError("cannot stop this MidiGenerator because it is not running");
//            return passfail.fail;
//        }
//
//        passfail ret = passfail.pass;
//        /*
//        {
//            const result = midiInStop(node.inputDevice.midiHandle);
//            if (result.failed)
//            {
//                logError("midiInStop failed, result=", result);
//                ret = passfail.fail;
//            }
//        }
//        {
//            const result = midiInClose(node.inputDevice.midiHandle);
//            if (result.failed)
//            {
//                logError("midiInClose failed, result=", result);
//                ret = passfail.fail;
//            }
//        }
//        */
//        if (ret.passed)
//            node.inputDevice.running = false;
//        return ret;
//    }
//
//    version (Windows)
//    {
//        import mar.windows : KeyEventRecord;
//        static void keyHandler(PCKeyboardInputNode* node, KeyEventRecord* keyEvent)
//        {
//            // TODO: get Timestamp
//            const timestamp = 0;
//            if (keyEvent.keyCode >= keyToNoteMap.length)
//            {
//                // log something?
//                return;
//            }
//            const note = keyToNoteMap[keyEvent.keyCode];
//            const velocity = 63; // maybe change velocity with shift or something?
//                                 // or the mouse could change velocity?
//            if (keyEvent.down)
//            {
//                const result = node.tryAddMidiEvent(MidiEvent.makeNoteOn(timestamp, note, velocity));
//                if (result.failed)
//                {
//                    logError("failed to add MIDI ON event: ", result);
//                }
//            }
//            else
//            {
//                const result = node.tryAddMidiEvent(MidiEvent.makeNoteOff(timestamp, note));
//                if (result.failed)
//                {
//                    logError("failed to add MIDI ON event: ", result);
//                }
//            }
//        }
//    }
//}
//
//// TODO: move these to mar
//enum VK_RETURN = 0x000d;
//enum VK_ESCAPE = 0x1b;
//enum VK_OEM_COMMA = 0xbc;
//enum VK_OEM_PERIOD = 0xbe;
//enum VK_OEM_1 = 0xba;
//enum VK_OEM_2 = 0xbf;
//enum LEFT_CTRL_PRESSED = 0x0008;
//enum RIGHT_CTRL_PRESSED = 0x0004;
//
//immutable MidiNote[ubyte.max + 1] keyToNoteMap = [
//    'Z'          : MidiNote.c4,
//    'S'          : MidiNote.csharp4,
//    'X'          : MidiNote.d4,
//    'D'          : MidiNote.dsharp4,
//    'C'          : MidiNote.e4,
//    'V'          : MidiNote.f4,
//    'G'          : MidiNote.fsharp4,
//    'B'          : MidiNote.g4,
//    'H'          : MidiNote.gsharp4,
//    'N'          : MidiNote.a4,
//    'J'          : MidiNote.asharp4,
//    'M'          : MidiNote.b4,
//    VK_OEM_COMMA : MidiNote.c5,
//    'L'          : MidiNote.csharp5,
//    VK_OEM_PERIOD: MidiNote.d5,
//    VK_OEM_1     : MidiNote.dsharp5, // ';'
//    VK_OEM_2     : MidiNote.e5,      // '/'
//];
//passfail installKeyNoteHandlers(PCKeyboardInputNode* node)
//{
//    enterGlobalCriticalSection();
//    scope (exit) exitGlobalCriticalSection();
//    for (ubyte keyCode = 0; ; keyCode++)
//    {
//        if (keyToNoteMap[keyCode] != 0)
//        {
//            //log("install keycode ", keyCode);
//            if (global.keyHandlers[keyCode].isSet)
//            {
//                logError("handler already installed to keycode ", keyCode);
//                return passfail.fail;
//            }
//            global.keyHandlers[keyCode].set(node, &PCKeyboardMidiInputDevice.keyHandler);
//        }
//        if (keyCode == ubyte.max)
//            break;
//    }
//    return passfail.pass;
//}
//
//struct KeyHandler(T)
//{
//    import mar.windows : KeyEventRecord;
//    bool down; // stop multiple down events
//    private T* context;
//    private void function(T*, KeyEventRecord*) handler;
//    bool isSet() const { return context !is null; }
//    void set(U)(U* context, void function(U*, KeyEventRecord*) handler)
//    {
//        this.context = cast(T*)context;
//        this.handler = cast(typeof(this.handler))handler;
//    }
//    void call(KeyEventRecord* keyEvent)
//    {
//        if (keyEvent.down)
//        {
//            if (this.down)
//                return;
//            this.down = true;
//        }
//        else
//        {
//            this.down = false;
//        }
//        handler(context, keyEvent);
//    }
//}
//
pub fn startInputThread() !void {
    const lock = global.inputThreadMutex.acquire();
    defer lock.release();

    if (!global.inputThreadRunning)
    {
        global.inputThread = try std.Thread.spawn(inputThreadEntry, {});
        global.inputThreadRunning = true;
    }
}
pub fn joinInputThread() void {
    var inputThreadCached : *std.Thread = undefined;
    {
        const lock = global.inputThreadMutex.acquire();
        defer lock.release();
        if (!global.inputThreadRunning)
            return;
        inputThreadCached = global.inputThread;
    }
    inputThreadCached.wait();
}

pub fn inputThreadEntry(context: void) void {
    inputlog.debug("inputThread started!", .{});
    const result = inputThread2();
    if (result) {
        inputlog.info("inputThread is exiting with no error", .{});
    } else |err| {
        inputlog.err("inputThread failed with {}", .{err});
    }
}
fn inputThread2() !void {
    inputlog.debug("inputThreadEntry!", .{});
    var mode = try audio.osinput.ConsoleMode.setup();
    defer mode.restore();

    inputLoop: while(true)
    {
        var inputEvents = audio.osinput.InputEvents(128).init();
        for (try inputEvents.read()) |*inputEvent| {
            if (inputEvent.isKeyEvent()) |keyEvent| {
                const code = keyEvent.getKeyCode();
                const down = keyEvent.getKeyDown();
                //logDebug("KEY_EVENT code={} {}", code, if (down) "down" else "up");

                if (code == audio.osinput.KEY_ESCAPE) {
                    inputlog.info("ESC key pressed", .{});
                    break :inputLoop;
                }
                // TODO: handle CTL-C
                //if (code == VK_ESCAPE) {
                //    log("CTL-C pressed");
                //    break :inputLoop;
                //}
            //    if (code > global.keyHandlers.length)
            //    {
            //        // log something?
            //    }
            //    else
            //    {
            //        enterGlobalCriticalSection();
            //        scope (exit) exitGlobalCriticalSection();
            //        if (global.keyHandlers[code].isSet)
            //        {
            //            global.keyHandlers[code].call(&inputBuffer[i].key);
            //        }
            //        else
            //        {
            //            //logDebug("keycode ", code, " has no handler");
            //        }
            //    }
//
            } else {
                inputlog.debug("unhandled event type: {}", .{inputEvent.getEventType()});
            }
        }
    }
}
