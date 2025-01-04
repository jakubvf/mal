const std = @import("std");

pub const Value = union(enum) {
    list: List,
    number: Number,
    symbol: []const u8,

    pub fn format(
        value: *Value,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        switch (value.*) {
            .list => |l| {
                _ = try writer.writeAll("(");
                for (l.items, 0..) |v, i| {
                    try writer.print("{}", .{v});
                    if (i < l.items.len - 1) try writer.writeAll(" ");
                }
                _ = try writer.writeAll(")");
            },
            .number => |n| {
                try writer.print("{d}", .{n});
            },
            .symbol => |s| {
                try writer.print("{s}", .{s});
            },
        }
    }
};

pub const Number = i64;
pub const List = std.ArrayList(*Value);
