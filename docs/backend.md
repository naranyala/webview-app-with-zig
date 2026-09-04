# Backend

Zig backend: a `webview` host with RPCs grouped into plugins, versioned JSON
note and quiz stores, validated PDF saving, and leveled logging.

## Modules

| File | Responsibility |
| --- | --- |
| `src/main.zig` | `Context` RPC handlers, window setup, plugin registration |
| `src/backend.zig` | Argument parsing, error envelopes, `savePdf` file flow |
| `src/backend/core_plugin.zig` | Binding registration + canonical `bound_names` (21) |
| `src/backend/plugin.zig` | `PluginRegistry`: dedupe validation, ordered `registerAll`, `deinitAll`, enable/disable + lifecycle hooks |
| `src/backend/storage.zig` | `Storage`: data-dir resolution, atomic `state.json`, note CRUD, validation, reload tests |
| `src/backend/quiz_storage.zig` | `QuizStore`: atomic `quizzes.json`, collection/question CRUD, validation, reload tests |
| `src/backend/log.zig` | `Level` logging; debug gated on build config |
| `src/config.zig` | Window title/size, devtools flag, dev-server URL |

## Bindings (21)

`window.*` functions bound in `core_plugin.zig`, typed in
`frontend-preact/src/bindings.d.ts`, wrapped in `frontend-preact/src/backend.js`
(with client-side validation, timeouts, and browser mocks):

| Binding | Args | Returns |
| --- | --- | --- |
| `increment` | integer delta | count |
| `reset` | — | count |
| `getSystemInfo` / `getTimestamp` / `getStatus` | — | string |
| `getNotes` | — | `Note[]` |
| `createNote` / `updateNote` | title, tag, body (+ id) | `Note` |
| `deleteNote` | id | void |
| `savePdf` | filename, base64 data | `{ path }` |
| `quizList` | — | `QuizCollection[]` |
| `quizCreateCollection` | title, description, tone, level | `QuizCollection` |
| `quizUpdateCollection` | id, title, description | `QuizCollection` |
| `quizDeleteCollection` | id | void |
| `quizCreateQuestion` | collection id, topic, question, answer | `QuizQuestion` |
| `quizUpdateQuestion` | collection id, id, topic, question, answer, explanation, difficulty, tags CSV | `QuizQuestion` |
| `quizDeleteQuestion` | collection id, id | void |
| `minimizeWindow` / `maximizeWindow` / `restoreWindow` / `closeWindow` | — | void |

Failures use stable `{code, message}` envelopes (`rejectWithCode`);
`check-bindings.cjs` fails CI if `bindings.d.ts` or `backend.js` drift from
`bound_names`.

## `savePdf` file flow

`savePdfToDocuments()` resolves the per-user Documents folder
(`~/Documents` on Linux/macOS, `%USERPROFILE%\Documents` on Windows) and
delegates to `savePdfToDir()`, which is injectable for hermetic tests:

- Filename: 5–100 chars, alphanumeric start, `[A-Za-z0-9._-]`, `.pdf` suffix.
- Payload: base64, ≤ ~22.4 M chars, decodes to ≤ 16 MiB.
- Directory is created as needed; existing names get `-2`, `-3`, … suffixes
  (up to 1000 attempts); writes are atomic (tmp file + rename).
- Returns `{"path": …}` with JSON-escaped path.
- Error codes: `InvalidPdfName`, `PdfTooLarge`, `PdfDecodeFailed`,
  `DocumentsUnavailable`, `PdfWriteFailed` — each with a display message and
  a frontend mirror in `backend.js`.

## Storage

Schema `{"version": 1, "counter": n, "notes": [...]}`. Limits: 4 MiB state
file, 200-char titles, 64-char tags, 512 KiB bodies. Corrupt files,
unsupported versions, and read/write failures map to distinct error codes.
`WEBVIEW_APP_DATA_DIR` overrides the data dir (used by tests and portable
deployments).

Quiz data is stored separately in `quizzes.json` in the same application data
directory. Its schema is `{ "version": 1, "counter": n, "collections": [...] }`.
Bundled quiz decks remain frontend assets and are read-only; user-created decks
and questions use the native store. The store enforces limits of 1000
collections, 500 questions per collection, 20,000-byte text fields, 16 tags per
question, and 64-byte tags. Quiz failures use `Quiz*` error codes and the same
`{code, message}` envelope as note and PDF operations.

## Adding a binding

1. Handler on `Context` in `src/main.zig` (parse with `parseRpcArgs` +
   typed parsers, `rejectRpcError` on failure, `resolveWith` on success).
2. `easy.bind(.name)` in `core_plugin.zig` + append to `bound_names`
   (uniqueness is unit-tested).
3. Type in `bindings.d.ts`, wrapper in `backend.js` (validate + mock).
4. Add the name to `check-bindings.cjs`.

## Linux install note

Workstations whose checkout lives on an NTFS/exFAT mount: Zig's atomic
install relies on hard-link syscalls those filesystems reject, and `chmod`
fails there too (files map to the mount owner). `build.zig` therefore
installs the Linux binary with `mkdir -p` + plain `cp` (the cached binary is
already executable; `cp` preserves that through the umask) while other
platforms keep `installArtifact`. Same output path (`zig-out/bin`).

## Linux libc note

Native builds set LLVM codegen for GCC-16/`R_X86_64_PC64` compatibility and
stage an isolated libc config: `tools/prepare-linux-libc.sh` copies (never
symlinks) the CRT objects plus static and shared system libraries into the
Zig cache and strips unsupported `.sframe` sections. See also
`tools/check-deps.sh` (used by CI) and `tools/install-frontend.sh`.
