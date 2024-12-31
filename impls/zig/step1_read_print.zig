const std = @import("std");
const readline = @cImport(@cInclude("readline/readline.h"));

const Tokenizer = @import("reader.zig").Tokenizer;

/// Result should be freed
pub fn READ(str: []const u8) ![]const u8 {
    var tokenizer = Tokenizer{
        .input = str,
        .index = 0,
    };

    while (try tokenizer.next()) |token| {
        std.debug.print("[{s}]\n", .{token});
    }

    return str;
}

pub fn EVAL(str: []const u8) []const u8 {
    return str;
}

pub fn PRINT(str: []const u8) []const u8 {
    return str;
}

pub fn rep(str: []const u8) ![]const u8 {
    const result = PRINT(EVAL(try READ(str)));
    return result;
}

pub fn main() !void {
    const stdout = std.io.getStdOut();
    const stderr = std.io.getStdErr();

    while (readline.readline("user> ")) |input| {
        const span = std.mem.span(input);
        const result = rep(span) catch |err| switch (err) {
            error.Eof => {
                try stderr.writeAll("unexpected EOF\n");
                continue;
            },
            else => return err,
        };

        try stdout.writeAll(result);
        try stdout.writeAll("\n");
        std.heap.raw_c_allocator.free(result);
    }
}
