const std = @import("std");
const win32 = struct {
    usingnamespace @import("win32").zig;
    usingnamespace @import("win32").foundation;
    usingnamespace @import("win32").media;
    usingnamespace @import("win32").media.audio;
};

const audio = @import("audio");

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = &arena.allocator;

var global_state: struct {
    out_file: std.fs.File,
    at_line_start: bool,
} = .{
    .out_file = undefined,
    .at_line_start = true,
};

pub fn main() !u8 {
    const all_cmd_args = try std.process.argsAlloc(allocator);
    // no need to free

    if (all_cmd_args.len <= 1) {
        try std.io.getStdErr().writer().print("Usage: midirecorder INPUT_DEVICE_NUM OUTPUT_FILE\n", .{});
        return 0xff;
    }
    const cmd_args = all_cmd_args[1..];
    if (cmd_args.len != 2) {
        std.log.err("expected 2 command-line arguments but got {}", .{cmd_args.len});
        return 0xff;
    }
    const input_device_num = std.fmt.parseInt(u32, cmd_args[0], 10) catch |err| {
        std.log.err("INPUT_DEVICE_NUM '{s}' is not an integer: {s}", .{cmd_args[0], @errorName(err)});
        return 0xff;
    };
    const out_filename = cmd_args[1];
    global_state.out_file = std.fs.cwd().createFile(out_filename, .{}) catch |err| {
        std.log.err("failed to create output file '{s}': {s}", .{out_filename, @errorName(err)});
        return 0xff;
    };
    defer global_state.out_file.close();

    var reader = audio.windows.MidiReader.init(onMidiEvent);
    try reader.start(input_device_num);
    
    try audio.pckeyboard.startInputThread();
    std.log.info("Press ESC to quit", .{});
    audio.pckeyboard.joinInputThread();

    return 0;
}

fn onMidiEvent(timestamp: usize, msg: audio.midi.MidiMsg) void {
    _ = timestamp;
    onMidiEvent2(msg) catch |err| {
        std.log.err("error in MIDI callback: {s}", .{@errorName(err)});
        @panic("error in MIDI callback");
    };
}
fn onMidiEvent2(msg: audio.midi.MidiMsg) !void {
    audio.midi.checkMidiMsg(msg) catch |e| {
        std.log.err("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!", .{});
        std.log.err("Midi Message Error: {}", .{e});
    };
    audio.midi.logMidiMsg(msg);

    switch (msg.kind) {
        .note_on => {
            if (global_state.at_line_start) {
                global_state.at_line_start = false;
            } else {
                try global_state.out_file.writer().writeAll(" ");
            }
            try global_state.out_file.writer().print("{s}", .{@tagName(@intToEnum(audio.midi.MidiNote, msg.data.note_on.note))});
        },
        .note_off => {
            if (!global_state.at_line_start) {
                try global_state.out_file.writer().writeAll("\n");
                global_state.at_line_start = true;
            }
        },
        else => {
            std.log.err("unhandled midi msg {}", .{msg.kind});
            @panic("unhandled MIDI msg");
        },
    }
}
