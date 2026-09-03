const std = @import("std");
const builtin = @import("builtin");
const c = @cImport({
    @cInclude("time.h");
});

pub const PluginRegistry = @import("backend/plugin.zig").PluginRegistry;
pub const Log = @import("backend/log.zig");

pub const State = struct {
    count: i64 = 0,

    pub fn increment(self: *State, delta: i64) i64 {
        self.count += delta;
        return self.count;
    }

    pub fn reset(self: *State) i64 {
        self.count = 0;
        return self.count;
    }
};

/// Typed validation failures for the increment RPC method, so the frontend
/// can distinguish malformed calls instead of receiving one opaque error.
pub const IncrementParseError = error{
    MalformedJson,
    NotArgumentArray,
    WrongArgumentCount,
    NonIntegerArgument,
};

/// Parses the one integer argument accepted by the increment RPC method.
pub fn parseIncrementArgs(args: []const u8, allocator: std.mem.Allocator) IncrementParseError!i64 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, args, .{}) catch {
        return error.MalformedJson;
    };
    defer parsed.deinit();

    const values = switch (parsed.value) {
        .array => |array| array.items,
        else => return error.NotArgumentArray,
    };
    if (values.len != 1) return error.WrongArgumentCount;

    return switch (values[0]) {
        .integer => |value| value,
        else => error.NonIntegerArgument,
    };
}

/// Human-readable detail for each increment validation failure.
/// Messages avoid double quotes so they embed safely in the error envelope.
pub fn incrementErrorMessage(err: IncrementParseError) [:0]const u8 {
    return switch (err) {
        error.MalformedJson => "arguments must be JSON, e.g. [1]",
        error.NotArgumentArray => "arguments must be a JSON array, e.g. [1]",
        error.WrongArgumentCount => "increment takes exactly one argument, e.g. [1]",
        error.NonIntegerArgument => "increment delta must be an integer, e.g. [1]",
    };
}

/// Rejects an RPC request with a structured JSON envelope:
/// {"code":"<PascalCaseCode>","message":"<human detail>"}.
/// Codes are stable tokens for frontend switching; messages are for display.
/// `message` must not contain double quotes (all built-in messages satisfy this).
pub fn rejectWithCode(req: anytype, code: []const u8, message: []const u8) void {
    var buf: [256]u8 = undefined;
    const payload = std.fmt.bufPrintZ(
        &buf,
        "{{\"code\":\"{s}\",\"message\":\"{s}\"}}",
        .{ code, message },
    ) catch {
        req.rejectError(error.EnvelopeTooLarge);
        return;
    };
    req.reject(payload);
}

pub fn systemInfo() [:0]const u8 {
    return switch (builtin.os.tag) {
        .linux => "Linux",
        .macos => "macOS",
        .windows => "Windows",
        else => "Unknown",
    };
}

pub fn timestamp() i64 {
    return @intCast(c.time(null));
}

pub fn formatTimestamp(buffer: []u8, value: i64) ![:0]u8 {
    return std.fmt.bufPrintSentinel(buffer, "{d}", .{value}, 0);
}

/// Health/status payload for frontend startup checks.
/// Mirrors the webview-app-with-vlang health-check idea (`get_time`).
/// Returns a plain status token, consistent with `systemInfo()`.
pub fn healthStatus() [:0]const u8 {
    return "ok";
}

/// Structured status payload for richer startup checks.
pub fn statusPayload() [:0]const u8 {
    return "{\"status\":\"ok\",\"backend\":\"zig\"}";
}

test "state increments and resets" {
    var state: State = .{};

    try std.testing.expectEqual(@as(i64, 0), state.count);
    try std.testing.expectEqual(@as(i64, 3), state.increment(3));
    try std.testing.expectEqual(@as(i64, 1), state.increment(-2));
    try std.testing.expectEqual(@as(i64, 0), state.reset());
}

