const std = @import("std");
const builtin = @import("builtin");
const c = @cImport({
    @cInclude("time.h");
});

const Allocator = std.mem.Allocator;
const io = std.Options.debug_io;

pub const schema_version: u32 = 1;
pub const max_state_bytes: usize = 4 * 1024 * 1024;
pub const max_title_bytes: usize = 200;
pub const max_id_bytes: usize = 200;
pub const max_tag_bytes: usize = 64;
pub const max_body_bytes: usize = 512 * 1024;

pub const Error = error{
    NoHomeDirectory,
    UnsupportedPlatform,
    StorageUnavailable,
    StorageCorrupt,
    StorageUnsupportedVersion,
    StorageReadFailed,
    StorageWriteFailed,
    NoteNotFound,
    NoteIdTooLong,
    InvalidNoteArguments,
    NoteTitleEmpty,
    NoteIdEmpty,
    NoteTitleTooLong,
    NoteTagTooLong,
    NoteBodyTooLong,
};

pub const Note = struct {
    id: []const u8,
    title: []const u8,
    tag: []const u8,
    updated: []const u8,
    body: []const u8,
};

const Document = struct {
    version: u32 = schema_version,
    counter: u64 = 0,
    notes: []Note = &.{},
};

pub const NoteInput = struct {
    title: []const u8,
    tag: []const u8,
    body: []const u8,
};

pub const UpdateNoteInput = struct {
    id: []const u8,
    title: []const u8,
    tag: []const u8,
    body: []const u8,
};

fn environment(comptime name: [:0]const u8) ?[]const u8 {
    const value = std.c.getenv(name.ptr) orelse return null;
    const slice = std.mem.span(value);
    return if (slice.len == 0) null else slice;
}

/// Resolves an absolute, app-specific data directory. WEBVIEW_APP_DATA_DIR
/// is an explicit override for tests and portable deployments.
pub fn resolveDataDir(allocator: Allocator) ![]u8 {
    if (environment("WEBVIEW_APP_DATA_DIR")) |override| {
        return allocator.dupe(u8, override);
    }

    var base: []const u8 = undefined;
    var owned_base = false;
    switch (builtin.os.tag) {
        .linux => {
            if (environment("XDG_DATA_HOME")) |xdg| {
                base = xdg;
            } else if (environment("HOME")) |home| {
                base = try std.fs.path.join(allocator, &.{ home, ".local", "share" });
                owned_base = true;
            } else {
                return error.NoHomeDirectory;
            }
        },
        .macos => {
            const home = environment("HOME") orelse return error.NoHomeDirectory;
            base = try std.fs.path.join(allocator, &.{ home, "Library", "Application Support" });
            owned_base = true;
        },
        .windows => {
            base = environment("APPDATA") orelse
                environment("LOCALAPPDATA") orelse
                environment("USERPROFILE") orelse
                return error.NoHomeDirectory;
        },
        else => return error.UnsupportedPlatform,
    }
    defer if (owned_base) allocator.free(base);
    return std.fs.path.join(allocator, &.{ base, "webview-app" });
}

