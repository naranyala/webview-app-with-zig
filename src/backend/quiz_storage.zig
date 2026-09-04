const std = @import("std");
const c = @cImport({
    @cInclude("time.h");
});

const Allocator = std.mem.Allocator;
const io = std.Options.debug_io;

// Native quiz-deck store, ported from webview-app-with-vlang
// (`quiz_storage.v`) and adapted to this codebase's conventions:
//   - Same limits: schema v1, 1000 collections, 500 questions each,
//     20000 text bytes. Question shape is a superset (keeps this
//     frontend's explanation/difficulty/tags alongside V's topic).
//   - Lives next to the notes store (`quizzes.json` in the same data dir)
//     instead of the OS config dir, so backup is one folder.
//   - No mutex: all bridge calls run on the main WebView thread. Revisit
//     together with worker-thread support (see TODOS.md).
//   - std-only module with no app imports, so it can move into a shared
//     C/ABI library later without untangling dependencies.
pub const schema_version: u32 = 1;
pub const max_state_bytes: usize = 8 * 1024 * 1024;
pub const max_collections: usize = 1000;
pub const max_questions: usize = 500;
pub const max_text_bytes: usize = 20000;
pub const max_title_bytes: usize = 200;
pub const max_id_bytes: usize = 200;
pub const max_topic_bytes: usize = 200;
pub const max_difficulty_bytes: usize = 64;
pub const max_tag_bytes: usize = 64;
pub const max_tags: usize = 16;

pub const Error = error{
    QuizUnavailable,
    QuizCorrupt,
    QuizUnsupportedVersion,
    QuizReadFailed,
    QuizWriteFailed,
    QuizNotFound,
    QuizLimitReached,
    QuizIdEmpty,
    QuizIdTooLong,
    QuizTitleEmpty,
    QuizTitleTooLong,
    QuizTextEmpty,
    QuizTextTooLong,
    QuizTagTooLong,
    QuizTooManyTags,
};

pub const QuizQuestion = struct {
    id: []const u8,
    topic: []const u8 = "",
    question: []const u8,
    answer: []const u8,
    explanation: []const u8 = "",
    difficulty: []const u8 = "",
    tags: [][]const u8 = &.{},
};

pub const QuizCollection = struct {
    id: []const u8,
    title: []const u8,
    shortTitle: []const u8 = "",
    description: []const u8 = "",
    tone: []const u8 = "gold",
    icon: []const u8 = "",
    level: []const u8 = "Custom",
    questions: []QuizQuestion = &.{},
};

const Document = struct {
    version: u32 = schema_version,
    counter: u64 = 0,
    collections: []QuizCollection = &.{},
};

pub const CollectionInput = struct {
    title: []const u8,
    description: []const u8,
    tone: []const u8,
    level: []const u8,
};

pub const UpdateCollectionInput = struct {
    id: []const u8,
    title: []const u8,
    description: []const u8,
};

pub const QuestionInput = struct {
    collection_id: []const u8,
    topic: []const u8,
    question: []const u8,
    answer: []const u8,
};

pub const UpdateQuestionInput = struct {
    collection_id: []const u8,
    id: []const u8,
    topic: []const u8,
    question: []const u8,
    answer: []const u8,
    explanation: []const u8,
    difficulty: []const u8,
    tags_csv: []const u8,
};

pub const DeleteQuestionInput = struct {
    collection_id: []const u8,
    id: []const u8,
};

