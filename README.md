# WebView App with Svelte + Zig

A lightweight desktop application starter using [webview](https://github.com/webview/webview) with a Zig backend and Svelte 5 frontend.

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
│   └── view/          # Svelte frontend (Vite)
│       ├── index.html
│       ├── package.json
│       ├── vite.config.js
│       └── src/
│           ├── main.js
│           ├── main.css
│           ├── App.svelte             # Default frontend shell
│           ├── frontends/             # Swappable frontend entrypoints
│           └── plugins/               # Registered tool plugins and views
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
cd src/view && npm install && npm run build && cd ../..
zig build
./zig-out/bin/webview-app
```

## Development

Start the frontend dev server for UI development:

```sh
zig build dev
```

## How It Works

1. **Frontend**: Svelte 5 app built with Vite. The `vite-plugin-singlefile` inlines all JS/CSS into a single HTML file.

2. **Backend**: Zig compiles the webview library and embeds the built HTML using `@embedFile`. Functions are bound to the JS context using the `Easy` API.

3. **Communication**: The frontend calls Zig functions via `window.functionName()`, which return Promises resolved by the Zig backend.

4. **Launcher**: The frontend starts as a workspace launcher. Selecting a tool enters native fullscreen mode; the workspace title bar provides launcher navigation and native window actions.

### Plugin Architecture

The current frontend is still the active default frontend; it has not been
swapped. Its entrypoint is selected through `src/view/src/frontends/index.js`,
so another complete frontend can be introduced by registering a component
without changing the native host. The default shell discovers tools from
`src/view/src/plugins/index.js`. Each tool plugin owns its manifest and Svelte
view, while the shell owns navigation and window lifecycle behavior.

The backend uses the same boundary in `src/backend/plugin.zig`. A backend
plugin is a cohesive RPC binding group with a `register` function. The native
entrypoint registers the ordered plugin list instead of binding individual RPCs
itself. Feature plugins can therefore be added under `src/backend/` without
changing the host setup beyond registration.

To add a frontend tool, create a Svelte view and manifest under
`src/view/src/plugins/`, then add the manifest to the registry. To add backend
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

3. Declare the type in `src/view/bindings.d.ts`:

```typescript
interface Window {
    myFunction(): Promise<string>;
}
```

4. Call it from Svelte:

```svelte
<script>
  const result = await window.myFunction();
</script>
```

## License

MIT