pub const Storage = struct {
    allocator: Allocator,
    data_dir: []u8,
    notes: std.ArrayList(Note) = .empty,
    counter: u64 = 0,

    pub fn init(allocator: Allocator) !Storage {
        const data_dir = resolveDataDir(allocator) catch return error.StorageUnavailable;
        defer allocator.free(data_dir);
        return initAt(allocator, data_dir) catch |err| {
            return err;
        };
    }

    pub fn initAt(allocator: Allocator, data_dir: []const u8) !Storage {
        var storage: Storage = .{
            .allocator = allocator,
            .data_dir = try allocator.dupe(u8, data_dir),
        };
        errdefer storage.deinit();
        storage.load() catch |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        };
        return storage;
    }

    pub fn deinit(self: *Storage) void {
        for (self.notes.items) |note| self.freeNote(note);
        self.notes.deinit(self.allocator);
        self.allocator.free(self.data_dir);
    }

    fn freeNote(self: *Storage, note: Note) void {
        self.allocator.free(note.id);
        self.allocator.free(note.title);
        self.allocator.free(note.tag);
        self.allocator.free(note.updated);
        self.allocator.free(note.body);
    }

    fn load(self: *Storage) !void {
        const root = std.Io.Dir.cwd();
        const path = self.statePath();
        defer self.allocator.free(path);
        const bytes = root.readFileAlloc(io, path, self.allocator, .limited(max_state_bytes)) catch |err| switch (err) {
            error.FileNotFound => return error.FileNotFound,
            else => return error.StorageReadFailed,
        };
        defer self.allocator.free(bytes);

        const parsed = std.json.parseFromSlice(Document, self.allocator, bytes, .{}) catch {
            return error.StorageCorrupt;
        };
        defer parsed.deinit();
        if (parsed.value.version != schema_version) return error.StorageUnsupportedVersion;
        self.counter = parsed.value.counter;

        for (parsed.value.notes) |note| {
            try self.notes.append(self.allocator, try self.cloneNote(note));
        }
    }

    fn statePath(self: *Storage) []const u8 {
        return std.fs.path.join(self.allocator, &.{ self.data_dir, "state.json" }) catch unreachable;
    }

    fn cloneNote(self: *Storage, source: Note) !Note {
        const id = try self.allocator.dupe(u8, source.id);
        errdefer self.allocator.free(id);
        const title = try self.allocator.dupe(u8, source.title);
        errdefer self.allocator.free(title);
        const tag = try self.allocator.dupe(u8, source.tag);
        errdefer self.allocator.free(tag);
        const updated = try self.allocator.dupe(u8, source.updated);
        errdefer self.allocator.free(updated);
        const body = try self.allocator.dupe(u8, source.body);
        return .{ .id = id, .title = title, .tag = tag, .updated = updated, .body = body };
    }

    fn serialize(self: *Storage, allocator: Allocator) ![:0]u8 {
        var output: std.Io.Writer.Allocating = .init(allocator);
        defer output.deinit();
        var stringify: std.json.Stringify = .{ .writer = &output.writer };
        try stringify.write(Document{
            .version = schema_version,
            .counter = self.counter,
            .notes = self.notes.items,
        });
        return allocator.dupeZ(u8, output.written());
    }

    fn persist(self: *Storage) !void {
        try std.Io.Dir.cwd().createDirPath(io, self.data_dir);
        var dir = std.Io.Dir.openDirAbsolute(io, self.data_dir, .{}) catch return error.StorageWriteFailed;
        defer dir.close(io);

        const data = self.serialize(self.allocator) catch return error.StorageWriteFailed;
        defer self.allocator.free(data);

        var atomic = dir.createFileAtomic(io, "state.json", .{ .replace = true }) catch return error.StorageWriteFailed;
        defer atomic.deinit(io);
        var buffer: [4096]u8 = undefined;
        var writer = atomic.file.writer(io, &buffer);
        writer.interface.writeAll(data) catch return error.StorageWriteFailed;
        writer.flush() catch return error.StorageWriteFailed;
        atomic.replace(io) catch return error.StorageWriteFailed;
    }

    pub fn listNotes(self: *Storage, allocator: Allocator) ![:0]u8 {
        var output: std.Io.Writer.Allocating = .init(allocator);
        defer output.deinit();
        var stringify: std.json.Stringify = .{ .writer = &output.writer };
        try stringify.write(self.notes.items);
        return allocator.dupeZ(u8, output.written());
    }

    pub fn createNote(self: *Storage, input: NoteInput, allocator: Allocator) ![:0]u8 {
        try validateNoteInput(input);
        const counter = self.counter;
        self.counter += 1;
        const id = try std.fmt.allocPrint(self.allocator, "note-{d}-{d}", .{
            @as(i64, @intCast(c.time(null))),
            counter,
        });
        errdefer self.counter = counter;
        defer self.allocator.free(id);
        const note = try self.makeNote(id, input);
        self.notes.append(self.allocator, note) catch |err| {
            self.freeNote(note);
            return err;
        };
        self.persist() catch |err| {
            _ = self.notes.pop();
            self.counter = counter;
            self.freeNote(note);
            return err;
        };
        return self.noteJson(self.notes.items.len - 1, allocator);
    }

    pub fn updateNote(self: *Storage, input: UpdateNoteInput, allocator: Allocator) ![:0]u8 {
        try validateUpdateInput(input);
        const index = self.findNote(input.id) orelse return error.NoteNotFound;
        const old = self.notes.items[index];
        const replacement = try self.makeNote(old.id, .{
            .title = input.title,
            .tag = input.tag,
            .body = input.body,
        });
        self.notes.items[index] = replacement;
        self.persist() catch |err| {
            self.notes.items[index] = old;
            self.freeNote(replacement);
            return err;
        };
        self.freeNote(old);
        return self.noteJson(index, allocator);
    }

    pub fn deleteNote(self: *Storage, id: []const u8) !void {
        if (id.len == 0) return error.NoteIdEmpty;
        const index = self.findNote(id) orelse return error.NoteNotFound;
        const old = self.notes.orderedRemove(index);
        self.persist() catch |err| {
            self.notes.insert(self.allocator, index, old) catch {
                self.freeNote(old);
                return error.StorageWriteFailed;
            };
            return err;
        };
        self.freeNote(old);
    }

    fn findNote(self: *Storage, id: []const u8) ?usize {
        for (self.notes.items, 0..) |note, index| {
            if (std.mem.eql(u8, note.id, id)) return index;
        }
        return null;
    }

    fn makeNote(self: *Storage, id: []const u8, input: NoteInput) !Note {
        const owned_id = try self.allocator.dupe(u8, id);
        errdefer self.allocator.free(owned_id);
        const title = try self.allocator.dupe(u8, input.title);
        errdefer self.allocator.free(title);
        const tag = try self.allocator.dupe(u8, if (input.tag.len == 0) "Draft" else input.tag);
        errdefer self.allocator.free(tag);
        const updated = try self.allocator.dupe(u8, "Just now");
        errdefer self.allocator.free(updated);
        const body = try self.allocator.dupe(u8, input.body);
        return .{ .id = owned_id, .title = title, .tag = tag, .updated = updated, .body = body };
    }

    fn noteJson(self: *Storage, index: usize, allocator: Allocator) ![:0]u8 {
        var output: std.Io.Writer.Allocating = .init(allocator);
        defer output.deinit();
        var stringify: std.json.Stringify = .{ .writer = &output.writer };
        try stringify.write(self.notes.items[index]);
        return allocator.dupeZ(u8, output.written());
    }
};

