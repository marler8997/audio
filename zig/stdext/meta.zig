const builtin = @import("builtin");
const TypeId = builtin.TypeId;

/// Given an array/pointer type, return the slice type `[]Child`. Preserves `const`.
pub fn SliceType(comptime T: type) type {
    return switch (@typeInfo(T)) {
        TypeId.Array => |info| []const info.child,
        TypeId.Pointer => |info| if (info.is_const) []const info.child else []info.child,
        else => @compileError("Expected pointer or array type, " ++ "found '" ++ @typeName(T) ++ "'"),
    };
}

/// Given an array/pointer type, return the "array pointer" type `[*]Child`. Preserves `const`.
pub fn ArrayPointerType(comptime T: type) type {
    return switch (@typeInfo(T)) {
        TypeId.Array => |info| [*]const info.child,
        TypeId.Pointer => |info| if (info.is_const) [*]const info.child else [*]info.child,
        else => @compileError("Expected pointer or array type, " ++ "found '" ++ @typeName(T) ++ "'"),
    };
}
