import { useMemo, useState } from 'preact/hooks';
import { backend, backendError } from './backend.js';
import { BackendStatus } from './backend-status.jsx';
import { frontendPlugins, getFrontendPlugin } from './plugins/index.js';
import {
  buildMonthGrid,
  formatDay,
  shiftMonth,
  todayISO
} from './plugins/todo-calendar.js';
import { styles, sx, toneStyle } from './stylex-styles.js';

const TAB_SHORT = {
  disk: 'Disk',
  equalizer: 'EQ',
  notes: 'Notes',
  todos: 'Todos',
  quiz: 'Quiz',
  paper: 'Paper'
};

const TAB_GLYPH = {
  disk: '◉',
  equalizer: '♪',
  notes: '✎',
  todos: '✓',
  quiz: '?',
  paper: '§'
};

// Plugin ids grouped under the Tools submenu instead of the primary rail.
const TOOL_IDS = ['disk', 'equalizer'];
const TOOLS_GLYPH = '▤';
const QUIZ_GLYPH = '?';

export function App() {
  const [activeApp, setActiveApp] = useState(null);
  const [openedApps, setOpenedApps] = useState([]);
  const [toolsOpen, setToolsOpen] = useState(false);
  const [quizOpen, setQuizOpen] = useState(false);
  const [quizMode, setQuizMode] = useState('session');
  const [paperOpen, setPaperOpen] = useState(false);
  const [paperMode, setPaperMode] = useState('read');
  const [todoOpen, setTodoOpen] = useState(false);
  const [todoMode, setTodoMode] = useState('tasks');
  const [todoFocus, setTodoFocus] = useState(null);
  const [todoCursor, setTodoCursor] = useState(() => todayISO().slice(0, 7));
  const [windowActionPending, setWindowActionPending] = useState(false);
  const [windowError, setWindowError] = useState('');
  const [windowMaximized, setWindowMaximized] = useState(false);
  const [isNative] = useState(() => backend.isNative());

  const openedWorkspaces = useMemo(
    () => frontendPlugins.filter((plugin) => openedApps.includes(plugin.id)),
    [openedApps]
  );
  const primaryPlugins = useMemo(
    () => frontendPlugins.filter((plugin) => !TOOL_IDS.includes(plugin.id)),
    []
  );
  const toolPlugins = useMemo(
    () => frontendPlugins.filter((plugin) => TOOL_IDS.includes(plugin.id)),
    []
  );
  const currentApp = getFrontendPlugin(activeApp);
  const ActivePlugin = currentApp?.component;
  const activeIsTool = activeApp !== null && TOOL_IDS.includes(activeApp);

  function selectApp(appId) {
    if (windowActionPending) return;
    setWindowError('');
    setOpenedApps((current) =>
      current.includes(appId) ? current : [...current, appId]
    );
    setActiveApp(appId);
    // Each expandable group stays open only while its own destination is active.
    setToolsOpen(TOOL_IDS.includes(appId));
    setQuizOpen(appId === 'quiz');
    setPaperOpen(appId === 'paper');
    setTodoOpen(appId === 'todos');
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
    setToolsOpen(false);
    setQuizOpen(false);
    setPaperOpen(false);
    setTodoOpen(false);
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

  const rail = (
    <nav className={sx('rail')} aria-label="Primary">
      <button
        type="button"
        className={sx('tab', activeApp === null && styles.tabActive)}
        onClick={goHome}
        aria-current={activeApp === null ? 'page' : undefined}
        title="Home"
      >
        <span className={sx('tab-glyph')} aria-hidden="true">
          ⌂
        </span>
        <span className={sx('tab-label')}>Home</span>
      </button>
      {primaryPlugins.map((app) => (
        <button
          type="button"
          key={app.id}
          className={sx(
            'tab',
            activeApp === app.id && styles.tabActive,
            toneStyle(app.tone)
          )}
          onClick={() => {
            if (app.id === 'quiz') {
              if (activeApp !== 'quiz') {
                selectApp(app.id);
                setQuizMode('session');
                setQuizOpen(true);
                return;
              }
              setQuizMode('session');
              setTodoOpen(false);
              setQuizOpen((open) => !open);
              return;
            }
            if (app.id === 'paper') {
              if (activeApp !== 'paper') {
                selectApp(app.id);
                setPaperMode('read');
                setPaperOpen(true);
                return;
              }
              setPaperMode('read');
              setToolsOpen(false);
              setQuizOpen(false);
              setTodoOpen(false);
              setPaperOpen((open) => !open);
              return;
            }
            if (app.id === 'todos') {
              if (activeApp !== 'todos') {
                selectApp(app.id);
                setTodoMode('tasks');
                setTodoOpen(true);
                return;
              }
              setTodoMode('tasks');
              setToolsOpen(false);
              setQuizOpen(false);
              setPaperOpen(false);
              setTodoOpen((open) => !open);
              return;
            }
            selectApp(app.id);
          }}
          aria-current={activeApp === app.id ? 'page' : undefined}
          aria-expanded={
            app.id === 'quiz'
              ? quizOpen
              : app.id === 'paper'
                ? paperOpen
                : app.id === 'todos'
                  ? todoOpen
                  : undefined
          }
          aria-controls={
            app.id === 'quiz'
              ? 'quiz-panel'
              : app.id === 'paper'
                ? 'paper-panel'
                : app.id === 'todos'
                  ? 'todo-panel'
                  : undefined
          }
          title={app.title}
        >
          <span className={sx('tab-glyph')} aria-hidden="true">
            {app.id === 'quiz' ? QUIZ_GLYPH : (TAB_GLYPH[app.id] ?? '•')}
          </span>
          <span className={sx('tab-label')}>
            {TAB_SHORT[app.id] ?? app.title}
          </span>
          {openedApps.includes(app.id) && (
            <span
              className={sx('tab-dot', toneStyle(app.tone, 'dot'))}
              aria-hidden="true"
            />
          )}
        </button>
      ))}
      <button
        type="button"
        className={sx('tab', activeIsTool && styles.tabActive)}
        onClick={() => {
          setQuizOpen(false);
          setPaperOpen(false);
          setTodoOpen(false);
          setToolsOpen((open) => !open);
        }}
        aria-expanded={toolsOpen}
        aria-controls="tools-panel"
        title="Tools"
      >
        <span className={sx('tab-glyph')} aria-hidden="true">
          {TOOLS_GLYPH}
        </span>
        <span className={sx('tab-label')}>Tools</span>
        {toolPlugins.some((app) => openedApps.includes(app.id)) && (
          <span className={sx('tab-dot')} aria-hidden="true" />
        )}
      </button>
    </nav>
  );

  const toolsPanel = toolsOpen && (
    <aside
      className={sx('tools-panel')}
      id="tools-panel"
      aria-label="Tools submenu"
    >
      <p className={sx('tools-group-label')}>Tools</p>
      <nav className={sx('sideNav')} aria-label="Tool plugins">
        {toolPlugins.map((app) => (
          <button
            type="button"
            key={app.id}
            className={sx(
              'tools-item',
              activeApp === app.id && styles.sideItemActive
            )}
            onClick={() => selectApp(app.id)}
            aria-current={activeApp === app.id ? 'page' : undefined}
          >
            <span
              className={sx('tools-item-glyph', toneStyle(app.tone))}
              aria-hidden="true"
            >
              {TAB_GLYPH[app.id] ?? '•'}
            </span>
            <span className={sx('tools-item-copy')}>
              <strong className={sx('sideCopyStrong')}>{app.title}</strong>
              <small className={sx('sideCopySmall')}>{app.description}</small>
            </span>
            {openedApps.includes(app.id) && (
              <span
                className={sx('tab-dot', toneStyle(app.tone, 'dot'))}
                aria-hidden="true"
              />
            )}
          </button>
        ))}
      </nav>
    </aside>
  );

  const quizPanel = quizOpen && (
    <aside
      className={sx('quiz-panel')}
      id="quiz-panel"
      aria-label="Quiz submenu"
    >
      <p className={sx('tools-group-label')}>Quiz</p>
      <nav className={sx('sideNav')} aria-label="Quiz destinations">
        <button
          type="button"
          className={sx(
            'tools-item',
            quizMode === 'session' && styles.sideItemActive
          )}
          onClick={() => {
            selectApp('quiz');
            setQuizMode('session');
          }}
          aria-current={quizMode === 'session' ? 'page' : undefined}
        >
          <span
            className={sx('tools-item-glyph', styles.purple)}
            aria-hidden="true"
          >
            ▶
          </span>
          <span className={sx('tools-item-copy')}>
            <strong className={sx('sideCopyStrong')}>Quiz Session</strong>
            <small className={sx('sideCopySmall')}>
              Review cards and track what you know.
            </small>
          </span>
        </button>
        <button
          type="button"
          className={sx(
            'tools-item',
            quizMode === 'editor' && styles.sideItemActive
          )}
          onClick={() => {
            selectApp('quiz');
            setQuizMode('editor');
          }}
          aria-current={quizMode === 'editor' ? 'page' : undefined}
        >
          <span
            className={sx('tools-item-glyph', styles.purple)}
            aria-hidden="true"
          >
            ✦
          </span>
          <span className={sx('tools-item-copy')}>
            <strong className={sx('sideCopyStrong')}>Quiz Editor</strong>
            <small className={sx('sideCopySmall')}>
              Browse and curate your question decks.
            </small>
          </span>
        </button>
      </nav>
    </aside>
  );

  const paperDestinations = [
    {
      mode: 'read',
      glyph: '▶',
      title: 'Reader',
      description: 'Two-column reading with section navigation.'
    },
    {
      mode: 'references',
      glyph: '≡',
      title: 'Reference Manager',
      description: 'Track citations and export BibTeX.'
    },
    {
      mode: 'images',
      glyph: '◫',
      title: 'Image Assets',
      description: 'Manage figures embedded in the paper.'
    }
  ];

  const paperPanel = paperOpen && (
    <aside
      className={sx('quiz-panel')}
      id="paper-panel"
      aria-label="Paper submenu"
    >
      <p className={sx('tools-group-label')}>Paper</p>
      <nav className={sx('sideNav')} aria-label="Paper destinations">
        {paperDestinations.map((destination) => (
          <button
            type="button"
            key={destination.mode}
            className={sx(
              'tools-item',
              paperMode === destination.mode && styles.sideItemActive
            )}
            onClick={() => {
              selectApp('paper');
              setPaperMode(destination.mode);
            }}
            aria-current={paperMode === destination.mode ? 'page' : undefined}
          >
            <span
              className={sx('tools-item-glyph', styles.greenMark)}
              aria-hidden="true"
            >
              {destination.glyph}
            </span>
            <span className={sx('tools-item-copy')}>
              <strong className={sx('sideCopyStrong')}>
                {destination.title}
              </strong>
              <small className={sx('sideCopySmall')}>
                {destination.description}
              </small>
            </span>
          </button>
        ))}
      </nav>
    </aside>
  );

  const todoDestinations = [
    {
      mode: 'tasks',
      glyph: '☰',
      title: 'Tasks',
      description: 'Capture and complete todos.'
    },
    {
      mode: 'calendar',
      glyph: '◫',
      title: 'Calendar',
      description: 'Browse due dates by month.'
    }
  ];
  const todoGrid = buildMonthGrid(todoCursor);

  const todoPanel = todoOpen && (
    <aside
      className={sx('quiz-panel')}
      id="todo-panel"
      aria-label="Todos submenu"
    >
      <p className={sx('tools-group-label')}>Todos</p>
      <nav className={sx('sideNav')} aria-label="Todos destinations">
        {todoDestinations.map((destination) => (
          <button
            type="button"
            key={destination.mode}
            className={sx(
              'tools-item',
              todoMode === destination.mode && styles.sideItemActive
            )}
            onClick={() => {
              selectApp('todos');
              setTodoMode(destination.mode);
            }}
            aria-current={todoMode === destination.mode ? 'page' : undefined}
          >
            <span
              className={sx('tools-item-glyph', styles.goldMark)}
              aria-hidden="true"
            >
              {destination.glyph}
            </span>
            <span className={sx('tools-item-copy')}>
              <strong className={sx('sideCopyStrong')}>
                {destination.title}
              </strong>
              <small className={sx('sideCopySmall')}>
                {destination.description}
              </small>
            </span>
          </button>
        ))}
      </nav>
      <p className={sx('tools-group-label')}>Pick a day</p>
      <div className={sx('notes-list-heading')}>
        <button
          type="button"
          className={sx('text-button')}
          onClick={() => setTodoCursor(shiftMonth(todoCursor, -1))}
          aria-label="Previous month"
        >
          ‹
        </button>
        <span className={sx('panel-label')}>{todoGrid.label}</span>
        <button
          type="button"
          className={sx('text-button')}
          onClick={() => setTodoCursor(shiftMonth(todoCursor, 1))}
          aria-label="Next month"
        >
          ›
        </button>
      </div>
      <div className={sx('cal-grid')}>
        {['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'].map((day) => (
          <span key={day} className={sx('cal-dow')}>
            {day}
          </span>
        ))}
        {todoGrid.weeks.flat().map((cell, index) => {
          if (!cell) return <span key={`blank-${index}`} />;
          return (
            <button
              type="button"
              key={cell.iso}
              aria-label={`Pick ${cell.iso}`}
              className={sx(
                'cal-cell',
                cell.iso === todoFocus && styles.calSelected,
                cell.iso === todayISO() && styles.calToday
              )}
              onClick={() =>
                setTodoFocus(todoFocus === cell.iso ? null : cell.iso)
              }
            >
              <span>{cell.day}</span>
            </button>
          );
        })}
      </div>
      {todoFocus && (
        <button
          type="button"
          className={sx('chip')}
          onClick={() => setTodoFocus(null)}
        >
          Due {formatDay(todoFocus)} ×
        </button>
      )}
    </aside>
  );

  if (activeApp === null) {
    return (
      <div className={sx('shell')}>
        <header className={sx('topbar')}>
          <span className={sx('brand-mark')}>WV</span>
          <span className={sx('brand-name')}>WebView</span>
          <span className={sx('topbar-status')}>
            <span className={sx('status-dot')} aria-hidden="true" />
            <span>{isNative ? 'Native' : 'Mock'}</span>
          </span>
        </header>

        <main className={sx('launcher-main')}>
          <div>
            <p className={sx('eyebrow')}>Toolkit</p>
            <h1 className={sx('launcherTitle')}>Tools</h1>
            <p className={sx('lede')}>
              {frontendPlugins.length} small utilities. Pick one to start.
            </p>
          </div>

          {windowError && (
            <p className={sx('error')} role="alert">
              {windowError}
            </p>
          )}

          <nav className={sx('tool-list')} aria-label="Available tools">
            {frontendPlugins.map((app) => (
              <button
                type="button"
                key={app.id}
                className={sx('tool-row')}
                onClick={() => selectApp(app.id)}
              >
                <span
                  className={sx('row-glyph', toneStyle(app.tone))}
                  aria-hidden="true"
                >
                  {TAB_GLYPH[app.id] ?? '•'}
                </span>
                <span className={sx('row-copy')}>
                  <strong className={sx('rowCopyStrong')}>{app.title}</strong>
                  <small className={sx('rowCopySmall')}>
                    {app.description}
                  </small>
                </span>
                <span
                  className={sx('row-chevron', toneStyle(app.tone))}
                  aria-hidden="true"
                >
                  ›
                </span>
              </button>
            ))}
          </nav>

          <div className={sx('launcher-status')}>
            <BackendStatus compact />
          </div>
        </main>

        {rail}
        {toolsPanel}
        {quizPanel}
        {paperPanel}
        {todoPanel}
      </div>
    );
  }

  return (
    <div className={sx('shell')}>
      <header className={sx('topbar', 'workspace-topbar')}>
        <button
          type="button"
          className={sx('back-button')}
          onClick={goHome}
          aria-label="Back to tools"
        >
          <span aria-hidden="true">‹</span>
          <span className={sx('back-label')}>Tools</span>
        </button>
        <div className={sx('titlebar-name')}>
          <span
            className={sx('titlebar-dot', toneStyle(currentApp.tone, 'dot'))}
            aria-hidden="true"
          />
          <strong className={sx('titlebarStrong')}>{currentApp.title}</strong>
        </div>
        {isNative ? (
          <div className={sx('window-actions')}>
            <button
              type="button"
              className={sx('windowAction')}
              onClick={minimizeWindow}
              disabled={windowActionPending}
              aria-label="Minimize window"
            >
              –
            </button>
            <button
              type="button"
              className={sx('windowAction')}
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
              className={sx('windowAction', 'close-button')}
              onClick={closeWindow}
              disabled={windowActionPending}
              aria-label="Close window"
            >
              ×
            </button>
          </div>
        ) : (
          <span className={sx('topbar-status')}>
            <span className={sx('status-dot')} aria-hidden="true" />
            <span>Mock</span>
          </span>
        )}
      </header>

      {windowError && (
        <p className={sx('error', 'workspace-error')} role="alert">
          {windowError}
        </p>
      )}

      {openedWorkspaces.length > 1 && (
        <section className={sx('recent-strip')} aria-label="Recently opened">
          {openedWorkspaces
            .filter((app) => app.id !== activeApp)
            .map((app) => (
              <button
                type="button"
                key={app.id}
                className={sx('chip')}
                onClick={() => selectApp(app.id)}
              >
                {TAB_SHORT[app.id] ?? app.title}
              </button>
            ))}
        </section>
      )}

      <main className={sx('workspace-body')}>
        <ActivePlugin
          mode={
            activeApp === 'quiz'
              ? quizMode
              : activeApp === 'paper'
                ? paperMode
                : activeApp === 'todos'
                  ? todoMode
                  : undefined
          }
          focusDate={activeApp === 'todos' ? todoFocus : undefined}
          onFocusDate={setTodoFocus}
          cursor={activeApp === 'todos' ? todoCursor : undefined}
          onCursor={setTodoCursor}
          onPickDate={() => setTodoMode('tasks')}
        />
      </main>

      {rail}
      {toolsPanel}
      {quizPanel}
      {paperPanel}
      {todoPanel}
    </div>
  );
}