fn validateNoteInput(input: NoteInput) Error!void {
    if (std.mem.trim(u8, input.title, " \t\r\n").len == 0) return error.NoteTitleEmpty;
    if (input.title.len > max_title_bytes) return error.NoteTitleTooLong;
    if (input.tag.len > max_tag_bytes) return error.NoteTagTooLong;
    if (input.body.len > max_body_bytes) return error.NoteBodyTooLong;
}

fn validateUpdateInput(input: UpdateNoteInput) Error!void {
    if (input.id.len == 0) return error.NoteIdEmpty;
    if (input.id.len > max_id_bytes) return error.NoteIdTooLong;
    return validateNoteInput(.{ .title = input.title, .tag = input.tag, .body = input.body });
}

pub fn errorCode(err: anyerror) []const u8 {
    return switch (err) {
        error.StorageUnavailable => "StorageUnavailable",
        error.StorageCorrupt => "StorageCorrupt",
        error.StorageUnsupportedVersion => "StorageUnsupportedVersion",
        error.StorageReadFailed => "StorageReadFailed",
        error.StorageWriteFailed => "StorageWriteFailed",
        error.NoteNotFound => "NoteNotFound",
        error.NoteIdEmpty => "NoteIdEmpty",
        error.NoteIdTooLong => "NoteIdTooLong",
        error.NoteTitleEmpty => "NoteTitleEmpty",
        error.NoteTitleTooLong => "NoteTitleTooLong",
        error.NoteTagTooLong => "NoteTagTooLong",
        error.NoteBodyTooLong => "NoteBodyTooLong",
        else => "StorageError",
    };
}

