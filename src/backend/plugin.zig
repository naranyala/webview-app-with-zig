const std = @import("std");

/// A backend plugin owns registration of one cohesive group of WebView RPCs.
/// Host is the concrete Easy type because bind() is compile-time typed.
pub fn PluginRegistry(comptime Host: type) type {
    return struct {
        const Self = @This();

        pub const Plugin = struct {
            id: []const u8,
            register: *const fn (*Host) anyerror!void,
        };

        plugins: []const Plugin,

        pub fn validate(self: Self) !void {
            for (self.plugins, 0..) |plugin, index| {
                for (self.plugins[0..index]) |previous| {
                    if (std.mem.eql(u8, plugin.id, previous.id)) return error.DuplicatePlugin;
                }
            }
        }

        pub fn registerAll(self: Self, host: *Host) !void {
            try self.validate();
            for (self.plugins) |plugin| {
                try plugin.register(host);
            }
        }
    };
}

test "plugin registry registers plugins in declaration order" {
    const Host = struct { order: u8 = 0 };
    const Registry = PluginRegistry(Host);

    const TestPlugins = struct {
        fn first(host: *Host) !void {
            host.order = host.order * 10 + 1;
        }

        fn second(host: *Host) !void {
            host.order = host.order * 10 + 2;
        }
    };

    const plugins = [_]Registry.Plugin{
        .{ .id = "first", .register = TestPlugins.first },
        .{ .id = "second", .register = TestPlugins.second },
    };
    var registry = Registry{ .plugins = &plugins };
    var host: Host = .{};

    try registry.registerAll(&host);
    try std.testing.expectEqual(@as(u8, 12), host.order);

    const duplicate_plugins = [_]Registry.Plugin{
        .{ .id = "first", .register = TestPlugins.first },
        .{ .id = "first", .register = TestPlugins.second },
    };
    var duplicate_registry = Registry{ .plugins = &duplicate_plugins };
    host.order = 0;
    try std.testing.expectError(error.DuplicatePlugin, duplicate_registry.registerAll(&host));
    try std.testing.expectEqual(@as(u8, 0), host.order);
}
