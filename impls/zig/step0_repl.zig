const std = @import("std");
const readline = @cImport(@cInclude("readline/readline.h"));

/// Result should be freed
pub fn READ(str: []const u8) []const u8 {
    return str;
}

pub fn EVAL(str: []const u8) []const u8 {
    return str;
}

pub fn PRINT(str: []const u8) []const u8 {
    return str;
}

pub fn rep(str: []const u8) []const u8 {
    const result = PRINT(EVAL(READ(str)));
    return result;
}

pub fn main() !void {
    while (readline.readline("user> ")) |input| {
        const span = std.mem.span(input);
        const result = rep(span);
        const stdout = std.io.getStdOut();

        try stdout.writeAll(result);
        try stdout.writeAll("\n");
        std.heap.raw_c_allocator.free(result);
    }
}