pub const QuizStore = struct {
    allocator: Allocator,
    file_path: []u8,
    collections: std.ArrayList(QuizCollection) = .empty,
    counter: u64 = 0,

    pub fn init(allocator: Allocator) !QuizStore {
        const storage = @import("storage.zig");
        const data_dir = storage.resolveDataDir(allocator) catch return error.QuizUnavailable;
        defer allocator.free(data_dir);
        const file_path = std.fs.path.join(allocator, &.{ data_dir, "quizzes.json" }) catch return error.QuizUnavailable;
        defer allocator.free(file_path);
        return initAt(allocator, file_path);
    }

    pub fn initAt(allocator: Allocator, file_path: []const u8) !QuizStore {
        var store: QuizStore = .{
            .allocator = allocator,
            .file_path = try allocator.dupe(u8, file_path),
        };
        errdefer store.deinit();
        store.load() catch |err| switch (err) {
            error.FileNotFound => {},
            else => return err,
        };
        return store;
    }

    pub fn deinit(self: *QuizStore) void {
        for (self.collections.items) |collection| self.freeCollection(collection);
        self.collections.deinit(self.allocator);
        self.allocator.free(self.file_path);
    }

    fn freeCollection(self: *QuizStore, collection: QuizCollection) void {
        self.allocator.free(collection.id);
        self.allocator.free(collection.title);
        self.allocator.free(collection.shortTitle);
        self.allocator.free(collection.description);
        self.allocator.free(collection.tone);
        self.allocator.free(collection.icon);
        self.allocator.free(collection.level);
        for (collection.questions) |question| self.freeQuestion(question);
        self.allocator.free(collection.questions);
    }

    fn freeQuestion(self: *QuizStore, question: QuizQuestion) void {
        self.allocator.free(question.id);
        self.allocator.free(question.topic);
        self.allocator.free(question.question);
        self.allocator.free(question.answer);
        self.allocator.free(question.explanation);
        self.allocator.free(question.difficulty);
        for (question.tags) |tag| self.allocator.free(tag);
        self.allocator.free(question.tags);
    }

    fn load(self: *QuizStore) !void {
        const root = std.Io.Dir.cwd();
        const bytes = root.readFileAlloc(io, self.file_path, self.allocator, .limited(max_state_bytes)) catch |err| switch (err) {
            error.FileNotFound => return error.FileNotFound,
            else => return error.QuizReadFailed,
        };
        defer self.allocator.free(bytes);

        const parsed = std.json.parseFromSlice(Document, self.allocator, bytes, .{}) catch {
            return error.QuizCorrupt;
        };
        defer parsed.deinit();
        if (parsed.value.version != schema_version) return error.QuizUnsupportedVersion;
        self.counter = parsed.value.counter;

        for (parsed.value.collections) |collection| {
            try validateStoredCollection(collection);
            try self.collections.append(self.allocator, try self.cloneCollection(collection));
        }
    }

    fn serialize(self: *QuizStore, allocator: Allocator) ![:0]u8 {
        var output: std.Io.Writer.Allocating = .init(allocator);
        defer output.deinit();
        var stringify: std.json.Stringify = .{ .writer = &output.writer };
        try stringify.write(Document{
            .version = schema_version,
            .counter = self.counter,
            .collections = self.collections.items,
        });
        return allocator.dupeZ(u8, output.written());
    }

    fn persist(self: *QuizStore) !void {
        const parent = std.fs.path.dirname(self.file_path) orelse return error.QuizWriteFailed;
        try std.Io.Dir.cwd().createDirPath(io, parent);
        var dir = std.Io.Dir.openDirAbsolute(io, parent, .{}) catch return error.QuizWriteFailed;
        defer dir.close(io);

        const base = std.fs.path.basename(self.file_path);
        const data = self.serialize(self.allocator) catch return error.QuizWriteFailed;
        defer self.allocator.free(data);

        var atomic = dir.createFileAtomic(io, base, .{ .replace = true }) catch return error.QuizWriteFailed;
        defer atomic.deinit(io);
        var buffer: [4096]u8 = undefined;
        var writer = atomic.file.writer(io, &buffer);
        writer.interface.writeAll(data) catch return error.QuizWriteFailed;
        writer.flush() catch return error.QuizWriteFailed;
        atomic.replace(io) catch return error.QuizWriteFailed;
    }

    fn nextId(self: *QuizStore, prefix: []const u8) ![]u8 {
        const id = try std.fmt.allocPrint(self.allocator, "{s}-{d}-{d}", .{
            prefix,
            @as(i64, @intCast(c.time(null))),
            self.counter,
        });
        self.counter += 1;
        return id;
    }

    fn findCollection(self: *QuizStore, id: []const u8) ?usize {
        for (self.collections.items, 0..) |collection, index| {
            if (std.mem.eql(u8, collection.id, id)) return index;
        }
        return null;
    }

    fn findQuestion(collection: QuizCollection, id: []const u8) ?usize {
        for (collection.questions, 0..) |question, index| {
            if (std.mem.eql(u8, question.id, id)) return index;
        }
        return null;
    }

    pub fn listCollections(self: *QuizStore, allocator: Allocator) ![:0]u8 {
        var output: std.Io.Writer.Allocating = .init(allocator);
        defer output.deinit();
        var stringify: std.json.Stringify = .{ .writer = &output.writer };
        try stringify.write(self.collections.items);
        return allocator.dupeZ(u8, output.written());
    }

    pub fn createCollection(self: *QuizStore, input: CollectionInput, allocator: Allocator) ![:0]u8 {
        try validateCollectionInput(input);
        if (self.collections.items.len >= max_collections) return error.QuizLimitReached;
        const id = try self.nextId("quiz-col");
        defer self.allocator.free(id);
        const collection = try self.makeCollection(id, input);
        self.collections.append(self.allocator, collection) catch |err| {
            self.freeCollection(collection);
            return err;
        };
        self.persist() catch |err| {
            const rollback = self.collections.pop().?;
            self.freeCollection(rollback);
            return err;
        };
        return self.collectionJson(self.collections.items.len - 1, allocator);
    }

    pub fn updateCollection(self: *QuizStore, input: UpdateCollectionInput, allocator: Allocator) ![:0]u8 {
        if (input.id.len == 0) return error.QuizIdEmpty;
        if (input.id.len > max_id_bytes) return error.QuizIdTooLong;
        if (std.mem.trim(u8, input.title, " \t\r\n").len == 0) return error.QuizTitleEmpty;
        if (input.title.len > max_title_bytes) return error.QuizTitleTooLong;
        if (input.description.len > max_text_bytes) return error.QuizTextTooLong;
        const index = self.findCollection(input.id) orelse return error.QuizNotFound;
        const old = self.collections.items[index];
        const title = try self.allocator.dupe(u8, input.title);
        errdefer self.allocator.free(title);
        const description = try self.allocator.dupe(u8, input.description);
        errdefer self.allocator.free(description);
        const replacement = QuizCollection{
            .id = old.id,
            .title = title,
            .shortTitle = old.shortTitle,
            .description = description,
            .tone = old.tone,
            .icon = old.icon,
            .level = old.level,
            .questions = old.questions,
        };
        self.collections.items[index] = replacement;
        self.persist() catch |err| {
            self.collections.items[index] = old;
            self.allocator.free(title);
            self.allocator.free(description);
            return err;
        };
        self.allocator.free(old.title);
        self.allocator.free(old.description);
        return self.collectionJson(index, allocator);
    }

    pub fn deleteCollection(self: *QuizStore, id: []const u8) !void {
        if (id.len == 0) return error.QuizIdEmpty;
        const index = self.findCollection(id) orelse return error.QuizNotFound;
        const old = self.collections.orderedRemove(index);
        self.persist() catch |err| {
            self.collections.insert(self.allocator, index, old) catch {
                self.freeCollection(old);
                return error.QuizWriteFailed;
            };
            return err;
        };
        self.freeCollection(old);
    }

    pub fn createQuestion(self: *QuizStore, input: QuestionInput, allocator: Allocator) ![:0]u8 {
        try validateQuestionInput(input);
        const index = self.findCollection(input.collection_id) orelse return error.QuizNotFound;
        var collection = self.collections.items[index];
        if (collection.questions.len >= max_questions) return error.QuizLimitReached;
        const id = try self.nextId("quiz-q");
        defer self.allocator.free(id);
        const question = try self.makeQuestion(id, .{
            .topic = input.topic,
            .question = input.question,
            .answer = input.answer,
            .explanation = "",
            .difficulty = "",
        }, &.{});
        collection.questions = self.allocator.realloc(collection.questions, collection.questions.len + 1) catch |err| {
            self.freeQuestion(question);
            return err;
        };
        collection.questions[collection.questions.len - 1] = question;
        self.collections.items[index] = collection;
        self.persist() catch |err| {
            const grown = self.collections.items[index].questions;
            self.collections.items[index].questions = self.allocator.realloc(
                grown,
                grown.len - 1,
            ) catch grown[0 .. grown.len - 1];
            self.freeQuestion(question);
            return err;
        };
        return self.questionJson(index, collection.questions.len - 1, allocator);
    }

    pub fn updateQuestion(self: *QuizStore, input: UpdateQuestionInput, allocator: Allocator) ![:0]u8 {
        try validateUpdateQuestionInput(input);
        const index = self.findCollection(input.collection_id) orelse return error.QuizNotFound;
        const collection = self.collections.items[index];
        const question_index = findQuestion(collection, input.id) orelse return error.QuizNotFound;
        const old = collection.questions[question_index];
        const replacement = try self.makeQuestion(old.id, .{
            .topic = input.topic,
            .question = input.question,
            .answer = input.answer,
            .explanation = input.explanation,
            .difficulty = input.difficulty,
        }, input.tags_csv);
        self.collections.items[index].questions[question_index] = replacement;
        self.persist() catch |err| {
            self.collections.items[index].questions[question_index] = old;
            self.freeQuestion(replacement);
            return err;
        };
        self.freeQuestion(old);
        return self.questionJson(index, question_index, allocator);
    }

    pub fn deleteQuestion(self: *QuizStore, collection_id: []const u8, id: []const u8) !void {
        if (id.len == 0) return error.QuizIdEmpty;
        const index = self.findCollection(collection_id) orelse return error.QuizNotFound;
        const question_index = findQuestion(self.collections.items[index], id) orelse return error.QuizNotFound;
        const questions = self.collections.items[index].questions;
        const old = questions[question_index];
        std.mem.copyForwards(
            QuizQuestion,
            questions[question_index .. questions.len - 1],
            questions[question_index + 1 ..],
        );
        const shrunk = self.allocator.realloc(questions, questions.len - 1) catch |realloc_err| {
            std.mem.copyBackwards(
                QuizQuestion,
                questions[question_index + 1 .. questions.len],
                questions[question_index .. questions.len - 1],
            );
            questions[question_index] = old;
            return realloc_err;
        };
        self.collections.items[index].questions = shrunk;
        self.persist() catch |err| {
            const restored = self.allocator.realloc(shrunk, shrunk.len + 1) catch {
                self.freeQuestion(old);
                return error.QuizWriteFailed;
            };
            std.mem.copyBackwards(
                QuizQuestion,
                restored[question_index + 1 .. restored.len],
                restored[question_index .. restored.len - 1],
            );
            restored[question_index] = old;
            self.collections.items[index].questions = restored;
            return err;
        };
        self.freeQuestion(old);
    }

    fn makeCollection(self: *QuizStore, id: []const u8, input: CollectionInput) !QuizCollection {
        const owned_id = try self.allocator.dupe(u8, id);
        errdefer self.allocator.free(owned_id);
        const title = try self.allocator.dupe(u8, input.title);
        errdefer self.allocator.free(title);
        const description = try self.allocator.dupe(u8, input.description);
        errdefer self.allocator.free(description);
        const tone = try self.allocator.dupe(u8, if (input.tone.len == 0) "gold" else input.tone);
        errdefer self.allocator.free(tone);
        const level = try self.allocator.dupe(u8, if (input.level.len == 0) "Custom" else input.level);
        errdefer self.allocator.free(level);
        const short_title = try self.allocator.dupe(u8, input.title);
        return .{
            .id = owned_id,
            .title = title,
            .shortTitle = short_title,
            .description = description,
            .tone = tone,
            .icon = try self.allocator.dupe(u8, ""),
            .level = level,
            .questions = &.{},
        };
    }

    const QuestionFields = struct {
        topic: []const u8,
        question: []const u8,
        answer: []const u8,
        explanation: []const u8,
        difficulty: []const u8,
    };

    fn makeQuestion(self: *QuizStore, id: []const u8, fields: QuestionFields, tags_csv: []const u8) !QuizQuestion {
        const owned_id = try self.allocator.dupe(u8, id);
        errdefer self.allocator.free(owned_id);
        const topic = try self.allocator.dupe(u8, fields.topic);
        errdefer self.allocator.free(topic);
        const question = try self.allocator.dupe(u8, fields.question);
        errdefer self.allocator.free(question);
        const answer = try self.allocator.dupe(u8, fields.answer);
        errdefer self.allocator.free(answer);
        const explanation = try self.allocator.dupe(u8, fields.explanation);
        errdefer self.allocator.free(explanation);
        const difficulty = try self.allocator.dupe(u8, fields.difficulty);
        errdefer self.allocator.free(difficulty);
        const tags = try parseTags(self.allocator, tags_csv);
        return .{
            .id = owned_id,
            .topic = topic,
            .question = question,
            .answer = answer,
            .explanation = explanation,
            .difficulty = difficulty,
            .tags = tags,
        };
    }

    fn cloneCollection(self: *QuizStore, source: QuizCollection) !QuizCollection {
        const id = try self.allocator.dupe(u8, source.id);
        errdefer self.allocator.free(id);
        const title = try self.allocator.dupe(u8, source.title);
        errdefer self.allocator.free(title);
        const short_title = try self.allocator.dupe(u8, source.shortTitle);
        errdefer self.allocator.free(short_title);
        const description = try self.allocator.dupe(u8, source.description);
        errdefer self.allocator.free(description);
        const tone = try self.allocator.dupe(u8, source.tone);
        errdefer self.allocator.free(tone);
        const icon = try self.allocator.dupe(u8, source.icon);
        errdefer self.allocator.free(icon);
        const level = try self.allocator.dupe(u8, source.level);
        errdefer self.allocator.free(level);
        const questions = try self.allocator.alloc(QuizQuestion, source.questions.len);
        errdefer self.allocator.free(questions);
        for (source.questions, 0..) |question, i| {
            questions[i] = try self.cloneQuestion(question);
        }
        return .{
            .id = id,
            .title = title,
            .shortTitle = short_title,
            .description = description,
            .tone = tone,
            .icon = icon,
            .level = level,
            .questions = questions,
        };
    }

    fn cloneQuestion(self: *QuizStore, source: QuizQuestion) !QuizQuestion {
        const id = try self.allocator.dupe(u8, source.id);
        errdefer self.allocator.free(id);
        const topic = try self.allocator.dupe(u8, source.topic);
        errdefer self.allocator.free(topic);
        const question = try self.allocator.dupe(u8, source.question);
        errdefer self.allocator.free(question);
        const answer = try self.allocator.dupe(u8, source.answer);
        errdefer self.allocator.free(answer);
        const explanation = try self.allocator.dupe(u8, source.explanation);
        errdefer self.allocator.free(explanation);
        const difficulty = try self.allocator.dupe(u8, source.difficulty);
        errdefer self.allocator.free(difficulty);
        const tags = try self.allocator.alloc([]const u8, source.tags.len);
        errdefer self.allocator.free(tags);
        for (source.tags, 0..) |tag, i| {
            tags[i] = try self.allocator.dupe(u8, tag);
        }
        return .{
            .id = id,
            .topic = topic,
            .question = question,
            .answer = answer,
            .explanation = explanation,
            .difficulty = difficulty,
            .tags = tags,
        };
    }

    fn collectionJson(self: *QuizStore, index: usize, allocator: Allocator) ![:0]u8 {
        var output: std.Io.Writer.Allocating = .init(allocator);
        defer output.deinit();
        var stringify: std.json.Stringify = .{ .writer = &output.writer };
        try stringify.write(self.collections.items[index]);
        return allocator.dupeZ(u8, output.written());
    }

    fn questionJson(self: *QuizStore, collection_index: usize, question_index: usize, allocator: Allocator) ![:0]u8 {
        var output: std.Io.Writer.Allocating = .init(allocator);
        defer output.deinit();
        var stringify: std.json.Stringify = .{ .writer = &output.writer };
        try stringify.write(self.collections.items[collection_index].questions[question_index]);
        return allocator.dupeZ(u8, output.written());
    }
};

