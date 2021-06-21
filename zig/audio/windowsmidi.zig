const std = @import("std");
const midilog = std.log.scoped(.midi);

const audio = @import("../audio.zig");

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
    fn midiInputCallback(
        handle: HMIDIIN,
        msg: u32,
        instance: usize,
        param1: usize,
        param2: usize
    ) callconv(std.os.windows.WINAPI) void {
        var device = @intToPtr(*MidiInputDevice, instance);
        switch (msg) {
            MM_MIM_OPEN => {
                midilog.debug("[MidiListenCallback] open", .{});
            },
            MM_MIM_CLOSE => {
                midilog.debug("[MidiListenCallback] close", .{});
            },
            MM_MIM_DATA => {
                const midi_msg = audio.midi.MidiMsgUnion { .bytes = [3]u8 {
                    @intCast(u8, (param1 >>  0) & 0xFF),
                    @intCast(u8, (param1 >>  8) & 0xFF),
                    @intCast(u8, (param1 >> 16) & 0xFF),
                }};
                audio.midi.logMidiMsg(midi_msg.msg);
                audio.midi.msgToDevice(
                    param2, // timestamp
                    midi_msg.msg,
                    device.midiGeneratorTypeA,
                );
                //midilog.debug("[MidiListenCallback] {} note {} {}, velocity={}",
                //    .{timestamp, note, note_type, velocity});
                //switch (note_type) {
                //    .off => {
                //        device.midiGeneratorTypeA.addMidiEvent(
                //            audio.midi.MidiEvent.makeNoteOff(timestamp, @intToEnum(audio.midi.MidiNote, @intCast(u7, note)))) catch |err| {
                //                midilog.err("failed to add MIDI OFF event: {}", .{err});
                //        };
                //    },
                //    .on => {
                //        device.midiGeneratorTypeA.addMidiEvent(
                //            audio.midi.MidiEvent.makeNoteOn(timestamp, @intToEnum(audio.midi.MidiNote, @intCast(u7, note)), velocity)) catch |err| {
                //                midilog.err("failed to add MIDI ON event: {}", .{err});
                //        };
                //    },
                //}
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
                midilog.warn("[MidiListenCallback] UNHANDLED msg={}", .{msg});
            },
        }
    }

    //static passfail startMidiDeviceInput(WindowsMidiGenerator* node, uint midiDeviceID) {
    pub fn startMidiDeviceInput(device: *MidiInputDevice, midiDeviceID: u32) !void {

        errdefer stopMidiDeviceInput(device) catch {}; // just attempt to stop on failure

        if (device.state == State.initial) {
            const result = midiInOpen(&device.midiHandle, midiDeviceID,
                @ptrToInt(midiInputCallback),
                @ptrToInt(device), CALLBACK_FUNCTION);
            if (result != MMSYSERR_NOERROR) {
                midilog.err("midiInOpen failed, result={}", .{result});
                return error.Unexpected;
            }
            device.state = State.midiInOpened;
        }
        if (device.state == State.midiInOpened) {
            const result = midiInStart(device.midiHandle);
            if (result != MMSYSERR_NOERROR) {
                midilog.err("midiInStart failed, result={}", .{result});
                return error.Unexpected;
            }
            device.state = State.started;
        }
    }

    //static passfail stopMidiDeviceInput(WindowsMidiGenerator* node) {
    pub fn stopMidiDeviceInput(device: *MidiInputDevice) !void {
        midilog.info("stopMidiInputDevice", .{});
        if (device.state == State.started) {
            const result = midiInStop(device.midiHandle);
            if (result != MMSYSERR_NOERROR) {
                midilog.err("midiInStop failed, result={}", .{result});
                return error.Unexpected;
            }
            device.state = State.midiInOpened;
        }
        if (device.state == State.midiInOpened) {
            const result = midiInClose(device.midiHandle);
            if (result != MMSYSERR_NOERROR) {
                midilog.err("midiInClose failed, result={}", .{result});
                return error.Unexpected;
            }
            device.state = State.initial;
        }
    }
};
