const std = @import("std");
const builtin = @import("builtin");
const c = @cImport({
    @cInclude("time.h");
});
const Webview = @import("webview").Webview;

// The built Svelte frontend is embedded directly into the binary.
const html = @embedFile("view/dist/index.html");

const Easy = Webview.Easy(Context);

const Context = struct {
    count: i64,

    pub fn increment(self: *Context, req: Easy.Request) !void {
        if (req.args.len < 3) return error.InvalidArgument;
        const delta = try std.fmt.parseInt(i64, req.args[1 .. req.args.len - 1], 10);
        self.count += delta;
        var buf: [32]u8 = undefined;
        req.resolveWith(try std.fmt.bufPrintZ(&buf, "{d}", .{self.count}));
    }

    pub fn reset(self: *Context, req: Easy.Request) !void {
        self.count = 0;
        req.resolveWith("0");
    }

    pub fn getSystemInfo(_: *Context, req: Easy.Request) !void {
        const info = switch (builtin.os.tag) {
            .linux => "Linux",
            .macos => "macOS",
            .windows => "Windows",
            else => "Unknown",
        };
        req.resolveWith(info);
    }

    pub fn getTimestamp(_: *Context, req: Easy.Request) !void {
        const ts = c.time(null);
        var buf: [32]u8 = undefined;
        req.resolveWith(try std.fmt.bufPrintZ(&buf, "{d}", .{@as(i64, @intCast(ts))}));
    }
};

pub fn main() !void {
    var ctx: Context = .{ .count = 0 };
    var easy: Easy = try .init(&ctx, .debug);
    defer easy.deinit();

    try easy.setTitle("WebView App");
    try easy.setSize(900, 600, .none);
    try easy.setHtml(html);

    try easy.bind(.increment);
    try easy.bind(.reset);
    try easy.bind(.getSystemInfo);
    try easy.bind(.getTimestamp);

    try easy.run();
}
