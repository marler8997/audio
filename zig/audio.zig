pub const global = @import("./audio/global.zig");
pub const renderformat = @import("./audio/renderformat.zig");
pub const backend = @import("./audio/backend.zig");
pub const render = @import("./audio/render.zig");
pub const dag = @import("./audio/dag.zig");
pub const midi = @import("./audio/midi.zig");
pub const oscillators = @import("./audio/oscillators.zig");
pub const pckeyboard = @import("./audio/pckeyboard.zig");

const builtin = @import("builtin");

pub const windows = @import("audio/windows.zig");

const windowsinput = @import("./audio/windowsinput.zig");
const posixinput = @import("./audio/posixinput.zig");
pub const osinput = switch (builtin.os.tag) {
    .windows => windowsinput,
    else => posixinput,
};
