import { useMemo, useState } from 'preact/hooks';
import { backend, backendError } from './backend.js';
import { BackendStatus } from './backend-status.jsx';
import { frontendPlugins, getFrontendPlugin } from './plugins/index.js';

const TAB_SHORT = {
  disk: 'Disk',
  equalizer: 'EQ',
  notes: 'Notes',
  todos: 'Todos'
};

const TAB_GLYPH = {
  disk: '◉',
  equalizer: '♪',
  notes: '✎',
  todos: '✓'
};

export function App() {
  const [activeApp, setActiveApp] = useState(null);
  const [openedApps, setOpenedApps] = useState([]);
  const [windowActionPending, setWindowActionPending] = useState(false);
  const [windowError, setWindowError] = useState('');
  const [windowMaximized, setWindowMaximized] = useState(false);
  const [isNative] = useState(() => backend.isNative());

  const openedWorkspaces = useMemo(
    () => frontendPlugins.filter((plugin) => openedApps.includes(plugin.id)),
    [openedApps]
  );
  const currentApp = getFrontendPlugin(activeApp);
  const ActivePlugin = currentApp?.component;

  function selectApp(appId) {
    if (windowActionPending) return;
    setWindowError('');
    setOpenedApps((current) =>
      current.includes(appId) ? current : [...current, appId]
    );
    setActiveApp(appId);
    if (typeof document !== 'undefined') {
      const plugin = getFrontendPlugin(appId);
      document.title = plugin ? `${plugin.title} - WebView App` : 'WebView App';
      window.scrollTo?.(0, 0);
    }
  }

  function goHome() {
    if (windowActionPending) return;
    setWindowError('');
    setActiveApp(null);
    if (typeof document !== 'undefined') {
      document.title = 'WebView App';
      window.scrollTo?.(0, 0);
    }
  }

  async function runWindowAction(fn, onDone) {
    if (windowActionPending) return;
    setWindowActionPending(true);
    setWindowError('');
    try {
      await fn();
      onDone?.();
    } catch (error) {
      setWindowError(backendError(error));
    } finally {
      setWindowActionPending(false);
    }
  }

  const minimizeWindow = () => runWindowAction(() => backend.minimizeWindow());
  const toggleMaximize = () =>
    runWindowAction(
      () =>
        windowMaximized ? backend.restoreWindow() : backend.maximizeWindow(),
      () => setWindowMaximized((value) => !value)
    );
  const closeWindow = () => runWindowAction(() => backend.closeWindow());

  const tabBar = (
    <nav className="tabbar" aria-label="Primary">
      <button
        type="button"
        className={`tab${activeApp === null ? ' active' : ''}`}
        onClick={goHome}
        aria-current={activeApp === null ? 'page' : undefined}
      >
        <span className="tab-glyph" aria-hidden="true">
          ⌂
        </span>
        <span className="tab-label">Home</span>
      </button>
      {frontendPlugins.map((app) => (
        <button
          type="button"
          key={app.id}
          className={`tab tone-${app.tone}${activeApp === app.id ? ' active' : ''}`}
          onClick={() => selectApp(app.id)}
          aria-current={activeApp === app.id ? 'page' : undefined}
        >
          <span className="tab-glyph" aria-hidden="true">
            {TAB_GLYPH[app.id] ?? '•'}
          </span>
          <span className="tab-label">{TAB_SHORT[app.id] ?? app.title}</span>
          {openedApps.includes(app.id) && (
            <span className="tab-dot" aria-hidden="true" />
          )}
        </button>
      ))}
    </nav>
  );

  if (activeApp === null) {
    return (
      <div className="shell">
        <header className="topbar">
          <span className="brand-mark">WV</span>
          <span className="brand-name">WebView</span>
          <span className="topbar-status">
            <span className="status-dot" aria-hidden="true" />
            <span>{isNative ? 'Native' : 'Mock'}</span>
          </span>
        </header>

        <main className="launcher-main">
          <div className="launcher-head">
            <p className="eyebrow">Toolkit</p>
            <h1>Tools</h1>
            <p className="lede">
              {frontendPlugins.length} small utilities. Pick one to start.
            </p>
          </div>

          {windowError && (
            <p className="error" role="alert">
              {windowError}
            </p>
          )}

          <nav className="tool-list" aria-label="Available tools">
            {frontendPlugins.map((app) => (
              <button
                type="button"
                key={app.id}
                className={`tool-row tone-${app.tone}`}
                onClick={() => selectApp(app.id)}
              >
                <span
                  className={`row-glyph tone-${app.tone}`}
                  aria-hidden="true"
                >
                  {TAB_GLYPH[app.id] ?? '•'}
                </span>
                <span className="row-copy">
                  <strong>{app.title}</strong>
                  <small>{app.description}</small>
                </span>
                <span className="row-chevron" aria-hidden="true">
                  ›
                </span>
              </button>
            ))}
          </nav>

          <div className="launcher-status">
            <BackendStatus compact />
          </div>
        </main>

        {tabBar}
      </div>
    );
  }

  return (
    <div className="shell">
      <header className="topbar workspace-topbar">
        <button
          type="button"
          className="back-button"
          onClick={goHome}
          aria-label="Back to tools"
        >
          <span aria-hidden="true">‹</span>
          <span className="back-label">Tools</span>
        </button>
        <div className="titlebar-name">
          <span
            className={`titlebar-dot tone-${currentApp.tone}`}
            aria-hidden="true"
          />
          <strong>{currentApp.title}</strong>
        </div>
        {isNative ? (
          <div className="window-actions">
            <button
              type="button"
              onClick={minimizeWindow}
              disabled={windowActionPending}
              aria-label="Minimize window"
            >
              –
            </button>
            <button
              type="button"
              onClick={toggleMaximize}
              disabled={windowActionPending}
              aria-label={
                windowMaximized ? 'Restore window' : 'Maximize window'
              }
            >
              {windowMaximized ? '❐' : '□'}
            </button>
            <button
              type="button"
              className="close-button"
              onClick={closeWindow}
              disabled={windowActionPending}
              aria-label="Close window"
            >
              ×
            </button>
          </div>
        ) : (
          <span className="topbar-status">
            <span className="status-dot" aria-hidden="true" />
            <span>Mock</span>
          </span>
        )}
      </header>

      {windowError && (
        <p className="error workspace-error" role="alert">
          {windowError}
        </p>
      )}

      {openedWorkspaces.length > 1 && (
        <section className="recent-strip" aria-label="Recently opened">
          {openedWorkspaces
            .filter((app) => app.id !== activeApp)
            .map((app) => (
              <button
                type="button"
                key={app.id}
                className="chip"
                onClick={() => selectApp(app.id)}
              >
                {TAB_SHORT[app.id] ?? app.title}
              </button>
            ))}
        </section>
      )}

      <main className="workspace-body">
        <ActivePlugin />
      </main>

      {tabBar}
    </div>
  );
}
