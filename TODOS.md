# Development TODOs

This roadmap covers the planned backend, frontend, integration, and release work.

## Phase 0: Build Foundation

- [x] Resolve the Zig/GCC linker issue involving `R_X86_64_PC64` and `.sframe` by enabling LLVM code generation for the executable.
- [x] Document supported Zig, native compiler, GTK, and WebKitGTK requirements.
- [x] Replace `npm install` with `npm ci` in `build.zig` for reproducible builds.
- [x] Add a CI workflow covering frontend build, `biome check`, backend compilation, and `zig build test` (mirror `v run build.vsh test` in webview-app-with-vlang, which runs frontend checks + backend tests together). Implemented: `.github/workflows/ci.yml` (apt GTK/WebKit, Zig 0.16.0, Node 20, `tools/check-deps.sh`, `zig build test --summary all`, `zig build`). `zig build test` runs backend unit tests (`backend`, `config`, `plugin`, `log`, `core_plugin`) + `npm run check` + `npm run check:bindings`.
- [x] Document and automate installation of native dependencies (`zig-webview`, GTK/WebKitGTK, WebView2) so a clean machine can build without manual steps. Implemented: `tools/check-deps.sh` (zig/node/npm/pkg-config/gtk+-3.0/webkit2gtk-4.1) used by CI.

## Backend

The Disk Scanner and Audio Equalizer work is tracked in detail under
`Disk Scanner Implementation` and `Audio Equalizer Implementation` below;
the three items here are the integration milestones for that work.

- [ ] Finish Disk Scanner backend (volume discovery, scan lifecycle, worker threads) and replace the mock Disk Scanner data with backend RPC calls.
- [ ] Finish Audio Equalizer backend (device discovery, playback, DSP) and replace the mock Audio Equalizer controls with backend RPC calls.
- [ ] Extend Chain Notes persistence with reorder, Markdown/plain-text import, and PDF styling options. Create, update/rename, delete, search/filtering, and PDF export now use the backend note store.
- [x] Move `Context` state and backend operations out of `src/main.zig` into a separate module.
- [ ] Define a clear RPC API for frontend/backend communication. Evaluate a namespace (e.g. `window.backend.*`) instead of loose `window.*` functions, as suggested by webview-app-with-vlang Phase 2.
- [x] Add a health/status bridge method for frontend startup checks (cf. webview-app-with-vlang `get_time` / health-check idea). Implemented as `getStatus` (`backend.healthStatus()` + `statusPayload()`), bound in `core_plugin`, exposed via `frontend-preact/src/backend.js` + `bindings.d.ts`.
- [x] Add a backend plugin registry for cohesive RPC binding groups.
- [x] Add plugin lifecycle hooks (init/cleanup), capability/version metadata, and optional enable/disable config (cf. webview-app-with-vlang Plugin Architecture todos). Implemented in `src/backend/plugin.zig` (`name/version/description/enabled/onInit/onDeinit`, `registerAll` skips disabled, `deinitAll` for cleanup).
- [x] Replace manual JSON argument slicing in `increment()` with proper JSON parsing and validation.
- [ ] Replace `std.heap.page_allocator` in `increment()` with an arena or GPA: every RPC currently leaks its parsed arguments because the page allocator never frees.
- [ ] Return valid JSON from string RPCs (`getSystemInfo`, `healthStatus`, `getTimestamp`): `resolveWith` requires a JSON value, but bare tokens like `Linux` / `ok` are not valid JSON. Encode properly, then update frontend expectations and tests.
- [ ] Settle the `closeWindow` promise (resolve before terminate) so the frontend pending state clears; remove the unused `gtk_window_deiconify` extern from `src/main.zig`.
- [ ] Run plugin `deinitAll` in reverse registration order so teardown unwinds setup.
- [x] Add consistent error responses for invalid arguments and backend failures. Implemented: typed `IncrementParseError` set with per-case messages, `rejectWithCode()` JSON envelope (`{"code","message"}`) used by `increment` validation, window-action failures (`WindowUnavailable` / `WindowActionFailed`), and `closeWindow` settles before terminating.
- [x] Add unit tests for counter logic, timestamp formatting, and system detection.
- [ ] Add longer-running operation support using Zig threads and WebView dispatching.
- [x] Add window lifecycle controls such as minimize, maximize, and close handling.
- [x] Add a backend configuration layer for window title, size, and debug/release mode (cf. webview-app-with-vlang `config.v`: `default_app_config()`, `is_debug_build()`). Implemented in `src/config.zig`; `src/main.zig` no longer hardcodes title/size/devtools.
- [x] Add backend logging with levels and different behavior for debug and release builds. Implemented in `src/backend/log.zig` (`Level`, `log()`, `shouldLog()`; debug gated on config).
- [x] Add graceful shutdown handling for the WebView event loop and worker threads (cf. webview-app-with-vlang graceful-shutdown todo). Implemented: `src/main.zig` runs `registry.deinitAll()` after `easy.run()` with warning on failure, then logs shutdown; plugin `onDeinit` hooks fire (no worker threads yet).
- [x] Decide on persistent storage: versioned JSON state file as v1 (see `Persistence Implementation Plan`). `localStorage` is rejected for anything durable because it throws under the native shell's opaque origin (cf. the Todos crash fixed via `todo-storage.js`); SQLite is deferred until Disk Scanner needs a real cache.
- [ ] Complete the v1 store: schema migrations, full `getState` / `saveState` bridge methods, and backup recovery. Implemented so far: OS data-directory resolution, atomic `state.json` read/write, note CRUD bindings, validation, structured storage errors, and reload tests.
- [ ] Add import/export or backup support (copy/restore the state file; JSON download/upload from the frontend).
- [ ] Add packaging for Linux, macOS, and Windows.

