/**
 * Zig backend bridge.
 *
 * Inside the native WebView each `window.*` function is bound by Zig
 * (`src/main.zig` via `src/backend/core_plugin.zig`) and returns a Promise.
 * Failures arrive in one of three shapes, all normalized by `errorDetails()`:
 *
 * - Structured envelope from `backend.rejectWithCode`:
 *   `{"code":"MalformedJson","message":"..."}`.
 * - Bare error names from `rejectError`: `"InvalidState"`, possibly quoted.
 * - Local errors: timeouts (`code: 'Timeout'`), missing bindings outside the
 *   native shell (`code: 'Unavailable'`), and client-side validation
 *   (`code: 'InvalidArgument'`).
 *
 * Under `npm run dev` / esbuild serve those bindings don't exist, so every
 * helper falls back to a mock that keeps the UI usable in the browser.
 */

const DEFAULT_TIMEOUT_MS = 5000;
const MOCK_NOTES_STORAGE_KEY = 'webview-app.chain-notes';

let defaultTimeoutMs = DEFAULT_TIMEOUT_MS;
let mockNotes = loadMockNotes();
let nextMockNoteId =
  mockNotes.reduce((highest, note) => {
    const match = /^note-mock-(\d+)$/.exec(note.id || '');
    return Math.max(highest, match ? Number(match[1]) : 0);
  }, 0) + 1;

function loadMockNotes() {
  try {
    const raw = globalThis.window?.localStorage?.getItem(
      MOCK_NOTES_STORAGE_KEY
    );
    const notes = raw ? JSON.parse(raw) : [];
    return Array.isArray(notes) ? notes : [];
  } catch {
    // Native WebViews can expose an opaque origin where localStorage throws.
    return [];
  }
}

function persistMockNotes() {
  try {
    globalThis.window?.localStorage?.setItem(
      MOCK_NOTES_STORAGE_KEY,
      JSON.stringify(mockNotes)
    );
  } catch {
    // The in-memory mock remains usable when browser storage is unavailable.
  }
}

export function setDefaultTimeout(ms) {
  defaultTimeoutMs = typeof ms === 'number' && ms > 0 ? ms : DEFAULT_TIMEOUT_MS;
}

export function getDefaultTimeout() {
  return defaultTimeoutMs;
}

function hasBinding(name) {
  return typeof window !== 'undefined' && typeof window[name] === 'function';
}

function mockValue(name) {
  switch (name) {
    case 'increment':
    case 'reset':
      return 0;
    case 'getSystemInfo':
      return 'Browser mock';
    case 'getTimestamp':
      return String(Math.floor(Date.now() / 1000));
    case 'getStatus':
      return 'ok';
    default:
      return undefined;
  }
}

function friendlyMessage(code, fallback) {
  switch (code) {
    case 'MalformedJson':
      return 'The request was not valid JSON.';
    case 'NotArgumentArray':
      return 'The request arguments must be a JSON array.';
    case 'WrongArgumentCount':
      return 'The request takes exactly one argument.';
    case 'NonIntegerArgument':
      return 'The counter delta must be an integer.';
    case 'InvalidArgument':
      return 'A backend argument was invalid.';
    case 'WindowUnavailable':
      return 'The native window is unavailable.';
    case 'WindowActionFailed':
      return 'The window action failed.';
    case 'Timeout':
      return fallback || 'The backend request timed out.';
    case 'Unavailable':
      return fallback || 'The backend is unavailable outside the native shell.';
    case 'StorageUnavailable':
      return 'Persistent storage is unavailable.';
    case 'StorageCorrupt':
      return 'Persistent note data is corrupt.';
    case 'StorageWriteFailed':
      return 'The note could not be saved.';
    case 'NoteNotFound':
      return 'The note no longer exists.';
    case 'InvalidPdfName':
      return 'The PDF filename is invalid.';
    case 'PdfTooLarge':
      return 'The PDF is too large.';
    case 'PdfDecodeFailed':
      return 'The PDF data could not be decoded.';
    case 'DocumentsUnavailable':
      return 'The documents folder is unavailable.';
    case 'PdfWriteFailed':
      return 'The PDF could not be saved.';
    default:
      return fallback || code;
  }
}

/**
 * Normalize any backend failure into `{ code, message }`.
 * Codes are stable PascalCase tokens for UI switching; messages are display-ready.
 */
export function errorDetails(error) {
  if (error && typeof error === 'object' && typeof error.code === 'string') {
    const message =
      typeof error.message === 'string' && error.message
        ? error.message
        : friendlyMessage(error.code, '');
    return { code: error.code, message: message || error.code };
  }

  const raw = error instanceof Error ? error.message : String(error ?? '');

  if (raw) {
    try {
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed.code === 'string') {
        return {
          code: parsed.code,
          message:
            typeof parsed.message === 'string' && parsed.message
              ? parsed.message
              : friendlyMessage(parsed.code, raw)
        };
      }
    } catch {
      // Not an envelope; fall through to bare-name handling.
    }

    const name = raw.replace(/^"|"$/g, '');
    if (/^[A-Z][A-Za-z]*$/.test(name)) {
      return { code: name, message: friendlyMessage(name, raw) };
    }
  }

  return { code: 'Unknown', message: raw || 'Backend request failed' };
}

export function backendError(error) {
  return errorDetails(error).message;
}

