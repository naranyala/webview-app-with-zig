# WebView App with Preact + Zig

A lightweight desktop application starter using [webview](https://github.com/webview/webview) with a Zig backend and Preact frontend.

## Architecture

```
.
├── build.zig          # Zig build system (compiles backend + builds frontend)
├── build.zig.zon      # Zig package manifest
├── src/
│   ├── main.zig       # Zig entry point and backend plugin host
│   ├── backend.zig    # Backend domain state, validation, and plugin registry
│   ├── backend/
│   │   └── core_plugin.zig
├── frontend-preact/   # Preact frontend (esbuild + Tailwind)
│   ├── public/index.html
│   ├── build.js         # Bundles src/main.jsx + inlines CSS/JS to dist/index.html
│   └── src/
│       ├── main.jsx         # Mounts App.jsx
│       ├── App.jsx          # Launcher/workspace shell
│       ├── backend.js       # window.* Zig bridge with browser mocks
│       ├── backend-status.jsx
│       ├── toolkit.css      # Dark toolkit theme (ported from Svelte shell)
│       └── plugins/         # Registered tool plugins and views
├── archive/svelte-view/ # Previous Svelte frontend (archived, not built)
└── lib/               # Shared libraries
```

## Prerequisites

- **Zig** 0.16.0+
- **Node.js** 18+ and npm
- **Linux**: GTK3 + WebKitGTK 4.1
- **macOS**: WebKit (built-in)
- **Windows**: WebView2 Runtime

The project uses Zig 0.16 and compiles the bundled webview C/C++ sources with a
C++11-capable system compiler. The exact native compiler toolchain must also be
compatible with the selected Zig release.

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

## Development

Start the frontend dev server for UI development:

```sh
zig build dev
```

## How It Works

1. **Frontend**: Preact app built with esbuild. A custom `single-file-html` plugin inlines all JS/CSS into `frontend-preact/dist/index.html`. `build.zig` stages that file to `src/frontend-dist/index.html` (Zig 0.16 only allows `@embedFile` inside the `src/` package tree).

2. **Backend**: Zig compiles the webview library and embeds the built HTML using `@embedFile`. Functions are bound to the JS context using the `Easy` API.

3. **Communication**: The frontend calls Zig functions via `window.functionName()`, which return Promises resolved by the Zig backend.

4. **Launcher**: The frontend starts as a workspace launcher. Selecting a tool keeps the configured native window size; fixed sidebars provide persistent navigation while the workspace title bar provides native window actions.

### Plugin Architecture

The Preact shell (`frontend-preact/src/App.jsx`) is the active frontend.
The shell discovers tools from
`frontend-preact/src/plugins/index.js`. Each tool plugin owns its manifest and Preact
view, while the shell owns navigation and window lifecycle behavior.

The backend uses the same boundary in `src/backend/plugin.zig`. A backend
plugin is a cohesive RPC binding group with a `register` function. The native
entrypoint registers the ordered plugin list instead of binding individual RPCs
itself. Feature plugins can therefore be added under `src/backend/` without
changing the host setup beyond registration.

To add a frontend tool, create a Preact view and manifest under
`frontend-preact/src/plugins/`, then add the manifest to the registry. To add backend
capabilities, create a `register(comptime Easy: type)` function under
`src/backend/` and add its descriptor to `backend_plugins` in `src/main.zig`.

### Adding New Backend Functions

1. Add a method to the `Context` struct in `src/main.zig`:

```zig
pub fn myFunction(self: *Context, req: Easy.Request) !void {
    // Your logic here
    req.resolveWith("result");
}
```

2. Bind it in `main()`:

```zig
try easy.bind(.myFunction);
```

3. Declare the type in `frontend-preact/src/bindings.d.ts`:

```typescript
interface Window {
    myFunction(): Promise<string>;
}
```

4. Call it from Preact (via `src/backend.js`, which mocks bindings in the browser):

```jsx
import { backend } from "./backend.js";
const result = await backend.myFunction?.() ?? window.myFunction();
```

## License

MIT
