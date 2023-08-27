const std = @import("std");
const stdext = @import("../stdext.zig");

// TODO: this should be in the standard library
pub fn LimitArray(comptime T : type) type {
    return struct {
        ptr : [*]T,
        limit : [*]T,

        pub fn init(ptr: [*]T, limit: [*]T) @This() {
            return @This() {
                .ptr = ptr,
                .limit = limit,
            };
        }
        pub fn fromArray(array: []T) @This() {
            return @This() {
                .ptr = array.ptr,
                .limit = array.ptr + array.len,
            };
        }
        pub fn toArray(self: @This()) []T {
            return self.ptr[0 .. (@intFromPtr(self.limit) - @intFromPtr(self.ptr)) / @sizeOf(T)];
        }
        pub fn empty(self: *const @This()) bool { return self.ptr == self.limit; }
        pub fn popFront(self: *@This(), count: usize) void {
            const newPtr = self.ptr + count;
            std.debug.assert(@intFromPtr(newPtr) <= @intFromPtr(self.limit));
            self.ptr = newPtr;
        }
    };
}

pub fn ptrLessThan(left: anytype, right: anytype) bool {
    return @intFromPtr(left) < @intFromPtr(right);
}

pub fn limitPointersToSlice(ptr: anytype, limit: anytype) stdext.meta.SliceType(@TypeOf(ptr)) {
    return ptr[0 .. (@intFromPtr(limit) - @intFromPtr(ptr)) / @sizeOf(@typeInfo(@TypeOf(ptr)).Pointer.child)];
}