function withTimeout(promise, name, ms) {
  let timer = null;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => {
      const error = new Error(`${name} timed out after ${ms}ms`);
      error.code = 'Timeout';
      reject(error);
    }, ms);
  });
  return Promise.race([
    Promise.resolve(promise).finally(() => {
      if (timer !== null) clearTimeout(timer);
    }),
    timeout
  ]);
}

function unavailable(name) {
  const error = new Error(`${name} is unavailable outside the native shell`);
  error.code = 'Unavailable';
  return Promise.reject(error);
}

function invalidArgument(message) {
  const error = new Error(message);
  error.code = 'InvalidArgument';
  return Promise.reject(error);
}

function validateNoteFields(id, title, tag, body) {
  if (id !== undefined && (typeof id !== 'string' || id.length === 0)) {
    return 'note id is required';
  }
  if (typeof title !== 'string' || title.trim().length === 0) {
    return 'note title is required';
  }
  if (title.length > 200) return 'note title is too long';
  if (typeof tag !== 'string' || tag.length > 64) return 'note tag is too long';
  if (typeof body !== 'string' || body.length > 512 * 1024) {
    return 'note body is too long';
  }
  return null;
}

function mockNote(title, tag, body) {
  return {
    id: `note-mock-${nextMockNoteId++}`,
    title: title.trim(),
    tag: tag || 'Draft',
    updated: 'Just now',
    body
  };
}

function callBinding(name, ...args) {
  let result;
  if (hasBinding(name)) {
    try {
      result = window[name](...args);
    } catch (error) {
      result = Promise.reject(error);
    }
  } else if (
    typeof window !== 'undefined' &&
    window.__PREACT_MOCK_BRIDGE__ === false
  ) {
    result = unavailable(name);
  } else {
    if (name === 'getNotes') {
      result = Promise.resolve(mockNotes.map((note) => ({ ...note })));
    } else if (name === 'createNote') {
      const note = mockNote(...args);
      mockNotes = [...mockNotes, note];
      persistMockNotes();
      result = Promise.resolve({ ...note });
    } else if (name === 'updateNote') {
      const [id, title, tag, body] = args;
      const note = mockNotes.find((item) => item.id === id);
      if (!note) result = Promise.reject(new Error('NoteNotFound'));
      else {
        const updated = {
          ...note,
          title: title.trim(),
          tag: tag || 'Draft',
          body,
          updated: 'Just now'
        };
        mockNotes = mockNotes.map((item) => (item.id === id ? updated : item));
        persistMockNotes();
        result = Promise.resolve({ ...updated });
      }
    } else if (name === 'deleteNote') {
      mockNotes = mockNotes.filter((note) => note.id !== args[0]);
      persistMockNotes();
      result = Promise.resolve(undefined);
    } else if (name === 'savePdf') {
      result = Promise.resolve({ path: `Documents/${args[0]}` });
    } else {
      result = Promise.resolve(mockValue(name));
    }
  }
  return withTimeout(result, name, defaultTimeoutMs);
}

const CORE_BINDINGS = [
  'increment',
  'reset',
  'getSystemInfo',
  'getTimestamp',
  'getStatus',
  'getNotes',
  'createNote',
  'updateNote',
  'deleteNote',
  'savePdf',
  'minimizeWindow',
  'maximizeWindow',
  'restoreWindow',
  'closeWindow'
];

export const backend = {
  isNative: () => CORE_BINDINGS.every(hasBinding),
  increment: (delta) => {
    if (typeof delta !== 'number' || !Number.isInteger(delta)) {
      return invalidArgument('increment delta must be an integer');
    }
    return callBinding('increment', delta);
  },
  reset: () => callBinding('reset'),
  getSystemInfo: () => callBinding('getSystemInfo'),
  getTimestamp: () => callBinding('getTimestamp'),
  getStatus: () => callBinding('getStatus'),
  getNotes: () => callBinding('getNotes'),
  createNote: (title, tag, body) => {
    const validationError = validateNoteFields(undefined, title, tag, body);
    return validationError
      ? invalidArgument(validationError)
      : callBinding('createNote', title, tag, body);
  },
  updateNote: (id, title, tag, body) => {
    const validationError = validateNoteFields(id, title, tag, body);
    return validationError
      ? invalidArgument(validationError)
      : callBinding('updateNote', id, title, tag, body);
  },
  deleteNote: (id) =>
    typeof id !== 'string' || id.length === 0
      ? invalidArgument('note id is required')
      : callBinding('deleteNote', id),
  savePdf: (filename, dataBase64) => {
    if (
      typeof filename !== 'string' ||
      !/^[A-Za-z0-9][A-Za-z0-9._-]{0,95}\.pdf$/.test(filename) ||
      filename.length > 100
    ) {
      return invalidArgument('pdf filename is invalid');
    }
    if (
      typeof dataBase64 !== 'string' ||
      dataBase64.length === 0 ||
      dataBase64.length > 22400000
    ) {
      return invalidArgument('pdf data is invalid');
    }
    return callBinding('savePdf', filename, dataBase64);
  },
  minimizeWindow: () => callBinding('minimizeWindow'),
  maximizeWindow: () => callBinding('maximizeWindow'),
  restoreWindow: () => callBinding('restoreWindow'),
  closeWindow: () => callBinding('closeWindow')
};

export function backendErrorWithCode(error) {
  const details = errorDetails(error);
  return `${details.message} (${details.code})`;
}
