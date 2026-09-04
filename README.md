# WebView App with Preact + Zig

A lightweight offline desktop toolkit using [webview](https://github.com/webview/webview)
with a Zig backend and Preact frontend: local Q&A chain notes with fuzzy search,
an academic paper reader with reference/figure management, quizzes, todos, and
PDF export throughout.

## Features

| Plugin | What it does |
| --- | --- |
| Chain Notes | Saves external AI chats as local question-and-answer records; fuzzy search, markdown-aware PDF/print export |
| Academic Paper | Two-column paper reader with citations, plus Reference Manager and Image Assets submenus |
| Quiz | Blender 3D and audio-programming decks with sessions and an editor |
| Todos | Local-first task list with filters |
| Disk Scanner | Storage usage mapping (mock UI, backend pending) |
| Audio Equalizer | Listening-profile controls (mock UI, backend pending) |

Details live in [`docs/`](docs/): [chain notes](docs/chain-notes.md),
[academic paper](docs/academic-paper.md), [backend](docs/backend.md), and
[testing](docs/testing.md).

## Architecture

```
.
├── build.zig / build.zig.zon  # Zig build, package manifest, test roots
├── src/
│   ├── main.zig                # Entry point, WebView host, RPC context
│   ├── backend.zig             # Domain logic, validation, PDF saving
│   ├── config.zig              # Window title/size, debug mode, dev URL
│   └── backend/
│       ├── plugin.zig          # Backend plugin registry + lifecycle hooks
│       ├── core_plugin.zig     # Binding registration + canonical name list
│       ├── storage.zig         # Versioned JSON note store (state.json)
│       └── log.zig             # Leveled logging
├── frontend-preact/            # Preact frontend (esbuild + StyleX)
│   ├── build.js                # Bundle + single-file dist/index.html
│   └── src/
│       ├── App.jsx             # Launcher, rail, submenus, window controls
│       ├── backend.js          # window.* Zig bridge with browser mocks
│       ├── bindings.d.ts       # Typed bridge declarations (14 bindings)
│       └── plugins/            # Tool UIs + shared modules
│           ├── chain-notes.jsx / qna.js
│           ├── note-search.js      # fuzzysort adapter (+ benchmark engines)
│           ├── note-markdown.js    # Markdown subset + print CSS reset
│           ├── note-pdf.js         # jsPDF / pdf-lib / pdfmake adapter
│           ├── academic-paper.jsx / paper.js / paper-data.js / paper-pdf.js
│           ├── reference-manager.jsx / image-assets.jsx
│           └── quiz.jsx / quiz-data.js, todo.jsx, …
├── tools/                      # check-deps.sh, install-frontend.sh, prepare-linux-libc.sh
├── docs/                       # Feature and backend documentation
└── archive/svelte-view/        # Previous Svelte frontend (archived, not built)
```

## Prerequisites

- **Zig** 0.16.0+
- **Node.js** 18+ and npm
- **Linux**: GTK3 + WebKitGTK 4.1
- **macOS**: WebKit (built-in)
- **Windows**: WebView2 Runtime

The project compiles the bundled webview C/C++ sources with a C++11-capable
system compiler; the native toolchain must be compatible with the pinned Zig
release. Verify everything up front:

```sh
bash tools/check-deps.sh
```

### Linux (Arch)

```sh
sudo pacman -S webkit2gtk-4.1 gtk3
```

### Linux (Ubuntu/Debian)

```sh
sudo apt install libgtk-3-dev libwebkit2gtk-4.1-dev
```

## Build & Run

```sh
# Build and launch the GUI
./run.sh

# Build everything (frontend + backend) and run
zig build run

# Or step by step:
cd frontend-preact && npm install && npm run build && cd ..
zig build
./zig-out/bin/webview-app
```

`build.zig` builds the Preact bundle, stages the single-file HTML under `src/`
(Zig 0.16 only allows `@embedFile` inside the package tree), then compiles the
native binary with the HTML embedded. On Linux it also stages a cached libc
configuration that strips unsupported `.sframe` sections from startup objects
without touching system files.

## Development

```sh
zig build dev          # frontend dev server (Preact shell + mocks)
```

Inside the dev server the Zig bindings don't exist, so `src/backend.js` falls
back to in-browser mocks (notes persist to `localStorage` when available).

## Tests & Benchmarks

```sh
zig build test --summary all   # backend unit tests + all frontend checks
cd frontend-preact && npm test # bridge, quiz, Q&A, markdown, paper, search, PDF suites
cd frontend-preact && npm run benchmark:notes  # fuzzy-search engines
cd frontend-preact && npm run benchmark:pdf    # PDF engines (note + chain)
cd frontend-preact && npm run benchmark:paper  # PDF engines (sample paper)
```

See [docs/testing.md](docs/testing.md) for the full matrix.

## How It Works

1. **Frontend**: Preact + esbuild + StyleX. The custom `single-file-html`
   plugin inlines all JS/CSS into `frontend-preact/dist/index.html`.
2. **Backend**: Zig compiles the webview library and embeds the built HTML.
   RPCs are grouped into backend plugins (`src/backend/plugin.zig`) instead of
   loose bindings; see [docs/backend.md](docs/backend.md).
3. **Communication**: the frontend calls Zig functions via `window.*`, which
   return Promises. Failures arrive as stable `{code, message}` envelopes.
4. **Persistence**: notes live in a versioned `state.json` under the OS data
   dir; PDF exports are written to the user's Documents folder via `savePdf`.
5. **Launcher**: the app starts as a workspace launcher with a fixed rail,
   expandable submenus (Tools, Quiz, Paper), and native window actions.

### Adding a frontend tool

Create a Preact view and manifest under `frontend-preact/src/plugins/` (see
`contract.js`), then register it in `plugins/index.js` and add its rail label
in `src/App.jsx`.

### Adding a backend function

1. Add a method to `Context` in `src/main.zig` and bind it in
   `src/backend/core_plugin.zig` (+ `bound_names`, tested for uniqueness).
2. Declare it in `frontend-preact/src/bindings.d.ts` and wrap it in
   `frontend-preact/src/backend.js` (validation + mock fallback).
3. Extend `frontend-preact/check-bindings.cjs` — CI fails on drift.

## License

MIT
