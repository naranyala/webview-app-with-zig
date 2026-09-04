const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const webkitgtk = b.option(
        WebkitGtkVersion,
        "webkitgtk",
        "WebKitGTK version (Linux only, default: 4.1)",
    ) orelse .@"4.1";
    const macos_sdk = b.option([]const u8, "macos-sdk", "Path to macOS SDK (optional)");
    const dev_mode = b.option(
        bool,
        "dev",
        "Navigate to the frontend dev server instead of the embedded HTML",
    ) orelse false;

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

    const build_options = b.addOptions();
    build_options.addOption(bool, "dev_mode", dev_mode);
    exe.root_module.addImport("build_options", build_options.createModule());

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

    if (builtin.os.tag == .linux) {
        // Workstations on NTFS/exFAT mounts: Zig's atomic install relies on
        // hard-link syscalls those filesystems reject, and chmod fails there
        // too (all files map to the mount owner). Install with a plain copy
        // instead: the cached binary is already executable and cp preserves
        // that through the umask. Same output path.
        const mkdir_bin = b.addSystemCommand(&.{ "mkdir", "-p" });
        mkdir_bin.addArg(b.exe_dir);
        const cp_bin = b.addSystemCommand(&.{"cp"});
        cp_bin.addFileArg(exe.getEmittedBin());
        cp_bin.addArg(b.getInstallPath(.bin, "webview-app"));
        cp_bin.step.dependOn(&mkdir_bin.step);
        b.getInstallStep().dependOn(&cp_bin.step);
    } else {
        b.installArtifact(exe);
    }

    // --- Frontend Build (npm + esbuild via frontend-preact) ---
    const npm_install = b.addSystemCommand(&.{"bash"});
    npm_install.addFileArg(b.path("tools/install-frontend.sh"));
    npm_install.setCwd(b.path("frontend-preact"));

    const frontend_build = b.addSystemCommand(&.{ "npm", "run", "build" });
    frontend_build.setCwd(b.path("frontend-preact"));
    frontend_build.step.dependOn(&npm_install.step);

    // Zig 0.16 restricts @embedFile to the package (src/) tree, so stage the
    // single-file bundle inside src/ before compiling the executable.
    const stage_frontend = b.addSystemCommand(&.{
        "cp",
        "../frontend-preact/dist/index.html",
        "frontend-dist/index.html",
    });
    stage_frontend.setCwd(b.path("src"));
    stage_frontend.step.dependOn(&frontend_build.step);

    exe.step.dependOn(&stage_frontend.step);

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
    dev_cmd.setCwd(b.path("frontend-preact"));
    dev_step.dependOn(&dev_cmd.step);

    // --- Test Step (backend unit tests + frontend checks) ---
    // Mirrors `v run build.vsh test` in webview-app-with-vlang.
    const test_step = b.step("test", "Run backend tests and frontend checks");

    const backend_test_roots: []const []const u8 = &.{
        "src/backend.zig",
        "src/config.zig",
        "src/backend/plugin.zig",
        "src/backend/log.zig",
        "src/backend/core_plugin.zig",
        "src/backend/storage.zig",
    };
    for (backend_test_roots) |root| {
        const mod = b.createModule(.{
            .root_source_file = b.path(root),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        const unit_tests = b.addTest(.{ .root_module = mod, .use_llvm = true });
        const run_unit_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_unit_tests.step);
    }

    const frontend_check = b.addSystemCommand(&.{ "npm", "run", "check" });
    frontend_check.setCwd(b.path("frontend-preact"));
    // Frontend checks require node_modules; install step provides them.
    frontend_check.step.dependOn(&npm_install.step);
    test_step.dependOn(&frontend_check.step);

    const bindings_check = b.addSystemCommand(&.{ "npm", "run", "check:bindings" });
    bindings_check.setCwd(b.path("frontend-preact"));
    bindings_check.step.dependOn(&npm_install.step);
    test_step.dependOn(&bindings_check.step);

    const frontend_tests = b.addSystemCommand(&.{ "npm", "run", "test" });
    frontend_tests.setCwd(b.path("frontend-preact"));
    frontend_tests.step.dependOn(&npm_install.step);
    test_step.dependOn(&frontend_tests.step);
}

const WebkitGtkVersion = enum {
    @"4.0",
    @"4.1",
    @"6.0",
};
