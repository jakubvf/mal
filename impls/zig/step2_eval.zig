const std = @import("std");
const readline = @cImport(@cInclude("readline/readline.h"));

const reader = @import("reader.zig");
const printer = @import("printer.zig");

const types = @import("types.zig");
const Value = types.Value;
const HashMap = types.HashMap;

const Env = std.StringHashMap(Value);

/// Result should be freed
pub fn READ(allocator: std.mem.Allocator, str: []const u8) reader.ReaderError!?*Value {
    return reader.readString(allocator, str);
}

pub const EvalError = error{ NotFound, UnexpectedEof, OutOfMemory };
fn evalAst(allocator: std.mem.Allocator, value: *Value, env: *Env) EvalError!*Value {
    switch (value.*) {
        .symbol => |s| {
            if (env.get(s)) |_| {
                return value;
            } else {
                return error.NotFound;
            }
        },
        .list => |l| {
            const result = try allocator.create(Value);
            result.* = Value{ .list = std.ArrayList(*Value).init(allocator) };
            for (l.items) |item| {
                try result.list.append(try EVAL(allocator, item, env));
            }
            return result;
        },
        .vector => |v| {
            const result = try allocator.create(Value);
            result.* = Value{ .vector = std.ArrayList(*Value).init(allocator) };
            for (v.items) |item| {
                try result.vector.append(try EVAL(allocator, item, env));
            }
            return result;
        },
        .hash_map => |hm| {
            const result = try allocator.create(Value);
            result.* = Value{ .hash_map = HashMap.init(allocator) };
            var i = hm.iterator();
            while (i.next()) |entry| {
                try result.hash_map.put(entry.key_ptr.*, try EVAL(allocator, entry.value_ptr.*, env));
            }
            return result;
        },
        else => {
            return value;
        },
    }
}

pub fn EVAL(allocator: std.mem.Allocator, value: *Value, env: *Env) EvalError!*Value {
    switch (value.*) {
        else => return evalAst(allocator, value, env),
        .list => |list| {
            if (list.items.len == 0) return value;

            switch (list.items[0].*) {
                .symbol => |s| {
                    // if (std.mem.eql(u8, s, "quote")) {
                    //     return list.items[1];
                    // }
                    var params = std.ArrayList(*Value).init(allocator);
                    for (list.items[1..]) |item| {
                        const p = EVAL(allocator, item, env) catch @panic("could not evaluate param");
                        try params.append(p);
                    }

                    if (env.get(s)) |mby_func| {
                        switch (mby_func) {
                            .native_func => |func| {
                                return func(allocator, params.items);
                            },
                            else => return error.NotFound,
                        }
                    } else {
                        return error.NotFound;
                    }
                },
                else => {
                    @panic("tis ting not a function bruh");
                    // return error.NotFound;
                },
            }
        },
    }
}

pub fn PRINT(allocator: std.mem.Allocator, value: *Value) ![]const u8 {
    return try printer.printString(allocator, value);
}

pub fn rep(allocator: std.mem.Allocator, str: []const u8, env: *Env) ![]const u8 {
    if (try READ(allocator, str)) |read| {
        const result = try PRINT(allocator, try EVAL(allocator, read, env));
        return result;
    } else return "";
}

const basic_funcs = struct {
    pub fn add(allocator: std.mem.Allocator, args: []*Value) *Value {
        var sum: i64 = 0;
        for (args) |arg| {
            sum += arg.number;
        }
        const result = allocator.create(Value) catch {
            @panic("failed to allocate Value");
        };
        result.* = Value{ .number = sum };
        return result;
    }

    pub fn sub(allocator: std.mem.Allocator, args: []*Value) *Value {
        var sum: i64 = args[0].number;
        for (args[1..]) |arg| {
            sum -= arg.number;
        }
        const result = allocator.create(Value) catch {
            @panic("failed to allocate Value");
        };
        result.* = Value{ .number = sum };
        return result;
    }

    pub fn mul(allocator: std.mem.Allocator, args: []*Value) *Value {
        var sum: i64 = 1;
        for (args) |arg| {
            sum *= arg.number;
        }
        const result = allocator.create(Value) catch {
            @panic("failed to allocate Value");
        };
        result.* = Value{ .number = sum };
        return result;
    }

    pub fn div(allocator: std.mem.Allocator, args: []*Value) *Value {
        var sum: i64 = args[0].number;
        for (args[1..]) |arg| {
            sum = @divTrunc(sum, arg.number);
        }
        const result = allocator.create(Value) catch {
            @panic("failed to allocate Value");
        };
        result.* = Value{ .number = sum };
        return result;
    }
};

pub fn main() !void {
    const stdout = std.io.getStdOut();
    const stderr = std.io.getStdErr();

    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    const allocator = arena.allocator();

    var env = Env.init(std.heap.c_allocator);
    try env.put("+", Value{ .native_func = &basic_funcs.add });
    try env.put("-", Value{ .native_func = &basic_funcs.sub });
    try env.put("*", Value{ .native_func = &basic_funcs.mul });
    try env.put("/", Value{ .native_func = &basic_funcs.div });
    try env.put("nil", Value.nil);

    while (readline.readline("user> ")) |input| {
        defer _ = arena.reset(.retain_capacity);

        const result = rep(
            allocator,
            std.mem.span(input),
            &env,
        ) catch |err| switch (err) {
            error.NotFound => {
                try stderr.writeAll("not found\n");
                continue;
            },
            error.UnexpectedEof => {
                try stderr.writeAll("EOF\n");
                continue;
            },
            else => return err,
        };

        try stdout.writeAll(result);
        try stdout.writeAll("\n");
    }
}
