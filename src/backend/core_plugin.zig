/// Registers the host and window RPCs currently provided by the default
/// backend. New feature plugins can expose their own register() function
/// without changing the application entry point.
pub fn register(comptime Easy: type) *const fn (*Easy) anyerror!void {
    const CorePlugin = struct {
        fn bind(easy: *Easy) !void {
            try easy.bind(.increment);
            try easy.bind(.reset);
            try easy.bind(.getSystemInfo);
            try easy.bind(.getTimestamp);
            try easy.bind(.getStatus);
            try easy.bind(.getNotes);
            try easy.bind(.createNote);
            try easy.bind(.updateNote);
            try easy.bind(.deleteNote);
            try easy.bind(.savePdf);
            try easy.bind(.minimizeWindow);
            try easy.bind(.maximizeWindow);
            try easy.bind(.restoreWindow);
            try easy.bind(.closeWindow);
        }
    };

    return &CorePlugin.bind;
}

pub const id: []const u8 = "core";
pub const name: []const u8 = "Core backend";
pub const version: []const u8 = "0.1.0";
pub const description: []const u8 = "Core bindings, notes storage, and window controls";

/// Canonical JS binding names exposed by this plugin.
/// `frontend-preact/check-bindings.mjs` asserts `bindings.d.ts` and
/// `src/backend.js` stay in sync with this list.
pub const bound_names: []const []const u8 = &.{
    "increment",
    "reset",
    "getSystemInfo",
    "getTimestamp",
    "getStatus",
    "getNotes",
    "createNote",
    "updateNote",
    "deleteNote",
    "savePdf",
    "minimizeWindow",
    "maximizeWindow",
    "restoreWindow",
    "closeWindow",
};

test "core plugin exposes the documented binding set" {
    const std = @import("std");
    try std.testing.expectEqual(@as(usize, 14), bound_names.len);
    for (bound_names) |plugin_name| {
        try std.testing.expect(plugin_name.len > 0);
    }
    for (bound_names, 0..) |plugin_name, index| {
        for (bound_names[0..index]) |previous| {
            try std.testing.expect(!std.mem.eql(u8, plugin_name, previous));
        }
    }
}