fn parseTags(allocator: Allocator, csv: []const u8) ![][]const u8 {
    var tags: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (tags.items) |tag| allocator.free(tag);
        tags.deinit(allocator);
    }
    var parts = std.mem.splitScalar(u8, csv, ',');
    while (parts.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " \t\r\n");
        if (trimmed.len == 0) continue;
        if (trimmed.len > max_tag_bytes) return error.QuizTagTooLong;
        if (tags.items.len >= max_tags) return error.QuizTooManyTags;
        try tags.append(allocator, try allocator.dupe(u8, trimmed));
    }
    return tags.toOwnedSlice(allocator);
}

fn validateCollectionInput(input: CollectionInput) Error!void {
    if (std.mem.trim(u8, input.title, " \t\r\n").len == 0) return error.QuizTitleEmpty;
    if (input.title.len > max_title_bytes) return error.QuizTitleTooLong;
    if (input.description.len > max_text_bytes) return error.QuizTextTooLong;
    if (input.tone.len > max_topic_bytes) return error.QuizTextTooLong;
    if (input.level.len > max_topic_bytes) return error.QuizTextTooLong;
}

fn validateQuestionInput(input: QuestionInput) Error!void {
    if (input.collection_id.len == 0) return error.QuizIdEmpty;
    if (input.collection_id.len > max_id_bytes) return error.QuizIdTooLong;
    if (std.mem.trim(u8, input.question, " \t\r\n").len == 0) return error.QuizTextEmpty;
    if (std.mem.trim(u8, input.answer, " \t\r\n").len == 0) return error.QuizTextEmpty;
    if (input.topic.len > max_topic_bytes) return error.QuizTextTooLong;
    if (input.question.len > max_text_bytes) return error.QuizTextTooLong;
    if (input.answer.len > max_text_bytes) return error.QuizTextTooLong;
}

