const std = @import("std");



pub fn READ(read_buffer: []u8) ![]const u8 {
    const in = std.io.getStdIn();

    _ = PRINT("\nuser> ") catch @panic("Hell let lose");
    return try in.reader().readUntilDelimiter(read_buffer, '\n');
}

pub fn EVAL(str: []const u8) []const u8 {
    return str;
}

pub fn PRINT(str: []const u8) ![]const u8 {
    const out = std.io.getStdOut();
    try out.writeAll(str);
    return str;
}

pub fn rep() !void {
    const read_buffer_size = 1024;

    var read_buffer: [read_buffer_size]u8 = [_]u8{0} ** read_buffer_size;
    _ = try PRINT(EVAL(try READ(&read_buffer)));
}

pub fn main() !void {
    while (true) {
        try rep();
    }
}