## Frontend

- [x] Create Disk Scanner and Audio Equalizer interface mockups with local-only interactions.
- [x] Create Chain Notes with searchable local drafts and client-side PDF export.
- [x] Add explicit loading, success, and error states for every backend call.
- [x] Prevent duplicate or conflicting counter requests while an operation is pending.
- [ ] Add TypeScript checking (`tsc --noEmit`) or migrate frontend files to TypeScript. The active frontend is Preact, so `svelte-check` does not apply.
- [ ] Organize the UI into reusable components as the application grows.
- [x] Migrate the active frontend styling from Tailwind and global component CSS to StyleX with esbuild extraction.
- [x] Move toolkit views and metadata behind a frontend plugin registry.
- [x] Add a replaceable frontend entrypoint registry without swapping the active frontend.
- [x] Improve responsive behavior for small windows.
- [x] Add keyboard navigation, visible focus states, labels, and accessible status messages.
- [x] Keep the launcher and compact workspace rail fixed by default; group Disk Scanner and Audio Equalizer under the expandable Tools submenu.
- [x] Add a Quiz workspace with bundled Blender 3D Editor and Audio Programming collections, answer reveal, explanations, progress, search, known-answer tracking, and reset controls. Implemented in `frontend-preact/src/plugins/quiz.jsx` and `quiz-data.js`.
- [x] Add an expandable Quiz sidebar with separate `Quiz Session` and `Quiz Editor` destinations; keep it mutually exclusive with the Tools submenu.
- [ ] Connect `Quiz Editor` to the versioned backend state store for custom decks and question CRUD; keep bundled example collections read-only.
- [ ] Expand Quiz collections and add a content authoring/schema workflow so new decks do not require editing the component.
- [ ] Persist Quiz progress and custom collections through the versioned backend state store; keep bundled decks read-only and safely migrate deck/question ids.
- [ ] Add spaced repetition, shuffled sessions, answer confidence levels, and session history to Quiz.
- [x] Add a frontend mock bridge so the UI can run independently under Vite. Implemented: `frontend-preact/src/backend.js` falls back to mocks when `window.*` bindings are absent (`__PREACT_MOCK_BRIDGE__` opts out); `npm run dev` / `npm run serve` serve the UI in the browser.
- [x] Add a typed bridge client for all Zig calls with backend-unavailable, timeout, and validation states (cf. webview-app-with-vlang `ui/src/lib/backend.ts` + `backend.test.ts`). Implemented: `frontend-preact/src/backend.js` normalizes every failure to `{code, message}` (`errorDetails()` handles envelopes, bare error names, timeouts, unavailable bindings, client-side validation), enforces a configurable timeout (default 5s), validates `increment` deltas locally, and `BackendStatus` probes `getStatus` on mount. Covered by `frontend-preact/check-backend-errors.mjs` (`npm test`, wired into `zig build test`).
- [x] Add frontend component tests for Todo interactions. Bridge-level CRUD and backend error behavior is covered by `check-backend-errors.mjs`; rendering is now covered by `vitest` + `@testing-library/preact` + `jsdom` (see `Third-Party Library Adoption Plan`, phase 1). Implemented: `frontend-preact/vitest.config.js` (esbuild JSX + `@stylexjs/stylex` stub), `test/stylex-stub.js`, `src/plugins/todo.test.jsx` (render, add, toggle, filter), wired into `npm test` as `test:components`.
- [ ] Add a proper application-level design system and theme configuration.
- [x] Add a production error boundary or fallback screen. Implemented: `frontend-preact/src/error-boundary.jsx` (`ErrorBoundary` with reload recovery) wrapping `<App />` in `src/main.jsx`.
- [ ] Verify `ErrorBoundary` against the pinned Preact version (`getDerivedStateFromError` support) with a render test; give the Notes and Todos tabs distinct tones (both are `gold` today).
- [x] Wire the `getStatus` health probe into `BackendStatus` and make `backend.isNative()` cover the full core binding set.
- [ ] Single-source the binding list: derive `frontend-preact/check-bindings.cjs` expectations from `src/backend/core_plugin.zig:bound_names` instead of maintaining the same 13 names by hand.