fn validateUpdateQuestionInput(input: UpdateQuestionInput) Error!void {
    if (input.id.len == 0) return error.QuizIdEmpty;
    if (input.id.len > max_id_bytes) return error.QuizIdTooLong;
    if (input.difficulty.len > max_difficulty_bytes) return error.QuizTextTooLong;
    if (input.explanation.len > max_text_bytes) return error.QuizTextTooLong;
    return validateQuestionInput(.{
        .collection_id = input.collection_id,
        .topic = input.topic,
        .question = input.question,
        .answer = input.answer,
    });
}

fn validateStoredCollection(collection: QuizCollection) Error!void {
    if (collection.id.len == 0 or collection.id.len > max_id_bytes) return error.QuizCorrupt;
    if (collection.title.len == 0 or collection.title.len > max_title_bytes) return error.QuizCorrupt;
    if (collection.questions.len > max_questions) return error.QuizCorrupt;
    for (collection.questions) |question| {
        if (question.id.len == 0 or question.question.len == 0 or question.answer.len == 0) {
            return error.QuizCorrupt;
        }
    }
}

pub fn errorCode(err: anyerror) []const u8 {
    return switch (err) {
        error.QuizUnavailable => "QuizUnavailable",
        error.QuizCorrupt => "QuizCorrupt",
        error.QuizUnsupportedVersion => "QuizUnsupportedVersion",
        error.QuizReadFailed => "QuizReadFailed",
        error.QuizWriteFailed => "QuizWriteFailed",
        error.QuizNotFound => "QuizNotFound",
        error.QuizLimitReached => "QuizLimitReached",
        error.QuizIdEmpty => "QuizIdEmpty",
        error.QuizIdTooLong => "QuizIdTooLong",
        error.QuizTitleEmpty => "QuizTitleEmpty",
        error.QuizTitleTooLong => "QuizTitleTooLong",
        error.QuizTextEmpty => "QuizTextEmpty",
        error.QuizTextTooLong => "QuizTextTooLong",
        error.QuizTagTooLong => "QuizTagTooLong",
        error.QuizTooManyTags => "QuizTooManyTags",
        else => "QuizError",
    };
}

