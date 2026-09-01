const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const webkitgtk = b.option(WebkitGtkVersion, "webkitgtk", "WebKitGTK version (Linux only, default: 4.1)") orelse .@"4.1";
    const macos_sdk = b.option([]const u8, "macos-sdk", "Path to macOS SDK (optional)");

    // --- Zig Executable ---
    const exe = b.addExecutable(.{
        .name = "webview-app",
        .use_llvm = true,
        .use_lld = false,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    if (target.result.os.tag == .linux and target.query.isNative()) {
        const prepare_linux_libc = b.addSystemCommand(&.{"bash"});
        prepare_linux_libc.addFileArg(b.path("tools/prepare-linux-libc.sh"));
        exe.setLibCFile(prepare_linux_libc.addOutputFileArg("libc.conf"));
    }

    const webview_dep = b.dependency("webview", .{
        .target = target,
        .optimize = optimize,
        .@"macos-sdk" = macos_sdk,
        .webkitgtk = webkitgtk,
    });
    exe.root_module.addImport("webview", webview_dep.module("webview"));

    if (target.result.os.tag == .windows) {
        exe.subsystem = .Windows;
    }

    b.installArtifact(exe);

    // --- Frontend Build (npm + vite) ---
    const npm_install = b.addSystemCommand(&.{"bash"});
    npm_install.addFileArg(b.path("tools/install-frontend.sh"));
    npm_install.setCwd(b.path("src/view"));

    const vite_build = b.addSystemCommand(&.{ "npm", "run", "build" });
    vite_build.setCwd(b.path("src/view"));
    vite_build.step.dependOn(&npm_install.step);

    exe.step.dependOn(&vite_build.step);

    // --- Run Step ---
    const run_step = b.step("run", "Build and run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_step.dependOn(&run_cmd.step);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // --- Dev Step (frontend only) ---
    const dev_step = b.step("dev", "Start frontend dev server");
    const dev_cmd = b.addSystemCommand(&.{ "npm", "run", "dev" });
    dev_cmd.setCwd(b.path("src/view"));
    dev_step.dependOn(&dev_cmd.step);

    // --- Test Step ---
    const backend_module = b.createModule(.{
        .root_source_file = b.path("src/backend.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const backend_tests = b.addTest(.{ .root_module = backend_module, .use_llvm = true });
    const run_backend_tests = b.addRunArtifact(backend_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_backend_tests.step);
}

const WebkitGtkVersion = enum {
    @"4.0",
    @"4.1",
    @"6.0",
};
