const audio = @import("../audio.zig");
usingnamespace audio.log;

pub const MidiInputDevice = struct {
    midiGenerator: audio.dag.MidiGenerator,
    pub fn init() @This() {
        return @This() {
            .midiGenerator = undefined,
        };
    }
    pub fn asMidiGeneratorNode(self: *MidiInputDevice) *audio.dag.MidiGenerator {
        return &self.midiGenerator;
    }
    pub fn startMidiDeviceInput(device: *MidiInputDevice, midiDeviceID: u32) !void {
        return error.NotImplemented;
    }
    pub fn stopMidiDeviceInput(device: *MidiInputDevice) !void {
        return error.NotImplemented;
    }
};
