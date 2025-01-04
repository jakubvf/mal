const std = @import("std");

const Value = @import("types.zig").Value;
const Number = @import("types.zig").Number;
const List = @import("types.zig").List;

pub fn printString(allocator: std.mem.Allocator, value: *Value) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{}", .{value});
}