## Integration

- [x] Keep `bindings.d.ts` synchronized with Zig bindings, ideally through generated types or a shared API schema. Implemented: `src/backend/core_plugin.zig:bound_names` (13 names + uniqueness test) + `frontend-preact/check-bindings.cjs` (`npm run check:bindings`, wired into `npm run build`, `zig build test`, and CI).
- [x] Define a development mode where Vite serves the UI while Zig provides the native shell. Implemented via `zig build run -Ddev`: dev build navigates to the Preact dev server (`http://localhost:3000`), release build uses the embedded single-file HTML (`build_options.dev_mode` in `build.zig` + `src/main.zig`).
- [x] Add a single `test-all` path (`zig build test` + `npm run check`, plus frontend build) mirroring `v run build.vsh test`, and keep an integration test for each JavaScript-to-Zig binding. `zig build test` now runs `backend/config/plugin/log/core_plugin` unit tests + `npm run check` + `npm run check:bindings`; binding-name sync is covered statically.
- [x] Add a Content Security Policy and restrict unintended navigation/external content. Implemented: CSP `<meta>` in `frontend-preact/public/index.html` (carried into `dist/` + embedded HTML by `single-file-html` plugin); release shell serves only embedded HTML, dev shell navigates only to the local dev server.
- [ ] Verify builds on Linux, macOS, and Windows, including on clean machines.
- [ ] Add release metadata, icons, versioning, installers, distribution documentation, and crash-reporting or diagnostic logs.
- [ ] Make `run.sh` call `tools/check-deps.sh` (and require node/npm) before building so missing toolchains fail with a clear message instead of an obscure `npm` error.
- [ ] Add a dev-server readiness probe for `zig build run -Ddev` with a clear error when `http://localhost:3000` is down (cf. webview-app-with-vlang `wait_for_frontend`); skip the full frontend rebuild when `dist/` is already fresh to speed up iteration.
- [ ] Refresh `README.md`: document `src/config.zig`, the `-Ddev` dev mode, `npm run check:bindings`, CI, CSP, the error boundary, and the Todos storage fallback. Remove the empty `lib/` directory or document its purpose.

## Execution Notes

