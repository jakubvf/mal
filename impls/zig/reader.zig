const std = @import("std");
const Allocator = std.mem.Allocator;

const Value = @import("types.zig").Value;
const Number = @import("types.zig").Number;
const List = @import("types.zig").List;

pub const ReaderError = error{UnexpectedEof} || Allocator.Error || std.fmt.ParseIntError;

pub fn readString(allocator: Allocator, input: []const u8) ReaderError!?*Value {
    const tokens = try tokenize(allocator, input);
    var reader = Reader{
        .tokens = tokens,
    };
    return try readForm(allocator, &reader);
}

fn readForm(allocator: Allocator, r: *Reader) ReaderError!?*Value {
    const token = r.peek() orelse return null;

    return switch (token[0]) {
        '(' => try readList(allocator, r),
        else => try readAtom(allocator, r),
    };
}

fn readList(allocator: Allocator, r: *Reader) ReaderError!?*Value {
    var result = try allocator.create(Value);
    result.* = Value{ .list = List.init(allocator) };

    _ = r.next(); // eat (

    std.debug.print("readList\n", .{});

    var token = r.peek();
    while (token != null and token.?[0] != ')') {
        try result.list.append(
            try readForm(allocator, r) orelse return null, // is this stupid???
        );
        token = r.peek();
    }
    _ = r.next(); // eat )

    return result;
}

fn readAtom(allocator: Allocator, r: *Reader) ReaderError!?*Value {
    const token = r.next() orelse return null;

    const result = try allocator.create(Value);

    std.debug.print("atom\n", .{});

    if (std.ascii.isDigit(token[0])) {
        const number = try std.fmt.parseInt(Number, token, 10);
        result.* = Value{ .number = number };
    } else {
        result.* = Value{ .symbol = try allocator.dupe(u8, token) };
    }

    return result;
}

pub fn tokenize(allocator: Allocator, input: []const u8) ReaderError![]const []const u8 {
    var buffer = std.ArrayList([]const u8).init(allocator);

    var tokenizer = Tokenizer{
        .input = input,
    };

    while (try tokenizer.next()) |token| {
        try buffer.append(token);
    }

    return buffer.toOwnedSlice();
}

const Reader = struct {
    tokens: []const []const u8,
    index: usize = 0,

    pub fn next(r: *Reader) ?[]const u8 {
        if (r.index < r.tokens.len) {
            defer r.index += 1;
            return r.tokens[r.index];
        } else return null;
    }

    pub fn peek(r: *Reader) ?[]const u8 {
        if (r.index < r.tokens.len) {
            return r.tokens[r.index];
        } else return null;
    }
};

pub const Tokenizer = struct {
    input: []const u8,
    index: usize = 0,

    pub fn next(t: *Tokenizer) !?[]const u8 {
        while (t.index < t.input.len) : (t.index += 1) {
            const c = t.input[t.index];

            switch (c) {
                ' ', '\t', '\n', ',' => {},
                '~' => {
                    defer t.index += 1;
                    if (t.index + 1 < t.input.len and t.input[t.index + 1] == '@') {
                        defer t.index += 1; // +1 because (t.index += 1) in while loop won't run because of the return
                        return t.input[t.index .. t.index + 2];
                    }
                    return t.input[t.index .. t.index + 1];
                },
                '[', ']', '{', '}', '(', ')', '\'', '`', '^', '@' => {
                    defer t.index += 1;
                    return t.input[t.index .. t.index + 1];
                },
                '"' => {
                    const start = t.index;
                    t.index += 1;
                    while (t.index < t.input.len) {
                        defer t.index += 1; // shift the index even when we hit a return

                        const d = t.input[t.index];
                        switch (d) {
                            '"' => return t.input[start .. t.index + 1],
                            '\\' => {
                                t.index += 2;
                            },
                            else => {},
                        }
                    }
                    return error.UnexpectedEof;
                },
                ';' => {
                    const start = t.index;
                    while (t.index < t.input.len) : (t.index += 1) {
                        const d = t.input[t.index];
                        if (d == '\n')
                            break;
                    }
                    return t.input[start .. t.index + 1];
                },
                else => {
                    const start = t.index;
                    var done = false;
                    while (!done and t.index < t.input.len) {
                        const d = t.input[t.index];
                        switch (d) {
                            ' ', '\t', '\n', '[', ']', '{', '}', '(', ')', '\'', '"', '`', ',', ';' => done = true,
                            else => t.index += 1,
                        }
                    }
                    return t.input[start..t.index];
                },
            }
        }

        return null;
    }
};
