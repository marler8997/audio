const std = @import("std");
const backend = @import("./backend.zig");

//
// Audio Settings
//
pub var channelCount : u8 = undefined;
pub var sampleFramesPerSec : u32 = undefined;
pub var bufferSampleFrameCount : u32 = undefined;
pub var backendFuncs : *const backend.BackendFuncs = undefined;

//
// Other Globals
//
var arenaDirectAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
pub const allocator = arenaDirectAllocator.allocator();