- The frontend production build currently succeeds.
- The native build uses LLVM code generation for compatibility with the local Zig 0.16/GCC 16 toolchain.
- Native Linux builds prepare a cached libc configuration that removes unsupported `.sframe` sections from startup objects without changing system files.
- The backend test suite (`backend`, `config`, `plugin`, `log`, `core_plugin`) plus `npm run check` and `npm run check:bindings` passes with `zig build test`.
- CI (`.github/workflows/ci.yml`) covers dependency checks, `zig build test`, and `zig build`.
- The launcher provides persistent home navigation and switching between opened workspaces.
- The Todos plugin no longer touches `localStorage` / `location.hash` directly: `frontend-preact/src/plugins/todo-storage.js` falls back to in-memory state where the native shell has an opaque origin, fixing the crash when opening the Todos workspace.

## Toolkit Dependencies

### Existing Dependencies

- `zig-webview`: native window, WebView, and JavaScript-to-Zig bindings.
- GTK3 and WebKitGTK 4.1 on Linux.
- WebView2 on Windows.
- Native WebKit on macOS.
- Preact 10, esbuild, and StyleX (active `frontend-preact/` shell).
- Previous Svelte frontend lives only in `archive/svelte-view/` and is not built.

### Recommended New Libraries

Constraint baseline for every adoption: the frontend ships as one offline
embedded file (bundle weight matters), Zig 0.16 churn breaks community
packages regularly (prefer C-ABI libs via `@cImport`, which are immune), and
the WebView sandbox allows no Node APIs, no CDN, and CSP-limited code.

- Disk Scanner: no third-party library is required initially; Zig filesystem APIs and OS APIs are sufficient.
- Disk Scanner persistence: SQLite for caching scan results.
- Audio I/O: `miniaudio` for cross-platform audio devices and playback.
- Audio DSP: custom biquad filters for the seven-band equalizer.
- Spectrum analysis: `KissFFT` for FFT-based visualizer data.
- Audio resampling: `libsamplerate` if sample-rate conversion is needed.
- Prefer `KissFFT` over FFTW for a permissive license suitable for distribution.

## Third-Party Library Adoption Plan

Surveyed 2026-09 against the constraints above. Phases are ordered by
value-per-risk; each phase lands behind the existing test gates
(`npm run check`, `npm test`, `zig build test`).

### Phase 1: component testing (execute first)

- Add devDependencies `vitest` + `@testing-library/preact` + `jsdom`.
- `frontend-preact/vitest.config.js`: `environment: jsdom` + `globals`
  (auto-cleanup), first-party `@preact/preset-vite` for JSX (raw esbuild
  `jsxImportSource` is ignored by the vite pipeline — use the preset),
  alias `@stylexjs/stylex` to a tiny `test/stylex-stub.js` (`create` =
  identity, `props` returns a fixed className) because real StyleX requires
  its babel plugin at build time. Invoke via node directly
  (`node node_modules/vitest/vitest.mjs run`) since installs use
  `--no-bin-links`.
- First suites: `src/plugins/todo.test.jsx` (render empty state, add todo,
  toggle completion, status filter). Keep pure-logic suites in `check-*.mjs`;
  vitest covers rendered-component behavior only.
- New script `test:components` (`node node_modules/vitest/vitest.mjs run`),
  appended to `npm test` so `zig build test` and CI pick it up with no
  workflow changes.
- Reset `localStorage` + `location.hash` in `beforeEach`: jsdom persists them
  across tests within a file.
