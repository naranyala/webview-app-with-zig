const std = @import("std");
const builtin = @import("builtin");
const c = @cImport({
    @cInclude("time.h");
});

const io = std.Options.debug_io;

pub const PluginRegistry = @import("backend/plugin.zig").PluginRegistry;
pub const Log = @import("backend/log.zig");
pub const Storage = @import("backend/storage.zig").Storage;
pub const Note = @import("backend/storage.zig").Note;
pub const NoteInput = @import("backend/storage.zig").NoteInput;
pub const UpdateNoteInput = @import("backend/storage.zig").UpdateNoteInput;

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

/// Typed validation failures for the increment RPC method, so the frontend
/// can distinguish malformed calls instead of receiving one opaque error.
pub const IncrementParseError = error{
    MalformedJson,
    NotArgumentArray,
    WrongArgumentCount,
    NonIntegerArgument,
};

/// Parses the one integer argument accepted by the increment RPC method.
pub fn parseIncrementArgs(args: []const u8, allocator: std.mem.Allocator) IncrementParseError!i64 {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, args, .{}) catch {
        return error.MalformedJson;
    };
    defer parsed.deinit();

    const values = switch (parsed.value) {
        .array => |array| array.items,
        else => return error.NotArgumentArray,
    };
    if (values.len != 1) return error.WrongArgumentCount;

    return switch (values[0]) {
        .integer => |value| value,
        else => error.NonIntegerArgument,
    };
}

/// Human-readable detail for each increment validation failure.
/// Messages avoid double quotes so they embed safely in the error envelope.
pub fn incrementErrorMessage(err: IncrementParseError) [:0]const u8 {
    return switch (err) {
        error.MalformedJson => "arguments must be JSON, e.g. [1]",
        error.NotArgumentArray => "arguments must be a JSON array, e.g. [1]",
        error.WrongArgumentCount => "increment takes exactly one argument, e.g. [1]",
        error.NonIntegerArgument => "increment delta must be an integer, e.g. [1]",
    };
}

/// Rejects an RPC request with a structured JSON envelope:
/// {"code":"<PascalCaseCode>","message":"<human detail>"}.
/// Codes are stable tokens for frontend switching; messages are for display.
/// `message` must not contain double quotes (all built-in messages satisfy this).
pub fn rejectWithCode(req: anytype, code: []const u8, message: []const u8) void {
    var buf: [256]u8 = undefined;
    const payload = std.fmt.bufPrintZ(
        &buf,
        "{{\"code\":\"{s}\",\"message\":\"{s}\"}}",
        .{ code, message },
    ) catch {
        req.rejectError(error.EnvelopeTooLarge);
        return;
    };
    req.reject(payload);
}

pub const RpcArgsError = error{
    MalformedJson,
    NotArgumentArray,
    WrongArgumentCount,
    NonStringArgument,
};

pub fn parseRpcArgs(
    args: []const u8,
    allocator: std.mem.Allocator,
) RpcArgsError!std.json.Parsed(std.json.Value) {
    return std.json.parseFromSlice(std.json.Value, allocator, args, .{}) catch {
        return error.MalformedJson;
    };
}

fn argumentStrings(value: std.json.Value, comptime count: usize) RpcArgsError![count][]const u8 {
    const values = switch (value) {
        .array => |array| array.items,
        else => return error.NotArgumentArray,
    };
    if (values.len != count) return error.WrongArgumentCount;

    var result: [count][]const u8 = undefined;
    for (values, 0..) |item, index| {
        result[index] = switch (item) {
            .string => |string| string,
            else => return error.NonStringArgument,
        };
    }
    return result;
}

pub fn parseCreateNoteArgs(value: std.json.Value) RpcArgsError!NoteInput {
    const values = try argumentStrings(value, 3);
    return .{ .title = values[0], .tag = values[1], .body = values[2] };
}

pub fn parseUpdateNoteArgs(value: std.json.Value) RpcArgsError!UpdateNoteInput {
    const values = try argumentStrings(value, 4);
    return .{ .id = values[0], .title = values[1], .tag = values[2], .body = values[3] };
}

pub fn parseDeleteNoteArgs(value: std.json.Value) RpcArgsError![]const u8 {
    return (try argumentStrings(value, 1))[0];
}

