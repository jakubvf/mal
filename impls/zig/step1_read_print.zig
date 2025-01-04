const std = @import("std");
const readline = @cImport(@cInclude("readline/readline.h"));

const reader = @import("reader.zig");
const printer = @import("printer.zig");

const Value = @import("types.zig").Value;

/// Result should be freed
pub fn READ(allocator: std.mem.Allocator, str: []const u8) reader.ReaderError!?*Value {
    return reader.readString(allocator, str);
}

pub fn EVAL(allocator: std.mem.Allocator, value: *Value) !*Value {
    _ = allocator;
    return value;
}

pub fn PRINT(allocator: std.mem.Allocator, value: *Value) ![]const u8 {
    return try printer.printString(allocator, value);
}

pub fn rep(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
    if (try READ(allocator, str)) |read| {
        const result = try PRINT(allocator, try EVAL(allocator, read));
        return result;
    } else return "";
}

pub fn main() !void {
    const stdout = std.io.getStdOut();
    const stderr = std.io.getStdErr();

    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    const allocator = arena.allocator();

    while (readline.readline("user> ")) |input| {
        defer _ = arena.reset(.retain_capacity);

        const result = rep(
            allocator,
            std.mem.span(input),
        ) catch |err| switch (err) {
            error.UnexpectedEof => {
                try stderr.writeAll("unexpected EOF\n");
                continue;
            },
            else => return err,
        };

        try stdout.writeAll(result);
        try stdout.writeAll("\n");
    }
}
