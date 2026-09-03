/**
 * Zig backend bindings available as `window.*` inside the native WebView.
 * See `src/main.zig` + `src/backend/core_plugin.zig`.
 * Under `npm run dev` these fall back to mocks via `src/backend.js`.
 */
declare global {
  interface Window {
    increment(delta: number): Promise<number>;
    reset(): Promise<number>;
    getSystemInfo(): Promise<string>;
    getTimestamp(): Promise<string>;
    getStatus(): Promise<string>;
    minimizeWindow(): Promise<void>;
    maximizeWindow(): Promise<void>;
    restoreWindow(): Promise<void>;
    closeWindow(): Promise<void>;
    __PREACT_MOCK_BRIDGE__?: boolean;
  }
}

export {};