pub fn rpcErrorCode(err: anyerror) []const u8 {
    return switch (err) {
        error.MalformedJson => "MalformedJson",
        error.NotArgumentArray => "NotArgumentArray",
        error.WrongArgumentCount => "WrongArgumentCount",
        error.NonStringArgument => "NonStringArgument",
        error.InvalidPdfName => "InvalidPdfName",
        error.PdfTooLarge => "PdfTooLarge",
        error.PdfDecodeFailed => "PdfDecodeFailed",
        error.DocumentsUnavailable => "DocumentsUnavailable",
        error.PdfWriteFailed => "PdfWriteFailed",
        else => @import("backend/storage.zig").errorCode(err),
    };
}

pub fn rpcErrorMessage(err: anyerror) []const u8 {
    return switch (err) {
        error.MalformedJson => "arguments must be valid JSON",
        error.NotArgumentArray => "arguments must be a JSON array",
        error.WrongArgumentCount => "the wrong number of arguments was provided",
        error.NonStringArgument => "note arguments must be strings",
        error.InvalidPdfName => "pdf filename is invalid",
        error.PdfTooLarge => "pdf is too large",
        error.PdfDecodeFailed => "pdf data could not be decoded",
        error.DocumentsUnavailable => "documents folder is unavailable",
        error.PdfWriteFailed => "pdf could not be written",
        else => @import("backend/storage.zig").errorMessage(err),
    };
}

/// Maximum PDF filename length, including the `.pdf` suffix.
pub const max_pdf_filename_bytes: usize = 100;
/// Maximum accepted PDF payload after base64 decoding (16 MiB).
pub const max_pdf_bytes: usize = 16 * 1024 * 1024;
/// Maximum accepted base64 payload length before decoding.
pub const max_pdf_b64_bytes: usize = 22_400_000;

pub const SavePdfInput = struct {
    filename: []const u8,
    content_b64: []const u8,
};

pub fn parseSavePdfArgs(value: std.json.Value) RpcArgsError!SavePdfInput {
    const values = try argumentStrings(value, 2);
    return .{ .filename = values[0], .content_b64 = values[1] };
}

fn pdfEnvironment(comptime name: [:0]const u8) ?[]const u8 {
    const value = std.c.getenv(name.ptr) orelse return null;
    const slice = std.mem.span(value);
    return if (slice.len == 0) null else slice;
}

/// Resolves the per-user Documents folder used for PDF exports.
pub fn resolveDocumentsDir(allocator: std.mem.Allocator) ![]u8 {
    switch (builtin.os.tag) {
        .linux, .macos => {
            const home = pdfEnvironment("HOME") orelse return error.DocumentsUnavailable;
            return std.fs.path.join(allocator, &.{ home, "Documents" });
        },
        .windows => {
            const profile = pdfEnvironment("USERPROFILE") orelse return error.DocumentsUnavailable;
            return std.fs.path.join(allocator, &.{ profile, "Documents" });
        },
        else => return error.UnsupportedPlatform,
    }
}

fn validatePdfFilename(name: []const u8) !void {
    if (name.len < 5 or name.len > max_pdf_filename_bytes) return error.InvalidPdfName;
    if (!std.mem.endsWith(u8, name, ".pdf")) return error.InvalidPdfName;
    if (!std.ascii.isAlphanumeric(name[0])) return error.InvalidPdfName;
    for (name[1 .. name.len - 4]) |ch| {
        if (!std.ascii.isAlphanumeric(ch) and ch != '.' and ch != '_' and ch != '-') {
            return error.InvalidPdfName;
        }
    }
}

fn decodePdfContent(allocator: std.mem.Allocator, content_b64: []const u8) ![]u8 {
    if (content_b64.len == 0 or content_b64.len > max_pdf_b64_bytes) return error.PdfTooLarge;
    const Decoder = std.base64.standard.Decoder;
    const decoded_len = Decoder.calcSizeForSlice(content_b64) catch return error.PdfDecodeFailed;
    if (decoded_len == 0 or decoded_len > max_pdf_bytes) return error.PdfTooLarge;
    const decoded = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(decoded);
    Decoder.decode(decoded, content_b64) catch return error.PdfDecodeFailed;
    return decoded;
}

