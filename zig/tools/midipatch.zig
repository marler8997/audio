const std = @import("std");
const win32 = struct {
    usingnamespace @import("win32").foundation;
    usingnamespace @import("win32").system.threading;
    usingnamespace @import("win32").media;
    usingnamespace @import("win32").media.audio;
};

const audio = @import("audio");

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = &arena.allocator;

pub fn main() !u8 {
    const all_cmd_args = try std.process.argsAlloc(allocator);
    // no need to free

    if (all_cmd_args.len <= 1) {
        try std.io.getStdErr().writer().writeAll(
            \\patches MIDI data from an input device to an output device
            \\
            \\Usage: midipatch INPUT_DEVICE_NUM OUTPUT_DEVICE_NUM
            \\
        );
        return 0xff;
    }
    const cmd_args = all_cmd_args[1..];
    if (cmd_args.len != 2) {
        std.log.err("expected 2 command-line arguments but got {}", .{cmd_args.len});
        return 0xff;
    }
    const input_num = std.fmt.parseInt(u32, cmd_args[0], 10) catch |err| {
        std.log.err("INPUT_DEVICE_NUM '{s}' is not an integer: {s}", .{cmd_args[0], @errorName(err)});
        return 0xff;
    };
    const output_num = std.fmt.parseInt(u32, cmd_args[1], 10)catch |err| {
        std.log.err("OUTPUT_DEVICE_NUM '{s}' is not an integer: {s}", .{cmd_args[1], @errorName(err)});
        return 0xff;
    };
    
    logDevices(input_num, output_num);

    var output_handle: win32.HMIDIOUT = undefined;
    {
        const result = win32.midiOutOpen(
            // TODO: this cast shouldn't be necessary, file an issue?
            @ptrCast(*?win32.HMIDIOUT, &output_handle),
            output_num,
            0, 0, win32.CALLBACK_NULL);
        if (result != win32.MMSYSERR_NOERROR) {
            std.log.err("midiOutOpen {} failed with {}", .{output_num, audio.windows.mmsystem.fmtMmsyserr(result)});
            return 0xff;
        }
    }
    // No need to close output_handle

    // What follows is an odd incantation
    // Passing CALLBACK_NULL doesn't work, but CALLBACK_THREAD seems to work even though the thread is never
    // resumed after calling SuspendThread.  I still have to call midiInStart as well.
    // Also note that in this case the main thread is just stuck with nothing to do, there must be another
    // thread servicing the midi data, I'm not sure how to service the midi input data with the main thread.
    // Note I also tried CALLBACK_FUNCTION but this was even worse as I had to provide a callback function
    // that's always called but doesn't need to do anything.

    var input_handle: win32.HMIDIIN = undefined;
    {
        const result = win32.midiInOpen(
            // TODO: this cast shouldn't be necessary, file an issue?
            @ptrCast(*?win32.HMIDIIN, &input_handle),
            input_num,
            win32.GetCurrentThreadId(),
            0,
            win32.CALLBACK_THREAD, // NOTE: CALLBACK_NULL doesn't work
        );
        if (result != win32.MMSYSERR_NOERROR) {
            std.log.err("midiInOpen {} failed with {}", .{input_num, audio.windows.mmsystem.fmtMmsyserr(result)});
            return 0xff;
        }
    }
    // No need to close input_handle

    {
        const result = win32.midiInStart(input_handle);
        if (result != win32.MMSYSERR_NOERROR) {
            std.log.err("midiInStart failed with {}", .{audio.windows.mmsystem.fmtMmsyserr(result)});
            return 0xff;
        }
    }


    {
        const result = win32.midiConnect(@ptrCast(win32.HMIDI, input_handle), output_handle, null);
        if (result != win32.MMSYSERR_NOERROR) {
            std.log.err("midiConnect failed with {}", .{audio.windows.mmsystem.fmtMmsyserr(result)});
            return 0xff;
        }
    }

    while (true) {
        const count = win32.SuspendThread(win32.GetCurrentThread());
        if (count == @bitCast(u32, @as(i32, -1))) {
            std.log.err("SuspendThread failed, error={}", .{win32.GetLastError()});
            std.os.exit(0xff);
        }
        std.log.info("SuspendThread returned count={}, is this normal? exiting...", .{count});
        return 0xff;
    }

    return 0;
}


fn logDevices(input_num: u32, output_num: u32) void {
    var input_caps: win32.MIDIINCAPS = undefined;
    {
        const result = win32.midiInGetDevCaps(input_num, &input_caps, @sizeOf(@TypeOf(input_caps)));
        if (result != win32.MMSYSERR_NOERROR) {
            std.log.err("midiInGetDevCaps failed with {}", .{audio.windows.mmsystem.fmtMmsyserr(result)});
            std.os.exit(0xff);
        }
    }

    var output_caps: win32.MIDIOUTCAPS = undefined;
    {
        const result = win32.midiOutGetDevCaps(output_num, &output_caps, @sizeOf(@TypeOf(output_caps)));
        if (result != win32.MMSYSERR_NOERROR) {
            std.log.err("midiOutGetDevCaps failed with {}", .{audio.windows.mmsystem.fmtMmsyserr(result)});
            std.os.exit(0xff);
        }
    }

    const input_name_fmt = blk: {
        // TODO: add support for non-unicode
        std.debug.assert(@TypeOf(input_caps.szPname) == [32]u16);
        const name_ptr: [*:0]u16 = @alignCast(2, @ptrCast([*:0]align(1) u16, &input_caps.szPname));
        const name_slice = std.mem.span(name_ptr);
        break :blk std.unicode.fmtUtf16le(name_slice);
    };

    const output_name_fmt = blk: {
        // TODO: add support for non-unicode
        std.debug.assert(@TypeOf(output_caps.szPname) == [32]u16);
        const name_ptr: [*:0]u16 = @alignCast(2, @ptrCast([*:0]align(1) u16, &output_caps.szPname));
        const name_slice = std.mem.span(name_ptr);
        break :blk std.unicode.fmtUtf16le(name_slice);
    };

    std.log.info("patching input \"{s}\" to output \"{s}\"", .{input_name_fmt, output_name_fmt});
}