pub fn errorMessage(err: anyerror) []const u8 {
    return switch (err) {
        error.StorageUnavailable => "persistent storage is unavailable",
        error.StorageCorrupt => "persistent state is corrupt",
        error.StorageUnsupportedVersion => "persistent state uses an unsupported schema",
        error.StorageReadFailed => "persistent state could not be read",
        error.StorageWriteFailed => "persistent state could not be written",
        error.NoteNotFound => "the requested note was not found",
        error.NoteIdEmpty => "note id is required",
        error.NoteIdTooLong => "note id is too long",
        error.NoteTitleEmpty => "note title is required",
        error.NoteTitleTooLong => "note title is too long",
        error.NoteTagTooLong => "note tag is too long",
        error.NoteBodyTooLong => "note body is too long",
        error.InvalidNoteArguments => "note arguments are invalid",
        else => "storage operation failed",
    };
}

test "note input validation protects storage limits" {
    try validateNoteInput(.{ .title = "Title", .tag = "Draft", .body = "Body" });
    try std.testing.expectError(error.NoteTitleEmpty, validateNoteInput(.{ .title = "", .tag = "", .body = "" }));
    try std.testing.expectError(error.NoteTitleTooLong, validateNoteInput(.{ .title = &([_]u8{'x'} ** (max_title_bytes + 1)), .tag = "", .body = "" }));
    try std.testing.expectEqualStrings("NoteNotFound", errorCode(error.NoteNotFound));
    try std.testing.expectEqualStrings("persistent state could not be written", errorMessage(error.StorageWriteFailed));
}

test "storage CRUD survives reload" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const cwd = try std.process.currentPathAlloc(io, allocator);
    defer allocator.free(cwd);
    const data_dir = try std.fs.path.join(allocator, &.{ cwd, ".zig-cache", "tmp", &tmp.sub_path });
    defer allocator.free(data_dir);

    var storage = try Storage.initAt(allocator, data_dir);
    const created = try storage.createNote(.{
        .title = "First note",
        .tag = "Draft",
        .body = "Write something useful.",
    }, allocator);
    defer allocator.free(created);
    try std.testing.expect(std.mem.indexOf(u8, created, "First note") != null);

    const parsed = try std.json.parseFromSlice(Note, allocator, created, .{});
    defer parsed.deinit();
    const id = try allocator.dupe(u8, parsed.value.id);
    defer allocator.free(id);

    const updated = try storage.updateNote(.{
        .id = id,
        .title = "Updated note",
        .tag = "Saved",
        .body = "Changed content.",
    }, allocator);
    defer allocator.free(updated);
    try std.testing.expect(std.mem.indexOf(u8, updated, "Updated note") != null);

    try storage.deleteNote(id);
    const empty = try storage.listNotes(allocator);
    defer allocator.free(empty);
    try std.testing.expectEqualStrings("[]", empty);
    storage.deinit();

    var reloaded = try Storage.initAt(allocator, data_dir);
    defer reloaded.deinit();
    const persisted_empty = try reloaded.listNotes(allocator);
    defer allocator.free(persisted_empty);
    try std.testing.expectEqualStrings("[]", persisted_empty);
}
