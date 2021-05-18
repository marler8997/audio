pub const log = @import("./audio/log.zig");
pub const global = @import("./audio/global.zig");
pub const renderformat = @import("./audio/renderformat.zig");
pub const backend = @import("./audio/backend.zig");
pub const render = @import("./audio/render.zig");
pub const dag = @import("./audio/dag.zig");
pub const midi = @import("./audio/midi.zig");
pub const oscillators = @import("./audio/oscillators.zig");
pub const pckeyboard = @import("./audio/pckeyboard.zig");

const builtin = @import("builtin");

const windowsmidi = @import("./audio/windowsmidi.zig");
const linuxmidi = @import("./audio/linuxmidi.zig");
pub const osmidi = switch (builtin.os.tag) {
    .windows => windowsmidi,
    .linux => linuxmidi,
    else => struct {},
};

const windowsinput = @import("./audio/windowsinput.zig");
const posixinput = @import("./audio/posixinput.zig");
pub const osinput = switch (builtin.os.tag) {
    .windows => windowsinput,
    else => posixinput,
};