/// Writes a PDF payload into `dir_path` (creating it when needed), picking a
/// unique filename when `input.filename` is taken. Returns `{"path": ...}`.
/// `dir_path` is injectable so tests avoid touching the real Documents folder.
pub fn savePdfToDir(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    input: SavePdfInput,
) ![:0]u8 {
    try validatePdfFilename(input.filename);
    const decoded = try decodePdfContent(allocator, input.content_b64);
    defer allocator.free(decoded);

    std.Io.Dir.cwd().createDirPath(io, dir_path) catch return error.DocumentsUnavailable;
    var dir = std.Io.Dir.openDirAbsolute(io, dir_path, .{}) catch return error.DocumentsUnavailable;
    defer dir.close(io);

    const stem = input.filename[0 .. input.filename.len - 4];
    var attempt: u32 = 0;
    while (attempt < 1000) : (attempt += 1) {
        var name_buf: [max_pdf_filename_bytes + 16]u8 = undefined;
        const candidate = if (attempt == 0)
            input.filename
        else
            std.fmt.bufPrint(&name_buf, "{s}-{d}.pdf", .{ stem, attempt + 1 }) catch return error.PdfWriteFailed;

        const occupied = blk: {
            var existing = dir.openFile(io, candidate, .{}) catch |err| switch (err) {
                error.FileNotFound => break :blk false,
                else => return error.PdfWriteFailed,
            };
            existing.close(io);
            break :blk true;
        };
        if (occupied) continue;

        var atomic = dir.createFileAtomic(io, candidate, .{ .replace = false }) catch return error.PdfWriteFailed;
        defer atomic.deinit(io);
        var write_buf: [8192]u8 = undefined;
        var writer = atomic.file.writer(io, &write_buf);
        writer.interface.writeAll(decoded) catch return error.PdfWriteFailed;
        writer.flush() catch return error.PdfWriteFailed;
        atomic.replace(io) catch return error.PdfWriteFailed;

        const full_path = try std.fs.path.join(allocator, &.{ dir_path, candidate });
        defer allocator.free(full_path);
        var output: std.Io.Writer.Allocating = .init(allocator);
        defer output.deinit();
        var stringify: std.json.Stringify = .{ .writer = &output.writer };
        try stringify.write(.{ .path = full_path });
        return allocator.dupeZ(u8, output.written());
    }
    return error.PdfWriteFailed;
}

/// Saves a PDF payload into the user's Documents folder. Returns `{"path": ...}`.
pub fn savePdfToDocuments(allocator: std.mem.Allocator, input: SavePdfInput) ![:0]u8 {
    const dir_path = try resolveDocumentsDir(allocator);
    defer allocator.free(dir_path);
    return savePdfToDir(allocator, dir_path, input);
}

