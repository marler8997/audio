pub const zin_config: zin.Config = .{
    .StaticWindowId = StaticWindowId,
    .x11_on_visual = x11Visual,
    // An optional callback if an x11 unhandled reply comes in.  Allows apps to
    // send their own X11 requests outside of what Zin supports.
    .x11_on_unhandled_reply = x11UnhandledReply,
};
const StaticWindowId = enum {
    main,
    pub fn getConfig(self: StaticWindowId) zin.WindowConfigData {
        return switch (self) {
            .main => .{
                .window_size_events = true,
                .key_events = true,
                .mouse_events = true,
                .timers = .one,
                .background = .{ .r = 49, .g = 49, .b = 49 },
                .dynamic_background = false,
                .win32 = .{ .render = .{ .gdi = .{} } },
                .x11 = .{ .render_kind = .double_buffered },
            },
        };
    }
};

pub const panic = zin.panic(.{ .title = "Audio Panic!" });

const midilog = std.log.scoped(.midi);

const global = struct {
    var main_thread: std.Thread.Id = undefined;
    var last_animation: ?std.time.Instant = null;
    var text_position: f32 = 0;
    var mouse_position: ?zin.XY = null;
    var mouse_down: zin.MouseButtonsDown = .{
        .left = false,
        .right = false,
        .middle = false,
    };
};

pub fn main() !void {
    global.main_thread = std.Thread.getCurrentId();

    if (builtin.os.tag == .windows) {
        const hr = win32.CoInitializeEx(null, .{});
        if (hr < 0) win32.panicHresult("CoInitializeEx", hr);
    }

    // one-time process initialization
    try zin.processInit(.{});

    {
        var err: zin.X11ConnectError = undefined;
        zin.x11Connect(&err) catch std.debug.panic("X11 connect failed: {f}", .{err});
    }
    defer zin.x11Disconnect();

    // const icons = getIcons(96, 96);

    zin.staticWindow(.main).registerClass(.{
        .callback = zinCallback,
        .win32_name = zin.L("AudioMainWindow"),
        .macos_view = "AudioView",
    }, .{
        // .win32_icon_large = icons.large,
        // .win32_icon_small = icons.small,
        .win32_icon_large = .none,
        .win32_icon_small = .none,
    });
    defer zin.staticWindow(.main).unregisterClass();

    try zin.staticWindow(.main).create(.{
        .title = "Audio",
        .size = .{ .client_points = .{ .x = 600, .y = 400 } },
        .pos = null,
    });
    defer zin.staticWindow(.main).destroy();
    zin.staticWindow(.main).show();
    zin.staticWindow(.main).startTimerMillis({}, 14);

    openMidi();

    {
        const thread = try std.Thread.spawn(.{}, audioThread, .{});
        thread.detach();
    }

    try zin.mainLoop();
}

fn openMidi() void {
    if (builtin.os.tag == .windows) {
        // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
        std.log.info("calling midiInOpen from thread {}", .{std.Thread.getCurrentId()});
        var handle: win32.HMIDIIN = undefined;
        {
            const result = win32.midiInOpen(
                // TODO: this cast shouldn't be necessary, file an issue?
                @ptrCast(&handle),
                0,
                @intFromPtr(&midiInCallback),
                // @intFromPtr(self),
                0,
                win32.CALLBACK_FUNCTION,
            );
            if (result != win32.MMSYSERR_NOERROR) {
                std.log.err("midiInOpen failed, error={f}", .{mmsystem.fmtMmsyserr(result)});
                return;
            }
        }

        {
            const result = win32.midiInStart(handle);
            if (result != win32.MMSYSERR_NOERROR) {
                midilog.err("midiInStart failed, error={f}", .{mmsystem.fmtMmsyserr(result)});
            }
        }
    } else {
        @compileError("midi");
    }
}

