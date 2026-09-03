const std = @import("std");

/// Leveled backend logging with different behavior for debug and release
/// builds (cf. webview-app-with-vlang logging todos).
/// `debug` messages are dropped unless `debug_enabled` is true; all other
/// levels always emit via `std.log`.
pub const Level = enum {
    debug,
    info,
    warn,
    err,
};

pub fn log(level: Level, debug_enabled: bool, comptime fmt: []const u8, args: anytype) void {
    switch (level) {
        .debug => {
            if (!debug_enabled) return;
            std.log.debug(fmt, args);
        },
        .info => std.log.info(fmt, args),
        .warn => std.log.warn(fmt, args),
        .err => std.log.err(fmt, args),
    }
}

pub fn shouldLog(level: Level, debug_enabled: bool) bool {
    return switch (level) {
        .debug => debug_enabled,
        .info, .warn, .err => true,
    };
}

test "debug logs are gated on debug flag" {
    try std.testing.expect(!shouldLog(.debug, false));
    try std.testing.expect(shouldLog(.debug, true));
    try std.testing.expect(shouldLog(.info, false));
    try std.testing.expect(shouldLog(.warn, false));
    try std.testing.expect(shouldLog(.err, false));
}
