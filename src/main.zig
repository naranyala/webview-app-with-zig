const std = @import("std");
const builtin = @import("builtin");
const Webview = @import("webview").Webview;
const backend = @import("backend.zig");
const core_plugin = @import("backend/core_plugin.zig");

const gtk = struct {
    extern fn gtk_window_iconify(window: ?*anyopaque) void;
    extern fn gtk_window_deiconify(window: ?*anyopaque) void;
    extern fn gtk_window_maximize(window: ?*anyopaque) void;
    extern fn gtk_window_unmaximize(window: ?*anyopaque) void;
    extern fn gtk_window_fullscreen(window: ?*anyopaque) void;
    extern fn gtk_window_unfullscreen(window: ?*anyopaque) void;
};

// The built Svelte frontend is embedded directly into the binary.
const html = @embedFile("view/dist/index.html");

const Easy = Webview.Easy(Context);

const Context = struct {
    state: backend.State,

    pub fn increment(self: *Context, req: Easy.Request) !void {
        const delta = try backend.parseIncrementArgs(req.args, std.heap.page_allocator);
        const count = self.state.increment(delta);
        var buf: [32]u8 = undefined;
        req.resolveWith(try std.fmt.bufPrintZ(&buf, "{d}", .{count}));
    }

    pub fn reset(self: *Context, req: Easy.Request) !void {
        var buf: [32]u8 = undefined;
        req.resolveWith(try std.fmt.bufPrintZ(&buf, "{d}", .{self.state.reset()}));
    }

    pub fn getSystemInfo(_: *Context, req: Easy.Request) !void {
        req.resolveWith(backend.systemInfo());
    }

    pub fn getTimestamp(_: *Context, req: Easy.Request) !void {
        var buf: [32]u8 = undefined;
        req.resolveWith(try backend.formatTimestamp(&buf, backend.timestamp()));
    }

    pub fn minimizeWindow(_: *Context, req: Easy.Request) !void {
        if (comptime builtin.os.tag == .linux) {
            gtk.gtk_window_iconify(req.easy.getWindow() orelse return error.InvalidState);
        } else {
            try req.easy.minimize();
        }
        req.resolve();
    }

    pub fn maximizeWindow(_: *Context, req: Easy.Request) !void {
        if (comptime builtin.os.tag == .linux) {
            gtk.gtk_window_maximize(req.easy.getWindow() orelse return error.InvalidState);
        } else {
            try req.easy.maximize();
        }
        req.resolve();
    }

    pub fn restoreWindow(_: *Context, req: Easy.Request) !void {
        if (comptime builtin.os.tag == .linux) {
            gtk.gtk_window_unmaximize(req.easy.getWindow() orelse return error.InvalidState);
        } else {
            try req.easy.unmaximize();
        }
        req.resolve();
    }

    pub fn enterFullscreen(_: *Context, req: Easy.Request) !void {
        if (comptime builtin.os.tag == .linux) {
            gtk.gtk_window_fullscreen(req.easy.getWindow() orelse return error.InvalidState);
        } else {
            try req.easy.fullscreen();
        }
        req.resolve();
    }

    pub fn exitFullscreen(_: *Context, req: Easy.Request) !void {
        if (comptime builtin.os.tag == .linux) {
            gtk.gtk_window_unfullscreen(req.easy.getWindow() orelse return error.InvalidState);
        } else {
            try req.easy.unfullscreen();
        }
        req.resolve();
    }

    pub fn closeWindow(_: *Context, req: Easy.Request) !void {
        try req.easy.terminate();
    }
};

const BackendRegistry = backend.PluginRegistry(Easy);
const backend_plugins = [_]BackendRegistry.Plugin{
    .{ .id = "core", .register = core_plugin.register(Easy) },
};

pub fn main() !void {
    var ctx: Context = .{ .state = .{} };
    var easy: Easy = try .init(&ctx, .debug);
    defer easy.deinit();

    try easy.setTitle("WebView App");
    try easy.setSize(900, 600, .none);
    try easy.setHtml(html);

    const registry = BackendRegistry{ .plugins = &backend_plugins };
    try registry.registerAll(&easy);

    try easy.run();
}
