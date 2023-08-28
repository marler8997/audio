const std = @import("std");
const win32 = struct {
    usingnamespace @import("win32").zig;
    usingnamespace @import("win32").foundation;
    usingnamespace @import("win32").media;
    usingnamespace @import("win32").media.audio;
};

const tevirtualmidi = @import("tevirtualmidi.zig");

const audio = @import("audio");

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

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

pub fn main() !u8 {
    const all_cmd_args = try std.process.argsAlloc(allocator);
    // no need to free

    if (all_cmd_args.len <= 1) {
        try std.io.getStdErr().writer().print("Usage: midilogger DEVICE_NAME\n", .{});
        return 0xff;
    }
    const cmd_args = all_cmd_args[1..];
    if (cmd_args.len != 1) {
        std.log.err("expected 1 command-line argument but got {}", .{cmd_args.len});
        return 0xff;
    }
    const device_name = try std.unicode.utf8ToUtf16LeWithNull(allocator, cmd_args[0]);

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
            {
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

            offset += process_result.len;
        }

        if (offset < buf_len) {
            std.log.err("offset={} len={} not implemented", .{offset, buf_len});
            return 0xff;
        }
    }

    return 0;
}
