const std = @import("std");
const builtin = @import("builtin");
const Webview = @import("webview").Webview;
const backend = @import("backend.zig");
const config = @import("config.zig");
const core_plugin = @import("backend/core_plugin.zig");
const build_options = @import("build_options");

const gtk = struct {
    extern fn gtk_window_iconify(window: ?*anyopaque) void;
    extern fn gtk_window_deiconify(window: ?*anyopaque) void;
    extern fn gtk_window_maximize(window: ?*anyopaque) void;
    extern fn gtk_window_unmaximize(window: ?*anyopaque) void;
};

// The built Preact frontend (staged by build.zig from frontend-preact/dist)
// is embedded directly into the binary for release builds.
// Dev builds (`zig build run -Ddev`) navigate to the Preact dev server.
const html = @embedFile("frontend-dist/index.html");

const Easy = Webview.Easy(Context);

const Context = struct {
    state: backend.State,
    storage: *backend.Storage,

    pub fn increment(self: *Context, req: Easy.Request) !void {
        const delta = backend.parseIncrementArgs(
            req.args,
            std.heap.page_allocator,
        ) catch |err| {
            backend.rejectWithCode(
                req,
                @errorName(err),
                backend.incrementErrorMessage(err),
            );
            return;
        };
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

    pub fn getStatus(_: *Context, req: Easy.Request) !void {
        req.resolveWith(backend.healthStatus());
    }

    pub fn getNotes(self: *Context, req: Easy.Request) !void {
        const payload = self.storage.listNotes(std.heap.page_allocator) catch |err| {
            backend.rejectRpcError(req, err);
            return;
        };
        defer std.heap.page_allocator.free(payload);
        req.resolveWith(payload);
    }

    pub fn createNote(self: *Context, req: Easy.Request) !void {
        const parsed = backend.parseRpcArgs(req.args, std.heap.page_allocator) catch |err| {
            backend.rejectRpcError(req, err);
            return;
        };
        defer parsed.deinit();
        const input = backend.parseCreateNoteArgs(parsed.value) catch |err| {
            backend.rejectRpcError(req, err);
            return;
        };
        const payload = self.storage.createNote(input, std.heap.page_allocator) catch |err| {
            backend.rejectRpcError(req, err);
            return;
        };
        defer std.heap.page_allocator.free(payload);
        req.resolveWith(payload);
    }

    pub fn updateNote(self: *Context, req: Easy.Request) !void {
        const parsed = backend.parseRpcArgs(req.args, std.heap.page_allocator) catch |err| {
            backend.rejectRpcError(req, err);
            return;
        };
        defer parsed.deinit();
        const input = backend.parseUpdateNoteArgs(parsed.value) catch |err| {
            backend.rejectRpcError(req, err);
            return;
        };
        const payload = self.storage.updateNote(input, std.heap.page_allocator) catch |err| {
            backend.rejectRpcError(req, err);
            return;
        };
        defer std.heap.page_allocator.free(payload);
        req.resolveWith(payload);
    }

    pub fn deleteNote(self: *Context, req: Easy.Request) !void {
        const parsed = backend.parseRpcArgs(req.args, std.heap.page_allocator) catch |err| {
            backend.rejectRpcError(req, err);
            return;
        };
        defer parsed.deinit();
        const id = backend.parseDeleteNoteArgs(parsed.value) catch |err| {
            backend.rejectRpcError(req, err);
            return;
        };
        self.storage.deleteNote(id) catch |err| {
            backend.rejectRpcError(req, err);
            return;
        };
        req.resolve();
    }

    pub fn savePdf(_: *Context, req: Easy.Request) !void {
        const parsed = backend.parseRpcArgs(req.args, std.heap.page_allocator) catch |err| {
            backend.rejectRpcError(req, err);
            return;
        };
        defer parsed.deinit();
        const input = backend.parseSavePdfArgs(parsed.value) catch |err| {
            backend.rejectRpcError(req, err);
            return;
        };
        const payload = backend.savePdfToDocuments(std.heap.page_allocator, input) catch |err| {
            backend.rejectRpcError(req, err);
            return;
        };
        defer std.heap.page_allocator.free(payload);
        req.resolveWith(payload);
    }

    pub fn minimizeWindow(_: *Context, req: Easy.Request) !void {
        if (comptime builtin.os.tag == .linux) {
            const win = req.easy.getWindow() orelse {
                backend.rejectWithCode(
                    req,
                    "WindowUnavailable",
                    "native window handle is unavailable",
                );
                return;
            };
            gtk.gtk_window_iconify(win);
        } else {
            req.easy.minimize() catch {
                backend.rejectWithCode(
                    req,
                    "WindowActionFailed",
                    "minimize failed",
                );
                return;
            };
        }
        req.resolve();
    }

    pub fn maximizeWindow(_: *Context, req: Easy.Request) !void {
        if (comptime builtin.os.tag == .linux) {
            const win = req.easy.getWindow() orelse {
                backend.rejectWithCode(
                    req,
                    "WindowUnavailable",
                    "native window handle is unavailable",
                );
                return;
            };
            gtk.gtk_window_maximize(win);
        } else {
            req.easy.maximize() catch {
                backend.rejectWithCode(
                    req,
                    "WindowActionFailed",
                    "maximize failed",
                );
                return;
            };
        }
        req.resolve();
    }

    pub fn restoreWindow(_: *Context, req: Easy.Request) !void {
        if (comptime builtin.os.tag == .linux) {
            const win = req.easy.getWindow() orelse {
                backend.rejectWithCode(
                    req,
                    "WindowUnavailable",
                    "native window handle is unavailable",
                );
                return;
            };
            gtk.gtk_window_unmaximize(win);
        } else {
            req.easy.unmaximize() catch {
                backend.rejectWithCode(
                    req,
                    "WindowActionFailed",
                    "restore failed",
                );
                return;
            };
        }
        req.resolve();
    }

    pub fn closeWindow(_: *Context, req: Easy.Request) !void {
        // Settle the JS promise before terminating so the frontend
        // pending state clears instead of hanging.
        req.resolve();
        try req.easy.terminate();
    }
};

const BackendRegistry = backend.PluginRegistry(Easy);
const backend_plugins = [_]BackendRegistry.Plugin{
    .{
        .id = core_plugin.id,
        .name = core_plugin.name,
        .version = core_plugin.version,
        .description = core_plugin.description,
        .register = core_plugin.register(Easy),
    },
};

pub fn main() !void {
    const app_config = config.defaultAppConfig(config.isDebugBuild());
    backend.Log.log(.info, app_config.debug, "starting {s} ({d}x{d}) dev_mode={}", .{
        app_config.title,
        app_config.width,
        app_config.height,
        build_options.dev_mode,
    });

    var storage = backend.Storage.init(std.heap.page_allocator) catch |err| {
        backend.Log.log(.err, app_config.debug, "storage initialization failed: {s}", .{@errorName(err)});
        return err;
    };
    defer storage.deinit();

    var ctx: Context = .{ .state = .{}, .storage = &storage };
    var easy: Easy = try .init(&ctx, .{ .devtools = app_config.debug, .window = null });
    defer easy.deinit();

    try easy.setTitle(app_config.title);
    try easy.setSize(app_config.width, app_config.height, .none);

    if (build_options.dev_mode) {
        backend.Log.log(
            .info,
            app_config.debug,
            "navigating to dev server at {s}",
            .{app_config.dev_url},
        );
        try easy.navigate(app_config.dev_url);
    } else {
        try easy.setHtml(html);
    }

    const registry = BackendRegistry{ .plugins = &backend_plugins };
    try registry.registerAll(&easy);
    backend.Log.log(
        .debug,
        app_config.debug,
        "registered {d} backend plugin(s)",
        .{backend_plugins.len},
    );

    try easy.run();
    registry.deinitAll(&easy) catch |err| {
        backend.Log.log(.warn, app_config.debug, "plugin cleanup failed: {s}", .{@errorName(err)});
    };
    backend.Log.log(.info, app_config.debug, "shutdown complete", .{});
}