pub fn errorMessage(err: anyerror) []const u8 {
    return switch (err) {
        error.QuizUnavailable => "quiz storage is unavailable",
        error.QuizCorrupt => "quiz data is corrupt",
        error.QuizUnsupportedVersion => "quiz data uses an unsupported schema",
        error.QuizReadFailed => "quiz data could not be read",
        error.QuizWriteFailed => "quiz data could not be written",
        error.QuizNotFound => "the requested quiz item was not found",
        error.QuizLimitReached => "the quiz storage limit was reached",
        error.QuizIdEmpty => "quiz id is required",
        error.QuizIdTooLong => "quiz id is too long",
        error.QuizTitleEmpty => "collection title is required",
        error.QuizTitleTooLong => "collection title is too long",
        error.QuizTextEmpty => "question and answer are required",
        error.QuizTextTooLong => "quiz text is too long",
        error.QuizTagTooLong => "quiz tag is too long",
        error.QuizTooManyTags => "too many quiz tags",
        else => "quiz operation failed",
    };
}

test "quiz input validation protects limits" {
    try validateCollectionInput(.{ .title = "T", .description = "", .tone = "", .level = "" });
    try std.testing.expectError(error.QuizTitleEmpty, validateCollectionInput(.{ .title = "  ", .description = "", .tone = "", .level = "" }));
    try std.testing.expectError(
        error.QuizTextEmpty,
        validateQuestionInput(.{ .collection_id = "c", .topic = "", .question = "", .answer = "a" }),
    );
    try std.testing.expectEqualStrings("QuizNotFound", errorCode(error.QuizNotFound));
    try std.testing.expectEqualStrings("quiz data could not be written", errorMessage(error.QuizWriteFailed));
}