fn midiInCallback(handle: win32.HMIDIIN, msg: u32, instance: usize, param1: usize, param2: usize) callconv(.winapi) void {

    // NOTE: we may not be on the main thread
    {
        // const thread_id = std.Thread.getCurrentId();
        // if (global.main_thread != thread_id) {
        //     std.debug.panic("MainThread {} != CallbackThread {}", .{ global.main_thread, thread_id });
        // }
        // std.debug.assert(global.main_thread == std.Thread.getCurrentId());
    }
    _ = handle;
    _ = instance;
    _ = param2;

    // var device: *@This() = @ptrFromInt(instance);
    switch (msg) {
        win32.MM_MIM_OPEN => {
            midilog.debug("open", .{});
        },
        win32.MM_MIM_CLOSE => {
            midilog.debug("close", .{});
        },
        win32.MM_MIM_DATA => {
            // const midi_msg: u24 = @intCast((param1 << 16) & 0xff0000 |
            //     (param1 << 8) & 0x00ff00 |
            //     (param1 << 0) & 0x0000ff);
            // @as(u24, @intCast((param1 >> 0) & 0xFF)) |
            // @as(u24, @intCast((param1 >> 8) & 0xFF)) |
            // @as(u24, @intCast((param1 >> 16) & 0xFF));
            const midi_msg: u24 = @intCast(0xffffff & param1);
            midilog.info("MIDI: 0x{x}", .{midi_msg});
            // device.callback(param2, @bitCast(midi_msg));
        },
        //        } case win32.MIM_LONGDATA:
        //            logDebug("[MIDI] longdata");
        //            break;
        //        case win32.MIM_ERROR:
        //            logDebug("[MIDI] error");
        //            break;
        //        case win32.MIM_LONGERROR:
        //            logDebug("[MIDI] longerror");
        //            break;
        //        case win32.MIM_MOREDATA:
        //            logDebug("[MIDI] moredata");
        //            break;
        else => {
            midilog.warn("[MIDI] UNHANDLED msg={}", .{msg});
        },
    }
}

fn zinCallback(cb: zin.Callback(.{ .static = .main })) void {
    switch (cb) {
        .close => zin.quitMainLoop(),
        .window_size => {},
        .draw => |d| {
            {
                const now = std.time.Instant.now() catch @panic("?");
                const elapsed_ns = if (global.last_animation) |l| now.since(l) else 0;
                global.last_animation = now;

                const speed: f32 = 0.0000000001;
                global.text_position = @mod(global.text_position + speed * @as(f32, @floatFromInt(elapsed_ns)), 1.0);
            }

            const size = zin.staticWindow(.main).getClientSize();
            d.clear();
            const animate: zin.XY = .{
                .x = @intFromFloat(@round(@as(f32, @floatFromInt(size.x)) * global.text_position)),
                .y = @intFromFloat(@round(@as(f32, @floatFromInt(size.y)) * global.text_position)),
            };
            const dpi_scale = d.getDpiScale();

            // currenly only supported on windows
            if (zin.platform_kind == .win32 or zin.platform_kind == .x11) {
                var pentagon = [5]zin.PolygonPoint{
                    .xy(zin.scale(i32, 200, dpi_scale.x), zin.scale(i32, 127, dpi_scale.y)), // top
                    .xy(zin.scale(i32, 232, dpi_scale.x), zin.scale(i32, 150, dpi_scale.y)), // top right
                    .xy(zin.scale(i32, 220, dpi_scale.x), zin.scale(i32, 187, dpi_scale.y)), // bottom right
                    .xy(zin.scale(i32, 180, dpi_scale.x), zin.scale(i32, 187, dpi_scale.y)), // bottom left
                    .xy(zin.scale(i32, 168, dpi_scale.x), zin.scale(i32, 150, dpi_scale.y)), // top left
                };
                d.polygon(&pentagon, .blue);
            }

            const rect_size = zin.scale(i32, 10, dpi_scale.x);
            d.rect(.ltwh(animate.x, size.y - animate.y, rect_size, rect_size), .red);
            const margin_left = zin.scale(i32, 10, dpi_scale.x);
            const margin_top = zin.scale(i32, 10, dpi_scale.y);
            const line_height = zin.scale(i32, 20, dpi_scale.y);

            const top = zin.scale(i32, 50, dpi_scale.y);
            {
                var str_buf: [100]u8 = undefined;
                const str = std.fmt.bufPrint(&str_buf, "Mouse left:{s} right:{s} middle:{s}", .{
                    if (global.mouse_down.left) "1" else "0",
                    if (global.mouse_down.right) "1" else "0",
                    if (global.mouse_down.middle) "1" else "0",
                }) catch unreachable;
                d.text(str, margin_left, top + zin.scale(i32, 20, dpi_scale.y), .white);
            }
            d.text("Weeee!!!", animate.x, animate.y, .white);
            if (global.mouse_position) |p| {
                d.text("Mouse", p.x, p.y, .white);
            }

            var y = margin_top;

            {
                const count = midi.countIn();
                if (count == 0) {
                    d.text("No MIDI Inputs", margin_left, margin_top, .white);
                } else {
                    d.text("MIDI Inputs:", margin_left, margin_top, .white);
                    y += line_height;
                    for (0..count) |i| {
                        var text_buf: [100]u8 = undefined;
                        const text = bufPrint(&text_buf, "{}: {f}", .{ i, midi.fmtIn(@intCast(i)) });
                        d.text(text, margin_left, y, .white);
                        y += line_height;
                    }
                }
            }
        },
        .timer => zin.staticWindow(.main).invalidate(),
        .key => |key| {
            _ = key;
            // var keyboard_state: zin.UnicodeKeyboardState = .init();
            // const utf8 = key.utf8(keyboard_state.ref());
            // if (null != std.mem.indexOfScalar(u8, utf8.slice(), 'n')) {
            // }
        },
        .mouse => |mouse| {
            global.mouse_position = mouse.position;
            global.mouse_down = mouse.down;
            zin.staticWindow(.main).invalidate();
        },
    }
}

