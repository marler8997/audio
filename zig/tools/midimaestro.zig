const std = @import("std");
const win32 = struct {
    usingnamespace @import("win32").zig;
    usingnamespace @import("win32").foundation;
    usingnamespace @import("win32").media;
    usingnamespace @import("win32").media.audio;
};

const tevirtualmidi = @import("tevirtualmidi.zig");

const audio = @import("audio");
const MidiNote = audio.midi.MidiNote;

fn dumpVersion(prefix: []const u8, func: anytype) void {
    var major: u16 = undefined;
    var minor: u16 = undefined;
    var release: u16 = undefined;
    var build: u16 = undefined;
    const str = func(&major, &minor, &release, &build);
    std.log.info("{s} version {}.{}.{}.{} \"{s}\"", .{
        prefix, major, minor, release, build, std.unicode.fmtUtf16le(std.mem.span(str)),
    });
}

var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena_instance.allocator();

pub fn main() !u8 {
    const all_cmd_args = try std.process.argsAlloc(allocator);
    // no need to free

    if (all_cmd_args.len <= 1) {
        try std.io.getStdErr().writer().print("Usage: midilogger DEVICE_NAME SONG_FILE\n", .{});
        return 0xff;
    }
    const cmd_args = all_cmd_args[1..];
    if (cmd_args.len != 2) {
        std.log.err("expected 2 command-line arguments but got {}", .{cmd_args.len});
        return 0xff;
    }
    const device_name = try std.unicode.utf8ToUtf16LeWithNull(allocator, cmd_args[0]);
    const song_file = cmd_args[1];

    const song_notes = loadSong(song_file);


    dumpVersion("virtualMIDI       ", tevirtualmidi.virtualMIDIGetVersion);
    dumpVersion("virtualMIDI Driver", tevirtualmidi.virtualMIDIGetDriverVersion);

    const midi_port = tevirtualmidi.virtualMIDICreatePortEx2(
        device_name,
        null, 0,
        10000,
        0,
    ) orelse {
        std.log.err("virtualMIDICreatePortEx2 failed, error={}", .{win32.GetLastError()});
        return 0xff;
    };
    // NOTE: the driver will close the midi port if our application exits so this isn't necessary
    //defer {
    //    std.log.info("closing midi port...", .{});
    //    tevirtualmidi.virtualMIDIClosePort(midi_port);
    //}

    std.log.info("midi port created, listening for data...", .{});

    var midi_processor = audio.midi.MidiStreamProcessor { };
    var song_state = SongState {
        .notes = song_notes,
    };

    var input_note_to_song_index = [1]?usize { null } ** 128;
    const NoteOnState = struct {
        input_note_owner: ?MidiNote = null, // the input note that when released will cause this note to go off
    };
    var note_on_table = [1]NoteOnState { NoteOnState{} } ** 128;

    while (true) {
        var buf: [1000]u8 = undefined;
        var buf_len: u32 = buf.len;
        {
            const result = tevirtualmidi.virtualMIDIGetData(midi_port, &buf, &buf_len);
            if (result != 1) {
                std.log.err("virtualMIDIGetData failed, result={}, error={}", .{result, win32.GetLastError()});
                return 0xff;
            }
        }

        var offset: u32 = 0;
        while (offset < buf_len) {
            const process_result = midi_processor.process(buf[offset..]) catch |err| switch (err) {
                error.MidiMsgStatusMsbIsZero => {
                    std.log.err("invalid midi data", .{});
                    return 0xff;
                },
                error.NeedMoreData => break,
            };

            audio.midi.checkMidiMsg(process_result.msg) catch |e| {
                std.log.err("Midi Message Error: {}", .{e});
                return 0xff;
            };
            audio.midi.logMidiMsg(process_result.msg);

            switch (process_result.msg.kind) {
                .note_on => {

                    if (input_note_to_song_index[process_result.msg.data.note_on.note]) |_| {
                        std.log.warn("note {} is already on? Should I treat this as an off/on? Ignoring for now", .{
                            @intToEnum(MidiNote, process_result.msg.data.note_on.note)});
                        break;
                    }
                    input_note_to_song_index[process_result.msg.data.note_on.note] = song_state.next;

                    while (true) {
                        const note = song_state.notes[song_state.next];
                        song_state.next += 1;
                        if (song_state.next == song_state.notes.len) {
                            // the last note of a song should never be attached
                            std.debug.assert(!note.attached);
                            song_state.next = 0;
                        }

                        if (note_on_table[@intFromEnum(note.note)].input_note_owner) |_| {
                            // we need to turn it off before turning it back on
                            sendNoteOff(midi_port, process_result.msg.status_arg, note.note, 0);
                            note_on_table[@intFromEnum(note.note)].input_note_owner = null;
                        }

                        std.log.info("next={} changed note {} to {}", .{song_state.next, @intToEnum(MidiNote, process_result.msg.data.note_on.note), note.note});

                        const msg = audio.midi.MidiMsg {
                            .kind = .note_on,
                            .status_arg = process_result.msg.status_arg, // channel
                            .msb_status = 1, // control byte
                            .data = .{ .note_on = .{
                                .note = @intFromEnum(note.note),
                                .msb_note = 0,
                                .velocity = process_result.msg.data.note_on.velocity,
                                .msb_velocity = 0,
                            }},
                        };
                        const send_result = tevirtualmidi.virtualMIDISendData(midi_port, @ptrCast([*]const u8, &msg), 3);
                        if (send_result != 1) {
                            std.log.err("failed to send note on MIDI message, result={}, error={}", .{send_result, win32.GetLastError()});
                            return 0xff;
                        }
                        note_on_table[@intFromEnum(note.note)].input_note_owner = @intToEnum(MidiNote, process_result.msg.data.note_on.note);
                        if (!note.attached) break;
                    }
                },
                .note_off => {
                    if (input_note_to_song_index[process_result.msg.data.note_off.note]) |song_note_index_const| {
                        var song_note_index = song_note_index_const;
                        while (true) : (song_note_index += 1) {
                            const note = song_state.notes[song_note_index];
                            if (note_on_table[@intFromEnum(note.note)].input_note_owner) |input_note_owner| {
                                if (input_note_owner == @intToEnum(MidiNote, process_result.msg.data.note_off.note)) {
                                    std.log.info("changed note off from {} to {}", .{@intToEnum(MidiNote, process_result.msg.data.note_off.note), note.note});
                                    sendNoteOff(midi_port, process_result.msg.status_arg, note.note, process_result.msg.data.note_off.velocity);
                                    note_on_table[@intFromEnum(note.note)].input_note_owner = null;
                                } else {
                                    std.log.info("note {} lost ownership of {} to {}", .{@intToEnum(MidiNote, process_result.msg.data.note_off.note), note.note, input_note_owner});
                                }
                            } else {
                                std.log.info("note {} lost ownership of {} (is off now)", .{@intToEnum(MidiNote, process_result.msg.data.note_off.note), note.note});
                            }
                            if (!note.attached) break;
                        }
                        input_note_to_song_index[process_result.msg.data.note_off.note] = null;
                    } else {
                        std.log.info("got note_off for note {} that wasn't on", .{@intToEnum(MidiNote, process_result.msg.data.note_off.note)});
                    }
                },
                else => {
                    const send_result = tevirtualmidi.virtualMIDISendData(
                        midi_port,
                        @as([*]u8, &buf) + offset,
                        process_result.len,
                    );
                    if (send_result != 1) {
                        std.log.err("failed to send midi message, result={}, error={}", .{send_result, win32.GetLastError()});
                        return 0xff;
                    }
                }
            }

            offset += process_result.len;
        }

        if (offset < buf_len) {
            std.log.err("offset={} len={} not implemented", .{offset, buf_len});
            return 0xff;
        }
    }

    return 0;
}

