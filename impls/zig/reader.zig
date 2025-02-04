const std = @import("std");
const Allocator = std.mem.Allocator;

const Value = @import("types.zig").Value;
const Number = @import("types.zig").Number;
const Vector = @import("types.zig").Vector;
const List = @import("types.zig").List;
const HashMap = @import("types.zig").HashMap;

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
        '[' => try readVector(allocator, r),
        '{' => try readHashMap(allocator, r),
        '\'', '`', '~', '@' => try readSyntacticSugar(allocator, r),
        else => try readAtom(allocator, r),
    };
}

fn readList(allocator: Allocator, r: *Reader) ReaderError!?*Value {
    var result = try allocator.create(Value);
    result.* = Value{ .list = List.init(allocator) };

    _ = r.next(); // eat (

    while (r.peek()) |token| {
        if (token[0] == ')') {
            _ = r.next(); // eat )
            return result;
        }

        try result.list.append(
            try readForm(allocator, r) orelse @panic("fix me"), // is this stupid???
        );
    }

    return error.UnexpectedEof;
}

fn readVector(allocator: Allocator, r: *Reader) ReaderError!?*Value {
    var result = try allocator.create(Value);
    result.* = Value{ .vector = Vector.init(allocator) };

    _ = r.next(); // eat [

    while (r.peek()) |token| {
        if (token[0] == ']') {
            _ = r.next(); // eat ]
            return result;
        }

        try result.vector.append(
            try readForm(allocator, r) orelse @panic("fix me"), // is this stupid???
        );
    }

    return error.UnexpectedEof;
}

fn readHashMap(allocator: Allocator, r: *Reader) ReaderError!?*Value {
    var result = try allocator.create(Value);
    result.* = Value{ .hash_map = HashMap.init(allocator) };

    _ = r.next(); // eat {

    while (r.peek()) |token| {
        if (token[0] == '}') {
            _ = r.next(); // eat }
            return result;
        }

        try result.hash_map.put(try readForm(allocator, r) orelse @panic("fix me"), try readForm(allocator, r) orelse @panic("fix me"));
    }

    return error.UnexpectedEof;
}

fn readSyntacticSugar(allocator: Allocator, r: *Reader) ReaderError!?*Value {
    const sugar = r.next().?;

    const result = try allocator.create(Value);
    result.* = Value{ .list = List.init(allocator) };

    const first_val = try allocator.create(Value);
    first_val.* = Value{ .symbol = try allocator.dupe(u8, switch (sugar[0]) {
        '\'' => "quote",
        '`' => "quasiquote",
        '~' => if (sugar.len == 1) "unquote" else "splice-unquote",
        '@' => "deref",
        else => @panic("fix me"),
    }) };
    try result.list.append(first_val);

    try result.list.append(try readForm(allocator, r) orelse @panic("fix me"));

    return result;
}

fn readAtom(allocator: Allocator, r: *Reader) ReaderError!?*Value {
    const token = r.next() orelse return null;

    const result = try allocator.create(Value);

    if (std.ascii.isDigit(token[0]) or (token[0] == '-' or token[0] == '+') and token.len > 1) {
        const number = try std.fmt.parseInt(Number, token, 10);
        result.* = Value{ .number = number };
    } else {
        result.* = Value{ .symbol = try allocator.dupe(u8, token) };
    }

    return result;
}

const debug_tokens = false;
pub fn tokenize(allocator: Allocator, input: []const u8) ReaderError![]const []const u8 {
    var buffer = std.ArrayList([]const u8).init(allocator);

    var tokenizer = Tokenizer{
        .input = input,
    };

    while (try tokenizer.next()) |token| {
        if (debug_tokens) {
            std.debug.print("{s}\n", .{token});
        }
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
                                t.index += 1;
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
                    return t.input[start..t.index];
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
