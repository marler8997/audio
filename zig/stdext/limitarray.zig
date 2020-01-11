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
            return self.ptr[0 .. (@ptrToInt(self.limit) - @ptrToInt(self.ptr)) / @sizeOf(T)];
        }
        pub fn empty(self: *const @This()) bool { return self.ptr == self.limit; }
        pub fn popFront(self: *@This(), count: usize) void {
            const newPtr = self.ptr + count;
            std.debug.assert(@ptrToInt(newPtr) <= @ptrToInt(self.limit));
            self.ptr = newPtr;
        }
    };
}

pub fn ptrLessThan(left: var, right: var) bool {
    return @ptrToInt(left) < @ptrToInt(right);
}

pub fn limitPointersToSlice(ptr: var, limit: var) stdext.meta.SliceType(@TypeOf(ptr)) {
    return ptr[0 .. (@ptrToInt(limit) - @ptrToInt(ptr)) / @sizeOf(@TypeOf(ptr).Child)];
}