fn sendNoteOff(midi_port: *tevirtualmidi.VM_MIDI_PORT, channel: u4, note: MidiNote, velocity: u7) void {
    const msg = audio.midi.MidiMsg {
        .kind = .note_off,
        .status_arg = channel, // channel
        .msb_status = 1, // control byte
        .data = .{ .note_off = .{
            .note = @intFromEnum(note),
            .msb_note = 0,
            .velocity = velocity,
            .msb_velocity = 0,
        }},
    };
    const send_result = tevirtualmidi.virtualMIDISendData(midi_port, @ptrCast([*]const u8, &msg), 3);
    if (send_result != 1) {
        std.log.err("failed to send note off MIDI message, result={}, error={}", .{send_result, win32.GetLastError()});
        std.os.exit(0xff);
    }
}

const Note = struct {
    note: MidiNote,
    attached: bool,
};

const SongState = struct {
    notes: []const Note,
    next: usize = 0,
};

const ParseError = struct {
    kind: enum {
        unfinishedNote,
        expectedOctaveNum,
        unexpectedCharInGlobalContext,
    },
    index: usize,

};
const note_offset_table = [_]i8 {
    9, // a
    11, // b
    0, // c
    2, // d
    4, // e
    5, // f
    7, // g
};
fn parse(note_builder: anytype, text: []const u8) error{OutOfMemory}!?ParseError {
    var index: usize = 0;
    var attach_previous_to_next_note: bool = false;
    while (true) {
        if (index >= text.len) return null;
        const c = text[index];
        if (c >= 'a' and c <= 'g') {
            //const note_start = index;
            if (attach_previous_to_next_note) {
                note_builder.items[note_builder.items.len - 1].attached = true;
            }

            index += 1;
            if (index == text.len) return ParseError{ .kind = .unfinishedNote, .index = index - 1 };
            const c2 = text[index];
            var mod: i2 = 0;
            if (c2 == '#') {
                mod = 1;
                index += 1;
                if (index == text.len) return ParseError{ .kind = .unfinishedNote, .index = index - 1 };
            } else if (c2 == 'b') {
                mod = -1;
                index += 1;
                if (index == text.len) return ParseError{ .kind = .unfinishedNote, .index = index - 1 };
            }
            const c3 = text[index];
            if (c3 < '0' or c3 > '9') return ParseError{ .kind = .expectedOctaveNum, .index = index };
            index += 1;
            const octave = c3 - '0' + 1;
            const note_offset: i8 = note_offset_table[c - 'a'];

            //std.log.info("{s} octave={} note_offset={} mod={}", .{text[note_start..index], octave, note_offset, mod});
            const note = @intCast(i8, octave * 12) + note_offset + @intCast(i8, mod);
            try note_builder.append(Note{ .note = @intToEnum(MidiNote, note), .attached = false });
            attach_previous_to_next_note = true;
        } else if (c == ' ') {
            index += 1;
        } else if (c == '\n') {
            attach_previous_to_next_note = false;
            index += 1;
        } else {
            return ParseError{ .kind = .unexpectedCharInGlobalContext, .index = index };
        }
    }
}

fn loadSong(filename: []const u8) []Note {
    const text = blk: {
        const file = std.fs.cwd().openFile(filename, .{}) catch |err| {
            std.log.err("failed to open '{s}': {s}", .{filename, @errorName(err)});
            std.os.exit(0xff);
        };
        defer file.close();
        break :blk file.readToEndAlloc(allocator, std.math.maxInt(usize)) catch @panic("Out Of Memory");
    };
    defer allocator.free(text);

    var notes = std.ArrayList(Note).init(allocator);
    if (parse(&notes, text) catch @panic("Out Of Memory")) |err| {
        std.debug.panic("got error {}", .{err});
    }
    //for (notes.items) |note| {
    //    std.log.info("{} {}", .{note.note, note.attached});
    //}
    return notes.toOwnedSlice();
}