test "increment arguments require one integer" {
    const allocator = std.testing.allocator;

    try std.testing.expectEqual(@as(i64, 5), try parseIncrementArgs("[5]", allocator));
    try std.testing.expectEqual(
        @as(i64, -12),
        try parseIncrementArgs(" \n [ -12 ] \n", allocator),
    );
    try std.testing.expectError(
        error.WrongArgumentCount,
        parseIncrementArgs("[]", allocator),
    );
    try std.testing.expectError(
        error.WrongArgumentCount,
        parseIncrementArgs("[1, 2]", allocator),
    );
    try std.testing.expectError(
        error.NonIntegerArgument,
        parseIncrementArgs("[\"1\"]", allocator),
    );
    try std.testing.expectError(
        error.NonIntegerArgument,
        parseIncrementArgs("[1.5]", allocator),
    );
    try std.testing.expectError(
        error.NonIntegerArgument,
        parseIncrementArgs("[true]", allocator),
    );
    try std.testing.expectError(
        error.NonIntegerArgument,
        parseIncrementArgs("[null]", allocator),
    );
    try std.testing.expectError(
        error.NonIntegerArgument,
        parseIncrementArgs("[{}]", allocator),
    );
    try std.testing.expectError(
        error.MalformedJson,
        parseIncrementArgs("[1] trailing", allocator),
    );
    try std.testing.expectError(
        error.MalformedJson,
        parseIncrementArgs("invalid", allocator),
    );
    try std.testing.expectError(
        error.NotArgumentArray,
        parseIncrementArgs("{\"delta\": 1}", allocator),
    );
}

test "increment failures carry distinct human-readable messages" {
    try std.testing.expectEqualStrings(
        "arguments must be JSON, e.g. [1]",
        incrementErrorMessage(error.MalformedJson),
    );
    try std.testing.expectEqualStrings(
        "arguments must be a JSON array, e.g. [1]",
        incrementErrorMessage(error.NotArgumentArray),
    );
    try std.testing.expectEqualStrings(
        "increment takes exactly one argument, e.g. [1]",
        incrementErrorMessage(error.WrongArgumentCount),
    );
    try std.testing.expectEqualStrings(
        "increment delta must be an integer, e.g. [1]",
        incrementErrorMessage(error.NonIntegerArgument),
    );
}

test "rejections use a stable JSON envelope" {
    // Note: the envelope borrows the helper's stack buffer and is only
    // valid for synchronous use (as with the real webview `reject`), so
    // the fake copies it into its own storage like a real bridge would.
    const FakeReq = struct {
        storage: [256]u8 = undefined,
        rejected: ?[]const u8 = null,
        failed: ?anyerror = null,

        pub fn reject(self: *@This(), payload: [:0]const u8) void {
            @memcpy(self.storage[0..payload.len], payload);
            self.rejected = self.storage[0..payload.len];
        }

        pub fn rejectError(self: *@This(), err: anyerror) void {
            self.failed = err;
        }
    };

    var req: FakeReq = .{};
    rejectWithCode(&req, "MalformedJson", "arguments must be JSON, e.g. [1]");
    try std.testing.expectEqualStrings(
        "{\"code\":\"MalformedJson\",\"message\":\"arguments must be JSON, e.g. [1]\"}",
        req.rejected.?,
    );
    try std.testing.expect(req.failed == null);
}

test "platform and timestamp are available" {
    try std.testing.expect(systemInfo().len > 0);
    try std.testing.expect(timestamp() > 0);

    var buffer: [32]u8 = undefined;
    try std.testing.expectEqualStrings("1700000000", try formatTimestamp(&buffer, 1700000000));
    try std.testing.expectEqualStrings("-42", try formatTimestamp(&buffer, -42));

    var small_buffer: [4]u8 = undefined;
    try std.testing.expectError(error.NoSpaceLeft, formatTimestamp(&small_buffer, 1700000000));
}

test "health status reports ok" {
    try std.testing.expectEqualStrings("ok", healthStatus());
    try std.testing.expectEqualStrings("{\"status\":\"ok\",\"backend\":\"zig\"}", statusPayload());
}
