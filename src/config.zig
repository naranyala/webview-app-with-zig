const builtin = @import("builtin");

/// Central application configuration, mirroring `config.v` in
/// webview-app-with-vlang (`default_app_config`, `is_debug_build`).
/// Keeps window title/size, devtools flag, and dev-server URL out of
/// `src/main.zig` so behavior can be reasoned about and tested.
pub const AppConfig = struct {
    title: [:0]const u8,
    width: i32,
    height: i32,
    debug: bool,
    dev_url: [:0]const u8,
};

pub const default_title: [:0]const u8 = "WebView App";
pub const default_width: i32 = 900;
pub const default_height: i32 = 600;
pub const default_dev_url: [:0]const u8 = "http://localhost:3000/";

/// True for non-release builds. Mirrors V's `is_debug_build()`.
pub fn isDebugBuild() bool {
    return builtin.mode != .ReleaseFast and
        builtin.mode != .ReleaseSmall and
        builtin.mode != .ReleaseSafe;
}

pub fn defaultAppConfig(debug: bool) AppConfig {
    return .{
        .title = default_title,
        .width = default_width,
        .height = default_height,
        .debug = debug,
        .dev_url = default_dev_url,
    };
}

test "default config carries window geometry and dev url" {
    const cfg = defaultAppConfig(true);
    try @import("std").testing.expectEqualStrings("WebView App", cfg.title);
    try @import("std").testing.expectEqual(@as(i32, 900), cfg.width);
    try @import("std").testing.expectEqual(@as(i32, 600), cfg.height);
    try @import("std").testing.expect(cfg.debug);
    try @import("std").testing.expectEqualStrings("http://localhost:3000/", cfg.dev_url);
}

test "release config disables devtools" {
    const cfg = defaultAppConfig(false);
    try @import("std").testing.expect(!cfg.debug);
}