- Install notes: `vite` is a vitest peer and must be installed explicitly.
  Pinned `esbuild@0.25` conflicts with vite's peer range, so `package.json`
  carries `"overrides": { "esbuild": "$esbuild" }` to unify on the root
  version (verified benign by green runs — do NOT "fix" this by upgrading
  the build chain's esbuild). Plain `npm install` / `npm ci` then work with
  no flags; the committed lockfile keeps CI deterministic. (Lesson learned:
  `--legacy-peer-deps` installs silently pruned transitive deps like
  `unplugin`, breaking both `npm ci` and the production build — overrides
  are the correct mechanism.)

### Phase 2: SQLite proof-of-concept (when Disk Scanner starts)

- Candidates verified 0.16-compatible: `karlseguin/zqlite.zig` (targets
  0.16.0) or `nDimensional/zig-sqlite` (tested on 0.16.0). Avoid
  `vrischmann/zig-sqlite` (stalled pre-0.16; community fork exists — this is
  the ecosystem tax in action).
- Zero-churn alternative: `@cImport` system `sqlite3` directly behind a thin
  envelope-error wrapper, mirroring how `time.h` is already consumed.
- Uses, in order: Disk Scanner result cache (already planned) → FTS5
  full-text search over chain notes (real upgrade over title matching) →
  durable quiz progress. Keep the v1 JSON store until the cache need is real.

### Phase 3: audio stack (per existing audio plan)

- `miniaudio` (single-header C, public domain/CC0) for device discovery and
  app-local playback; `KissFFT` for the visualizer FFT. Both via `@cImport`,
  no Zig-version risk. Unchanged from `Recommended New Libraries` above.

### Phase 4: on demand only

- `@preact/signals` (first-party, tiny): adopt when lifted `useState`
  (papers editing, todo focus date, quiz-known) starts prop-drilling — not
  before. Current lifting works.
- `uPlot` (framework-agnostic, tiny): EQ spectrum / scanner treemap visuals.
  Hand-rolled SVG stays acceptable for bars and treemaps.
- `date-fns`: only if recurring todos/reminders arrive; hand-rolled ISO utils
  suffice today.
- `marked`: only if papers need full GFM (tables). The tested markdown subset
  is a deliberate CSP-safe asset — do not replace it lightly.
- `lucide` icons: only if the glyph system outgrows itself.
- TypeScript `tsc --noEmit` (devDep, zero runtime cost): complements
  `bindings.d.ts`; see the existing Frontend TODO.
- Playwright: e2e against `npm run dev`; the native shell stays manual.

### Explicitly rejected

- React-only libs needing `preact/compat`; `zod` (bridge validation is
  tighter and smaller); `idb-keyval` (the Zig store owns durability);
  anything CDN-loaded (offline + CSP); `resvg` for SVG-in-PDF (heavy native
  dep for a nice-to-have — placeholder-box semantics are the right 80/20);
  HTTP server libs (no server surface); CLI-arg parsers (no CLI surface);
  UUID libs (time+counter ids are fine); pure-Zig utility grab-bags (churn
  risk exceeds value at this scale).

## Audio Product Scope

- [ ] Start with an app-local equalizer that processes audio played by this application.
- [ ] Decide separately whether a system-wide equalizer is worth the platform-specific complexity.
- System-wide audio requires capture and rerouting through PipeWire or PulseAudio on Linux, WASAPI loopback and potentially a virtual audio device on Windows, and CoreAudio routing or a virtual audio driver on macOS.

## Disk Scanner Implementation

- [ ] Add `listVolumes()` to discover mounted volumes.
- [ ] Add `startDiskScan(volumeId)` and return a scan ID.
- [ ] Add `getDiskScanStatus(scanId)` for progress and state polling.
- [ ] Add `getDiskScanResult(scanId)` for the completed directory-size report.
- [ ] Add `cancelDiskScan(scanId)` for cancellation.
- [ ] Traverse directories using Zig filesystem APIs.
- [ ] Do not follow symbolic links by default.
- [ ] Handle permission failures without aborting the entire scan.
- [ ] Prevent crossing into other mounted volumes unless explicitly requested.
- [ ] Run scans on worker threads.
- [ ] Cache scan results for faster subsequent views.
- [ ] Report progress, scanned bytes, file count, total bytes, largest directories, free space, and permission errors. Use platform capacity APIs (`statvfs` on Linux/macOS, `GetDiskFreeSpaceExW` on Windows, cf. webview-app-with-vlang Toolkit plan).
- [ ] Replace the mock Disk Scanner data with the backend RPC results.

## Audio Equalizer Implementation

- [ ] Add `listAudioDevices()`.
- [ ] Add `loadAudioFile(path)` for the first app-local audio source.
- [ ] Add `setEqualizerBands(values)`.
- [ ] Add `setEqualizerEnabled(enabled)`.
- [ ] Add `getAudioLevels()` for visualizer data.
- [ ] Add `stopAudio()`.
- [ ] Use an audio thread for playback and DSP.
- [ ] Keep WebView requests on the main Zig thread.
- [ ] Use a lock-free queue or atomic state to transfer equalizer changes to the audio thread.
- [ ] Never allocate memory or call WebView APIs inside the audio callback.
- [ ] Implement seven peaking biquad filters.
- [ ] Send RMS or FFT levels to the frontend at roughly 30 to 60 updates per second.
- [ ] Debounce slider changes before sending them to the backend.
- [ ] Replace the mock Audio Equalizer controls with real backend state.
- [ ] Add device selection, source selection, playback controls, loading states, and backend error handling. Include preset loading, playback position/duration, unsupported-format and missing-device errors, and proper release of audio resources on track switch (cf. webview-app-with-vlang Audio Bridge API).

## Recommended Delivery Order

- [x] Implement the v1 JSON state store and persist Chain Notes through it.
- [ ] Finish Disk Scanner using Zig and OS filesystem APIs.
- [ ] Add worker-thread progress and cancellation.
- [ ] Replace Disk Scanner mock data with RPC results.
- [ ] Add `miniaudio`.
- [ ] Implement app-local audio file playback.
- [ ] Implement biquad equalizer processing.
- [ ] Connect frontend sliders to real filter coefficients.
- [ ] Add FFT visualizer data through `KissFFT`.
- [ ] Revisit system-wide audio routing as a separate advanced project.
- [ ] Add SQLite scan-result caching only when Disk Scanner outgrows the JSON store.

## Persistence Implementation Plan

Context: the Todos workspace crash showed `localStorage` throws under the
native shell's opaque origin, so anything durable must live behind the Zig
backend. Options considered:

### Option A (chosen for v1): single versioned JSON state file
- Backend resolves the OS data dir (`XDG_DATA_HOME` on Linux,
  `%APPDATA%` on Windows, `~/Library/Application Support` on macOS) and
  manages `<app-dir>/state.json` with schema `{ "version": 1, "notes": [...],
  "presets": {...}, "counter": n }`.
- Reads at startup (missing file = fresh defaults); writes are debounced and
  atomic (tmp file + rename). Migrations run on load via a version switch.
- Bridge: `getState()` returns the document; `saveState(doc)` validates
  (version, known top-level keys) and persists. Failures use the error
  envelope: `StorageUnavailable`, `StorageCorrupt` (with backup of the bad
  file + fresh defaults), `StorageWriteFailed`.
- Pros: zero dependencies, human-readable, trivial backup (copy one file),
  easy import/export. Cons: whole-file rewrites; fine at KB scale.
- Tasks:
  - [ ] Add data-dir resolution per OS with unit tests (env overrides for hermetic tests).
  - [ ] Add versioned schema + migration switch with tests (v0/missing -> v1).
  - [ ] Add atomic write (tmp + rename) with tests, including corrupt-file recovery.
  - [ ] Add `getState` / `saveState` bindings with envelope errors and frontend
    `backend.js` wiring (`getState`, `saveState` with validation states).
  - [ ] Migrate Chain Notes (then counter, then EQ presets) onto the store.

### Option B (deferred): file-per-note Markdown + index
- Each note is a `.md` file with front-matter; `index.json` keeps ordering.
- Revisit only if users need external editing, git history, or per-note sync;
  overkill while notes are simple.

### Option C (deferred): SQLite
- Correct tool for Disk Scanner result caching (indexed queries over thousands
  of rows) but a heavy dependency for notes/counters alone. Revisit when the
  scanner needs it, per the delivery order above.

### Option D (rejected): frontend-only `localStorage`
- Rejected for anything durable: throws in the native shell. Keep it as a
  browser-dev convenience behind the `todo-storage.js` memory fallback only.

### Option E (rejected as steady state): in-memory + manual export only
- Acceptable stopgap at most; users lose data silently. The JSON download /
  upload path survives as the import/export mechanism for Option A.
