# Development TODOs

This roadmap covers the planned backend, frontend, integration, and release work.

## Phase 0: Build Foundation

- [x] Resolve the Zig/GCC linker issue involving `R_X86_64_PC64` and `.sframe` by enabling LLVM code generation for the executable.
- [x] Document supported Zig, native compiler, GTK, and WebKitGTK requirements.
- [x] Replace `npm install` with `npm ci` in `build.zig` for reproducible builds.
- [ ] Add a CI workflow covering frontend build and backend compilation.

## Backend

- [ ] Implement disk scanner volume discovery and directory-size aggregation.
- [ ] Implement audio device discovery, playback routing, and equalizer processing.
- [ ] Replace the mock Disk Scanner and Audio Equalizer data with backend RPC calls.
- [ ] Add Chain Notes persistence, note synchronization, and backend export support if needed.
- [x] Move `Context` state and backend operations out of `src/main.zig` into a separate module.
- [ ] Define a clear RPC API for frontend/backend communication.
- [x] Add a backend plugin registry for cohesive RPC binding groups.
- [x] Replace manual JSON argument slicing in `increment()` with proper JSON parsing and validation.
- [x] Add consistent error responses for invalid arguments and backend failures.
- [x] Add unit tests for counter logic, timestamp formatting, and system detection.
- [ ] Add longer-running operation support using Zig threads and WebView dispatching.
- [x] Add window lifecycle controls such as minimize, maximize, fullscreen, and close handling.
- [ ] Add configurable window title, size, and development/release mode.
- [ ] Add backend logging with different behavior for debug and release builds.
- [ ] Decide whether application state should persist between launches.
- [ ] Add packaging for Linux, macOS, and Windows.

## Frontend

- [x] Create Disk Scanner and Audio Equalizer interface mockups with local-only interactions.
- [x] Create Chain Notes with searchable local drafts and client-side PDF export.
- [x] Add explicit loading, success, and error states for every backend call.
- [x] Prevent duplicate or conflicting counter requests while an operation is pending.
- [ ] Add TypeScript checking with `svelte-check` or migrate frontend files to TypeScript.
- [ ] Organize the UI into reusable components as the application grows.
- [x] Move toolkit views and metadata behind a frontend plugin registry.
- [x] Add a replaceable frontend entrypoint registry without swapping the active frontend.
- [x] Improve responsive behavior for small windows.
- [x] Add keyboard navigation, visible focus states, labels, and accessible status messages.
- [ ] Add a frontend mock bridge so the UI can run independently under Vite.
- [ ] Add frontend tests for counter interactions and backend error states.
- [ ] Add a proper application-level design system and theme configuration.
- [ ] Add a production error boundary or fallback screen.

## Integration

- [ ] Keep `bindings.d.ts` synchronized with Zig bindings, ideally through generated types or a shared API schema.
- [ ] Define a development mode where Vite serves the UI while Zig provides the native shell.
- [ ] Add an integration test for each JavaScript-to-Zig binding.
- [ ] Add a Content Security Policy and restrict unintended navigation/external content.
- [ ] Verify builds on Linux, macOS, and Windows.
- [ ] Add release metadata, icons, versioning, and distribution documentation.

## Execution Notes

- The frontend production build currently succeeds.
- The native build uses LLVM code generation for compatibility with the local Zig 0.16/GCC 16 toolchain.
- Native Linux builds prepare a cached libc configuration that removes unsupported `.sframe` sections from startup objects without changing system files.
- The backend test suite is implemented and passes with `zig build test`.
- The first implementation slice is complete for reproducible builds, testable backend state, RPC validation, and frontend request handling.
- The launcher provides persistent home navigation and switching between opened workspaces.

## Toolkit Dependencies

### Existing Dependencies

- `zig-webview`: native window, WebView, and JavaScript-to-Zig bindings.
- GTK3 and WebKitGTK 4.1 on Linux.
- WebView2 on Windows.
- Native WebKit on macOS.
- Svelte 5, Vite, and `vite-plugin-singlefile`.

### Recommended New Libraries

- Disk Scanner: no third-party library is required initially; Zig filesystem APIs and OS APIs are sufficient.
- Disk Scanner persistence: SQLite for caching scan results.
- Audio I/O: `miniaudio` for cross-platform audio devices and playback.
- Audio DSP: custom biquad filters for the seven-band equalizer.
- Spectrum analysis: `KissFFT` for FFT-based visualizer data.
- Audio resampling: `libsamplerate` if sample-rate conversion is needed.
- Prefer `KissFFT` over FFTW for a permissive license suitable for distribution.

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
- [ ] Report progress, scanned bytes, file count, total bytes, largest directories, free space, and permission errors.
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
- [ ] Add device selection, source selection, playback controls, loading states, and backend error handling.

## Recommended Delivery Order

- [ ] Finish Disk Scanner using Zig and OS filesystem APIs.
- [ ] Add worker-thread progress and cancellation.
- [ ] Replace Disk Scanner mock data with RPC results.
- [ ] Add `miniaudio`.
- [ ] Implement app-local audio file playback.
- [ ] Implement biquad equalizer processing.
- [ ] Connect frontend sliders to real filter coefficients.
- [ ] Add FFT visualizer data through `KissFFT`.
- [ ] Revisit system-wide audio routing as a separate advanced project.
- [ ] Add SQLite persistence after the core features work.
