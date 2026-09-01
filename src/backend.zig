const std = @import("std");
const builtin = @import("builtin");
const c = @cImport({
    @cInclude("time.h");
});

pub const PluginRegistry = @import("backend/plugin.zig").PluginRegistry;

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

/// Parses the one integer argument accepted by the increment RPC method.
pub fn parseIncrementArgs(args: []const u8, allocator: std.mem.Allocator) !i64 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, args, .{}) catch {
        return error.InvalidArgument;
    };
    defer parsed.deinit();

    const values = switch (parsed.value) {
        .array => |array| array.items,
        else => return error.InvalidArgument,
    };
    if (values.len != 1) return error.InvalidArgument;

    return switch (values[0]) {
        .integer => |value| value,
        else => error.InvalidArgument,
    };
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
    try std.testing.expectEqual(@as(i64, -12), try parseIncrementArgs(" \n [ -12 ] \n", allocator));
    try std.testing.expectError(error.InvalidArgument, parseIncrementArgs("[]", allocator));
    try std.testing.expectError(error.InvalidArgument, parseIncrementArgs("[1, 2]", allocator));
    try std.testing.expectError(error.InvalidArgument, parseIncrementArgs("[\"1\"]", allocator));
    try std.testing.expectError(error.InvalidArgument, parseIncrementArgs("[1.5]", allocator));
    try std.testing.expectError(error.InvalidArgument, parseIncrementArgs("[true]", allocator));
    try std.testing.expectError(error.InvalidArgument, parseIncrementArgs("[null]", allocator));
    try std.testing.expectError(error.InvalidArgument, parseIncrementArgs("[{}]", allocator));
    try std.testing.expectError(error.InvalidArgument, parseIncrementArgs("[1] trailing", allocator));
    try std.testing.expectError(error.InvalidArgument, parseIncrementArgs("invalid", allocator));
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
