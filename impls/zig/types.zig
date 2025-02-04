const std = @import("std");

pub const Value = union(enum) {
    number: Number,
    list: List,
    vector: Vector,
    native_func: NativeFunc,
    hash_map: HashMap,
    symbol: []const u8,
    nil: Nil,

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
            .vector => |l| {
                _ = try writer.writeAll("[");
                for (l.items, 0..) |v, i| {
                    try writer.print("{}", .{v});
                    if (i < l.items.len - 1) try writer.writeAll(" ");
                }
                _ = try writer.writeAll("]");
            },
            .native_func => |f| {
                try writer.print("{p}", .{f});
            },
            .hash_map => |h| {
                _ = try writer.writeAll("{");
                var i = h.iterator();
                var counter: usize = 0;
                while (i.next()) |entry| {
                    try writer.print("{} {}", .{ entry.key_ptr.*, entry.value_ptr.* });
                    if (counter < h.count() - 1) {
                        try writer.writeAll(" ");
                    }

                    counter += 1;
                }
                _ = try writer.writeAll("}");
            },
            .number => |n| {
                try writer.print("{d}", .{n});
            },
            .symbol => |s| {
                try writer.print("{s}", .{s});
            },
            .nil => {
                try writer.print("nil", .{});
            },
        }
    }
};

pub const Nil = void;
pub const Number = i64;
pub const List = Vector; // Maybe use std.SinglyLinkedList(*Value)?
pub const Vector = std.ArrayList(*Value);
pub const NativeFunc = *const fn (std.mem.Allocator, []*Value) *Value;
pub const HashMap = std.HashMap(
    *Value,
    *Value,
    ValueHashMapContext,
    std.hash_map.default_max_load_percentage,
);
const ValueHashMapContext = struct {
    pub fn hash(self: @This(), v: *Value) u64 {
        _ = self;
        // yes very dirty I know (all of it)
        const printed = std.fmt.allocPrint(std.heap.c_allocator, "{}", .{v}) catch @panic("bruh");
        defer std.heap.c_allocator.free(printed);

        return std.hash.Wyhash.hash(0, printed);
    }
    pub fn eql(self: @This(), a: *Value, b: *Value) bool {
        _ = self;

        const printed_a = std.fmt.allocPrint(std.heap.c_allocator, "{}", .{a}) catch @panic("bruh");
        defer std.heap.c_allocator.free(printed_a);

        const printed_b = std.fmt.allocPrint(std.heap.c_allocator, "{}", .{b}) catch @panic("bruh");
        defer std.heap.c_allocator.free(printed_b);

        return std.mem.eql(u8, printed_a, printed_b);
    }
};
