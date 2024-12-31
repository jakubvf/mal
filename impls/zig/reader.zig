const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Tokenizer = struct {
    input: []const u8,
    index: usize,

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
                    return error.Eof;
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

// const Value = usize;
// pub fn readString(allocator: Allocator, input: []const u8) !*Value {}