fn audioThread() void {
    if (builtin.os.tag == .windows) {
        if (0 == win32.SetThreadPriority(win32.GetCurrentThread(), win32.THREAD_PRIORITY_TIME_CRITICAL)) win32.panicWin32(
            "SetThreadPriority",
            win32.GetLastError(),
        );
    }

    // TODO: render audio
}

fn bufPrint(buf: []u8, comptime fmt: []const u8, args: anytype) []u8 {
    std.debug.assert(buf.len >= 3);
    if (std.fmt.bufPrint(buf, fmt, args)) |t| return t else |_| {}
    buf[buf.len - 1] = '.';
    buf[buf.len - 2] = '.';
    buf[buf.len - 3] = '.';
    return buf;
}

fn x11Visual(screen_index: u8, depth: u8, visual_index: u16, visual: *const zin.X11VisualType) void {
    std.log.info(
        "X11 Visual screen[{}] depth {} visual[{}] id={} class={f} bits-per-ch={} map_cnt={} red=0x{x} grn=0x{x} blu=0x{x}",
        .{
            screen_index,
            depth,
            visual_index,
            @intFromEnum(visual.id),
            zin.fmtEnum(visual.class),
            visual.bits_per_rgb_value,
            visual.colormap_entries,
            visual.red_mask,
            visual.green_mask,
            visual.blue_mask,
        },
    );
}
fn x11UnhandledReply(flex: u8, seq: u16, words: u32) error{ X11Protocol, ReadFailed, EndOfStream }!void {
    std.log.err("not handling x11 reply (flex={}, seq={}, {} words)", .{ flex, seq, words });
}

// const Icons = struct {
//     small: zin.MaybeWin32Icon,
//     large: zin.MaybeWin32Icon,
// };
// fn getIcons(dpi_x: u32, dpi_y: u32) Icons {
//     if (builtin.os.tag == .windows) {
//         const small_x = win32.GetSystemMetricsForDpi(@intFromEnum(win32.SM_CXSMICON), dpi_x);
//         const small_y = win32.GetSystemMetricsForDpi(@intFromEnum(win32.SM_CYSMICON), dpi_y);
//         const large_x = win32.GetSystemMetricsForDpi(@intFromEnum(win32.SM_CXICON), dpi_x);
//         const large_y = win32.GetSystemMetricsForDpi(@intFromEnum(win32.SM_CYICON), dpi_y);
//         std.log.info("icons small={}x{} large={}x{} at dpi {}x{}", .{
//             small_x, small_y,
//             large_x, large_y,
//             dpi_x,   dpi_y,
//         });
//         const small = win32.LoadImageW(
//             win32.GetModuleHandleW(null),
//             @ptrFromInt(1), // resource id
//             .ICON,
//             small_x,
//             small_y,
//             win32.LR_SHARED,
//         );
//         if (small == null)
//             std.debug.panic("LoadImage for small icon failed, error={f}", .{win32.GetLastError()});
//         const large = win32.LoadImageW(
//             win32.GetModuleHandleW(null),
//             @ptrFromInt(1), // resource id
//             .ICON,
//             large_x,
//             large_y,
//             win32.LR_SHARED,
//         );
//         if (large == null)
//             std.debug.panic("LoadImage for large icon failed, error={f}", .{win32.GetLastError()});
//         return .{
//             .small = .init(@ptrCast(small)),
//             .large = .init(@ptrCast(large)),
//         };
//     }
//     return .{ .small = .none, .large = .none };
// }

const builtin = @import("builtin");
const std = @import("std");
const zin = @import("zin");
const win32 = zin.platform.win32;

const midi = @import("midi.zig");
const mmsystem = @import("mmsystem.zig");