pub fn rejectRpcError(req: anytype, err: anyerror) void {
    rejectWithCode(req, rpcErrorCode(err), rpcErrorMessage(err));
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

/// Health/status payload for frontend startup checks.
/// Mirrors the webview-app-with-vlang health-check idea (`get_time`).
/// Returns a plain status token, consistent with `systemInfo()`.
pub fn healthStatus() [:0]const u8 {
    return "ok";
}

/// Structured status payload for richer startup checks.
pub fn statusPayload() [:0]const u8 {
    return "{\"status\":\"ok\",\"backend\":\"zig\"}";
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
    try std.testing.expectEqual(
        @as(i64, -12),
        try parseIncrementArgs(" \n [ -12 ] \n", allocator),
    );
    try std.testing.expectError(
        error.WrongArgumentCount,
        parseIncrementArgs("[]", allocator),
    );
    try std.testing.expectError(
        error.WrongArgumentCount,
        parseIncrementArgs("[1, 2]", allocator),
    );
    try std.testing.expectError(
        error.NonIntegerArgument,
        parseIncrementArgs("[\"1\"]", allocator),
    );
    try std.testing.expectError(
        error.NonIntegerArgument,
        parseIncrementArgs("[1.5]", allocator),
    );
    try std.testing.expectError(
        error.NonIntegerArgument,
        parseIncrementArgs("[true]", allocator),
    );
    try std.testing.expectError(
        error.NonIntegerArgument,
        parseIncrementArgs("[null]", allocator),
    );
    try std.testing.expectError(
        error.NonIntegerArgument,
        parseIncrementArgs("[{}]", allocator),
    );
    try std.testing.expectError(
        error.MalformedJson,
        parseIncrementArgs("[1] trailing", allocator),
    );
    try std.testing.expectError(
        error.MalformedJson,
        parseIncrementArgs("invalid", allocator),
    );
    try std.testing.expectError(
        error.NotArgumentArray,
        parseIncrementArgs("{\"delta\": 1}", allocator),
    );
}

test "increment failures carry distinct human-readable messages" {
    try std.testing.expectEqualStrings(
        "arguments must be JSON, e.g. [1]",
        incrementErrorMessage(error.MalformedJson),
    );
    try std.testing.expectEqualStrings(
        "arguments must be a JSON array, e.g. [1]",
        incrementErrorMessage(error.NotArgumentArray),
    );
    try std.testing.expectEqualStrings(
        "increment takes exactly one argument, e.g. [1]",
        incrementErrorMessage(error.WrongArgumentCount),
    );
    try std.testing.expectEqualStrings(
        "increment delta must be an integer, e.g. [1]",
        incrementErrorMessage(error.NonIntegerArgument),
    );
}

test "rejections use a stable JSON envelope" {
    // Note: the envelope borrows the helper's stack buffer and is only
    // valid for synchronous use (as with the real webview `reject`), so
    // the fake copies it into its own storage like a real bridge would.
    const FakeReq = struct {
        storage: [256]u8 = undefined,
        rejected: ?[]const u8 = null,
        failed: ?anyerror = null,

        pub fn reject(self: *@This(), payload: [:0]const u8) void {
            @memcpy(self.storage[0..payload.len], payload);
            self.rejected = self.storage[0..payload.len];
        }

        pub fn rejectError(self: *@This(), err: anyerror) void {
            self.failed = err;
        }
    };

    var req: FakeReq = .{};
    rejectWithCode(&req, "MalformedJson", "arguments must be JSON, e.g. [1]");
    try std.testing.expectEqualStrings(
        "{\"code\":\"MalformedJson\",\"message\":\"arguments must be JSON, e.g. [1]\"}",
        req.rejected.?,
    );
    try std.testing.expect(req.failed == null);
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

test "health status reports ok" {
    try std.testing.expectEqualStrings("ok", healthStatus());
    try std.testing.expectEqualStrings("{\"status\":\"ok\",\"backend\":\"zig\"}", statusPayload());
}

test "pdf filenames are validated" {
    try validatePdfFilename("chain-notes.pdf");
    try validatePdfFilename("a.pdf");
    try validatePdfFilename("Chain_Notes-2026.09.04.pdf");
    try std.testing.expectError(error.InvalidPdfName, validatePdfFilename(""));
    try std.testing.expectError(error.InvalidPdfName, validatePdfFilename(".pdf"));
    try std.testing.expectError(error.InvalidPdfName, validatePdfFilename("notes.txt"));
    try std.testing.expectError(error.InvalidPdfName, validatePdfFilename("../evil.pdf"));
    try std.testing.expectError(error.InvalidPdfName, validatePdfFilename("has space.pdf"));
    try std.testing.expectError(error.InvalidPdfName, validatePdfFilename("-leading.pdf"));
    try std.testing.expectEqualStrings("InvalidPdfName", rpcErrorCode(error.InvalidPdfName));
    try std.testing.expectEqualStrings("pdf filename is invalid", rpcErrorMessage(error.InvalidPdfName));
}

test "pdf payloads decode within limits" {
    const allocator = std.testing.allocator;

    const decoded = try decodePdfContent(allocator, "aGVsbG8=");
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("hello", decoded);

    try std.testing.expectError(error.PdfDecodeFailed, decodePdfContent(allocator, "!!!"));
    try std.testing.expectError(error.PdfTooLarge, decodePdfContent(allocator, ""));
    try std.testing.expectEqualStrings("PdfTooLarge", rpcErrorCode(error.PdfTooLarge));
    try std.testing.expectEqualStrings("pdf could not be written", rpcErrorMessage(error.PdfWriteFailed));
}

test "pdf saves land on disk with unique names" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const cwd = try std.process.currentPathAlloc(io, allocator);
    defer allocator.free(cwd);
    const data_dir = try std.fs.path.join(allocator, &.{ cwd, ".zig-cache", "tmp", &tmp.sub_path });
    defer allocator.free(data_dir);

    const input: SavePdfInput = .{ .filename = "chain.pdf", .content_b64 = "aGVsbG8=" };
    const first = try savePdfToDir(allocator, data_dir, input);
    defer allocator.free(first);
    try std.testing.expect(std.mem.indexOf(u8, first, "chain.pdf") != null);

    const second = try savePdfToDir(allocator, data_dir, input);
    defer allocator.free(second);
    try std.testing.expect(std.mem.indexOf(u8, second, "chain-2.pdf") != null);

    try std.testing.expectError(
        error.InvalidPdfName,
        savePdfToDir(allocator, data_dir, .{ .filename = "evil/../x.pdf", .content_b64 = "aGVsbG8=" }),
    );
    try std.testing.expectError(
        error.PdfDecodeFailed,
        savePdfToDir(allocator, data_dir, .{ .filename = "chain.pdf", .content_b64 = "!!!" }),
    );
}
