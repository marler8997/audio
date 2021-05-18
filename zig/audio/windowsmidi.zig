const std = @import("std");

const audio = @import("../audio.zig");
usingnamespace audio.log;

const win32 = @import("win32");
usingnamespace win32.media.multimedia;
usingnamespace @import("win32missing.zig");

//alias WindowsMidiGenerator = MidiGeneratorTemplate!MidiInputDevice;
pub const MidiInputDevice = struct {
    const State = enum {
        initial,
        midiInOpened,
        started,
    };

    midiGeneratorTypeA: audio.dag.MidiGeneratorTypeA,
    midiGeneratorTypeAImpl: audio.dag.MidiGeneratorTypeAImpl,
    state: State,
    midiHandle: HMIDIIN,
    pub fn init() @This() {
        return @This() {
            .midiGeneratorTypeAImpl = audio.dag.MidiGeneratorTypeAImpl {
            },
            .midiGeneratorTypeA = audio.dag.MidiGeneratorTypeA.init(),
            .state = State.initial,
            .midiHandle = undefined,
        };
    }
    pub fn asMidiGeneratorNode(self: *MidiInputDevice) *audio.dag.MidiGenerator {
        return &self.midiGeneratorTypeA.midiGenerator;
    }
    fn midiInputCallback(handle: HMIDIIN, msg: u32,
        instance: usize, param1: *u32, param2: *u32) callconv(std.os.windows.WINAPI) void {
        var device = @intToPtr(*MidiInputDevice, instance);
        switch (msg) {
            MM_MIM_OPEN => {
                logDebug("[MidiListenCallback] open", .{});
            },
            MM_MIM_CLOSE => {
                logDebug("[MidiListenCallback] close", .{});
            },
            MM_MIM_DATA => {
                const status = LOBYTE(
                    @intCast(u16, 0xffff & @ptrToInt(param1)));
                const timestamp = @intCast(u32, 0xffffffff & @ptrToInt(param2));

                const category = status & 0xf0;
                const NoteType = enum { notNote, noteOff, noteOn };
                var noteType : NoteType = undefined;
                if (category == audio.midi.MidiMessageCategory.noteOff) {
                    noteType = NoteType.noteOff;
                } else if (category == audio.midi.MidiMessageCategory.noteOn) {
                    noteType = NoteType.noteOn;
                } else {
                    noteType = NoteType.notNote;
                }

                if (noteType != NoteType.notNote) {
                    const note     = HIBYTE(
                        LOWORD(@intCast(u32, 0xffffffff & @ptrToInt(param1))));
                    const velocity = LOBYTE(
                        HIWORD(@intCast(u32, 0xffffffff & @ptrToInt(param1))));

                    if (note & 0x80 != 0) {
                        logError("Bad MIDI note 0x{x} the MSB is set", .{note});
                    } else if (velocity & 0x80 != 0) {
                        logError("Bad MIDI velocity 0x{x} the MSB is set", .{velocity});
                    } else {
                        const onOffString = if (noteType == NoteType.noteOff) "OFF" else "ON";
                        logDebug("[MidiListenCallback] {} note {} {s}, velocity={}",
                            .{timestamp, note, onOffString, velocity});
                        if (noteType == .noteOff) {
                            device.midiGeneratorTypeA.addMidiEvent(
                                audio.midi.MidiEvent.makeNoteOff(timestamp, @intToEnum(audio.midi.MidiNote, @intCast(u7, note)))) catch |err| {
                                    logError("failed to add MIDI OFF event: {}", .{err});
                            };
                        } else {
                            device.midiGeneratorTypeA.addMidiEvent(
                                audio.midi.MidiEvent.makeNoteOn(timestamp, @intToEnum(audio.midi.MidiNote, @intCast(u7, note)), velocity)) catch |err| {
                                    logError("failed to add MIDI ON event: {}", .{err});
                            };
                        }
                        //const result = (cast(WindowsMidiGenerator*)instance).tryAddMidiEvent(
                        //    MidiEvent.makeNoteOff(timestamp, cast(MidiNote)note));
                        //if (result.failed)
                        //{
                        //    logError("failed to add MIDI OFF event: ", result);
                        //}
                    }
                } else {
                    logDebug("[MidiListenCallback] {} data status=0x{x}", .{timestamp, status});
                }

//        case MIM_DATA: {
//            // param1 (low byte) = midi event
//            // param2            = timestamp
//            const status = MIDI_STATUS(param1);
//            const category = status & 0xF0;
//            if(category == MidiMsgCategory.noteOff)
//            {
//                const note     = HIBYTE(LOWORD(param1));
//                const velocity = LOBYTE(HIWORD(param1));
//                const timestamp = cast(size_t)param2;
//
//                if (note & 0x80)
//                    logError("Bad MIDI note 0x", note.formatHex, ", the MSB is set");
//                else if (velocity & 0x80)
//                    logError("Bad MIDI velocity 0x", note.formatHex, ", the MSB is set");
//                else
//                {
//                    //logDebug("[MidiListenCallback] note ", note, " OFF, velocity=", velocity, " timestamp=", timestamp);
//                    const result = (cast(WindowsMidiGenerator*)instance).tryAddMidiEvent(
//                        MidiEvent.makeNoteOff(timestamp, cast(MidiNote)note));
//                    if (result.failed)
//                    {
//                        logError("failed to add MIDI OFF event: ", result);
//                    }
//                }
//            }
//            else if(category == MidiMsgCategory.noteOn)
//            {
//                const note     = HIBYTE(LOWORD(param1));
//                const velocity = LOBYTE(HIWORD(param1));
//                const timestamp = cast(size_t)param2;
//                //logDebug("[MidiListenCallback] note ", note, " ON,  velocity=", velocity, " timestamp=", timestamp);
//                if (note & 0x80)
//                    logError("Bad MIDI note 0x", note.formatHex, ", the MSB is set");
//                else if (velocity & 0x80)
//                    logError("Bad MIDI velocity 0x", note.formatHex, ", the MSB is set");
//                else
//                {
//                    const result = (cast(WindowsMidiGenerator*)instance).tryAddMidiEvent(
//                        MidiEvent.makeNoteOn(timestamp, cast(MidiNote)note, velocity));
//                    if (result.failed)
//                    {
//                        logError("failed to add MIDI ON event: ", result);
//                    }
//                }
//            }
//            else if (category == MidiMsgCategory.control)
//            {
//                const number = HIBYTE(LOWORD(param1));
//                const value  = LOBYTE(HIWORD(param1));
//                const timestamp = cast(size_t)param2;
//                if (number == MidiControlCode.sustainPedal)
//                {
//                    bool on = value >= 64;
//                    //logDebug("[MidiListenCallback] sustain: ", on ? "ON" : "OFF");
//                    const result = (cast(WindowsMidiGenerator*)instance).tryAddMidiEvent(
//                        MidiEvent.makeSustainPedal(timestamp,on));
//                    if (result.failed)
//                    {
//                        logError("failed to add MIDI event: ", result);
//                    }
//                }
//                else
//                {
//                    //logDebug("[MidiListenCallback] control ", number, "=", value);
//                }
//            }
//            else
//            {
//                logDebug("[MidiListenCallback] data, unknown category 0x", status.formatHex);
//            }
//            //printf("[MidiListenCallback] data (event=%d, timestampe=%d)\n",
//            //(byte)param1, param2);
//            break;
            },
//        } case MIM_LONGDATA:
//            logDebug("[MidiListenCallback] longdata");
//            break;
//        case MIM_ERROR:
//            logDebug("[MidiListenCallback] error");
//            break;
//        case MIM_LONGERROR:
//            logDebug("[MidiListenCallback] longerror");
//            break;
//        case MIM_MOREDATA:
//            logDebug("[MidiListenCallback] moredata");
//            break;
            else => {
                logDebug("[MidiListenCallback] UNHANDLED msg={}", .{msg});
            },
        }
//        flushDebug();
    }

    //static passfail startMidiDeviceInput(WindowsMidiGenerator* node, uint midiDeviceID) {
    pub fn startMidiDeviceInput(device: *MidiInputDevice, midiDeviceID: u32) !void {

        errdefer stopMidiDeviceInput(device) catch {}; // just attempt to stop on failure

        if (device.state == State.initial) {
            const result = midiInOpen(&device.midiHandle, midiDeviceID,
                @ptrToInt(midiInputCallback),
                @ptrToInt(device), CALLBACK_FUNCTION);
            if (result != MMSYSERR_NOERROR) {
                logError("midiInOpen failed, result={}", .{result});
                return error.Unexpected;
            }
            device.state = State.midiInOpened;
        }
        if (device.state == State.midiInOpened) {
            const result = midiInStart(device.midiHandle);
            if (result != MMSYSERR_NOERROR) {
                logError("midiInStart failed, result={}", .{result});
                return error.Unexpected;
            }
            device.state = State.started;
        }
    }

    //static passfail stopMidiDeviceInput(WindowsMidiGenerator* node) {
    pub fn stopMidiDeviceInput(device: *MidiInputDevice) !void {
        logDebug("stopMidiInputDevice", .{});
        if (device.state == State.started) {
            const result = midiInStop(device.midiHandle);
            if (result != MMSYSERR_NOERROR) {
                logError("midiInStop failed, result={}", .{result});
                return error.Unexpected;
            }
            device.state = State.midiInOpened;
        }
        if (device.state == State.midiInOpened) {
            const result = midiInClose(device.midiHandle);
            if (result != MMSYSERR_NOERROR) {
                logError("midiInClose failed, result={}", .{result});
                return error.Unexpected;
            }
            device.state = State.initial;
        }
    }
};