test "quiz tags parse from csv" {
    const allocator = std.testing.allocator;
    const tags = try parseTags(allocator, " alpha,beta ,, gamma ");
    defer {
        for (tags) |tag| allocator.free(tag);
        allocator.free(tags);
    }
    try std.testing.expectEqual(@as(usize, 3), tags.len);
    try std.testing.expectEqualStrings("alpha", tags[0]);
    try std.testing.expectError(error.QuizTagTooLong, parseTags(allocator, &([_]u8{'x'} ** (max_tag_bytes + 1))));
}

test "quiz CRUD survives reload" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const cwd = try std.process.currentPathAlloc(io, allocator);
    defer allocator.free(cwd);
    const file_path = try std.fs.path.join(allocator, &.{ cwd, ".zig-cache", "tmp", &tmp.sub_path, "quizzes.json" });
    defer allocator.free(file_path);

    var store = try QuizStore.initAt(allocator, file_path);
    const created = try store.createCollection(.{
        .title = "Zig Basics",
        .description = "First deck",
        .tone = "gold",
        .level = "Custom",
    }, allocator);
    defer allocator.free(created);
    try std.testing.expect(std.mem.indexOf(u8, created, "Zig Basics") != null);

    const parsed = try std.json.parseFromSlice(QuizCollection, allocator, created, .{});
    defer parsed.deinit();
    const id = try allocator.dupe(u8, parsed.value.id);
    defer allocator.free(id);

    const question = try store.createQuestion(.{
        .collection_id = id,
        .topic = "General",
        .question = "What is Zig?",
        .answer = "A systems language.",
    }, allocator);
    defer allocator.free(question);

    const question_parsed = try std.json.parseFromSlice(QuizQuestion, allocator, question, .{});
    defer question_parsed.deinit();
    const question_id = try allocator.dupe(u8, question_parsed.value.id);
    defer allocator.free(question_id);

    const updated = try store.updateQuestion(.{
        .collection_id = id,
        .id = question_id,
        .topic = "General",
        .question = "What is Zig?",
        .answer = "A systems programming language.",
        .explanation = "Low-level control.",
        .difficulty = "Starter",
        .tags_csv = "systems, languages",
    }, allocator);
    defer allocator.free(updated);
    try std.testing.expect(std.mem.indexOf(u8, updated, "systems programming") != null);

    try store.deleteQuestion(id, question_id);
    try store.deleteCollection(id);
    const empty = try store.listCollections(allocator);
    defer allocator.free(empty);
    try std.testing.expectEqualStrings("[]", empty);
    store.deinit();

    var reloaded = try QuizStore.initAt(allocator, file_path);
    defer reloaded.deinit();
    const persisted_empty = try reloaded.listCollections(allocator);
    defer allocator.free(persisted_empty);
    try std.testing.expectEqualStrings("[]", persisted_empty);
}

test "quiz rejects unknown collections" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const cwd = try std.process.currentPathAlloc(io, allocator);
    defer allocator.free(cwd);
    const file_path = try std.fs.path.join(allocator, &.{ cwd, ".zig-cache", "tmp", &tmp.sub_path, "missing.json" });
    defer allocator.free(file_path);

    var store = try QuizStore.initAt(allocator, file_path);
    defer store.deinit();
    try std.testing.expectError(
        error.QuizNotFound,
        store.deleteCollection("quiz-col-0-0"),
    );
    try std.testing.expectError(
        error.QuizNotFound,
        store.createQuestion(.{
            .collection_id = "quiz-col-0-0",
            .topic = "",
            .question = "Q",
            .answer = "A",
        }, allocator),
    );
}
