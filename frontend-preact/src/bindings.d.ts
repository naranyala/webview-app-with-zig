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
    getNotes(): Promise<Note[]>;
    createNote(title: string, tag: string, body: string): Promise<Note>;
    updateNote(
      id: string,
      title: string,
      tag: string,
      body: string
    ): Promise<Note>;
    deleteNote(id: string): Promise<void>;
    savePdf(filename: string, dataBase64: string): Promise<SaveResult>;
    minimizeWindow(): Promise<void>;
    maximizeWindow(): Promise<void>;
    restoreWindow(): Promise<void>;
    closeWindow(): Promise<void>;
    __PREACT_MOCK_BRIDGE__?: boolean;
  }
}

interface Note {
  id: string;
  title: string;
  tag: string;
  updated: string;
  body: string;
}

interface SaveResult {
  path: string;
}

export {};
