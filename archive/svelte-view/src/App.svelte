<script>
  import { frontendPlugins, getFrontendPlugin } from "./plugins/index.js";

  let activeApp = $state(null);
  let openedApps = $state([]);
  let openedWorkspaces = $derived(frontendPlugins.filter((plugin) => openedApps.includes(plugin.id)));
  let currentApp = $derived(getFrontendPlugin(activeApp));
  let ActivePlugin = $derived(currentApp?.component);
  let windowActionPending = $state(false);
  let windowError = $state("");
  let windowMaximized = $state(false);

  function errorMessage(error) {
    return error instanceof Error ? error.message : String(error);
  }

  async function openApp(appId) {
    if (windowActionPending) return;
    windowActionPending = true;
    windowError = "";
    try {
      if (!openedApps.includes(appId)) openedApps = [...openedApps, appId];
      activeApp = appId;
    } catch (error) {
      windowError = errorMessage(error);
    } finally {
      windowActionPending = false;
    }
  }

  async function returnToLauncher() {
    if (windowActionPending) return;
    windowActionPending = true;
    windowError = "";
    try {
      activeApp = null;
    } catch (error) {
      windowError = errorMessage(error);
    } finally {
      windowActionPending = false;
    }
  }

  async function minimizeWindow() {
    if (windowActionPending) return;
    windowActionPending = true;
    windowError = "";
    try {
      await window.minimizeWindow();
    } catch (error) {
      windowError = errorMessage(error);
    } finally {
      windowActionPending = false;
    }
  }

  async function toggleMaximize() {
    if (windowActionPending) return;
    windowActionPending = true;
    windowError = "";
    try {
      if (windowMaximized) await window.restoreWindow();
      else await window.maximizeWindow();
      windowMaximized = !windowMaximized;
    } catch (error) {
      windowError = errorMessage(error);
    } finally {
      windowActionPending = false;
    }
  }

  async function closeWindow() {
    if (windowActionPending) return;
    windowActionPending = true;
    windowError = "";
    try {
      await window.closeWindow();
    } catch (error) {
      windowError = errorMessage(error);
      windowActionPending = false;
    }
  }

</script>

<svelte:head>
  <title>{currentApp ? `${currentApp.title} - WebView App` : "WebView App"}</title>
</svelte:head>

<div class="shell">
  {#if activeApp === null}
    <div class="launcher">
      <aside class="sidebar">
        <div class="brand-mark">WV</div>
        <div class="brand-copy">
          <span>WebView</span>
          <small>Toolkit collection</small>
        </div>
        <div class="side-label">Menu</div>
        <nav aria-label="Application menu">
           {#each frontendPlugins as app}
            <button class="menu-item" onclick={() => openApp(app.id)} disabled={windowActionPending}>
              <span class="menu-index">{app.index}</span>
              <span>{app.title}</span>
            </button>
          {/each}
        </nav>
        <div class="sidebar-foot">
          <span class="status-dot"></span>
          <span>Mock edition</span>
        </div>
      </aside>

      <main class="launcher-main">
        <header class="launcher-header">
          <div>
            <p class="eyebrow">Toolkit / Home</p>
            <h1>Pick a tool.</h1>
            <p class="lede">Three focused tools, designed now and ready for backend functionality later.</p>
          </div>
          <div class="header-meta">
            <span class="meta-label">Collection</span>
            <strong>Early access</strong>
          </div>
        </header>

        {#if windowError}
          <p class="error" role="alert">Window error: {windowError}</p>
        {/if}

        <section class="app-grid" aria-label="Available toolkit items">
           {#each frontendPlugins as app}
            <button class={`app-card tone-${app.tone}`} onclick={() => openApp(app.id)} disabled={windowActionPending}>
              <span class="card-topline">
                <span>{app.index}</span>
                <span class="open-label">Open</span>
              </span>
               <span class="card-symbol">{app.symbol}</span>
              <strong>{app.title}</strong>
              <span class="card-description">{app.description}</span>
              <span class="card-arrow" aria-hidden="true">-&gt;</span>
            </button>
          {/each}
        </section>

        <footer class="launcher-footer">
          <span>3 tools in collection</span>
          <span>Backend pending</span>
        </footer>
      </main>
    </div>
  {:else}
    <div class="workspace">
      <aside class="workspace-sidebar">
        <button class="home-button" onclick={returnToLauncher} disabled={windowActionPending} aria-label="Open home launcher">
          <span class="home-glyph" aria-hidden="true">WV</span>
          <span>Home</span>
        </button>
        <div class="rail-divider"></div>
        <nav class="workspace-nav" aria-label="Opened workspaces">
          {#each openedWorkspaces as app}
            <button
              class:active={activeApp === app.id}
              class={`workspace-menu-item tone-${app.tone}`}
              onclick={() => openApp(app.id)}
              disabled={windowActionPending}
              aria-current={activeApp === app.id ? "page" : undefined}
            >
              <span class="rail-index">{app.index}</span>
              <span class="rail-name">{app.title}</span>
            </button>
          {/each}
        </nav>
      </aside>

      <div class="workspace-stage">
        <header class="titlebar">
          <button class="back-button" onclick={returnToLauncher} disabled={windowActionPending}>
            <span aria-hidden="true">&lt;-</span>
            Launcher
          </button>
          <div class="titlebar-name">
            <span class={`titlebar-dot tone-${currentApp.tone}`}></span>
            <strong>{currentApp.title}</strong>
            <span class="titlebar-path">Mock workspace</span>
          </div>
          <div class="window-actions" aria-label="Window actions">
            <button onclick={minimizeWindow} disabled={windowActionPending} aria-label="Minimize window">Min</button>
            <button onclick={toggleMaximize} disabled={windowActionPending} aria-label={windowMaximized ? "Restore window" : "Maximize window"}>
              {windowMaximized ? "Restore" : "Max"}
            </button>
            <button class="close-button" onclick={closeWindow} disabled={windowActionPending} aria-label="Close window">Close</button>
          </div>
        </header>

        {#if windowError}
          <p class="error workspace-error" role="alert">Window error: {windowError}</p>
        {/if}

        <main class="workspace-body">
          <ActivePlugin />
        </main>
      </div>
    </div>
  {/if}
</div>

<style>
  :global {
  .shell {
    min-height: 100vh;
    background: radial-gradient(circle at 75% 0%, rgba(240, 107, 79, 0.11), transparent 28rem), var(--bg-primary);
  }

  button {
    border: 0;
    color: inherit;
    font: inherit;
    cursor: pointer;
  }

  button:focus-visible,
  select:focus-visible,
  input:focus-visible {
    outline: 2px solid #f7c66b;
    outline-offset: 3px;
  }

  button:disabled,
  select:disabled {
    cursor: wait;
    opacity: 0.55;
  }

  .launcher {
    display: block;
    min-height: 100vh;
  }

  .sidebar {
    position: fixed;
    top: 0;
    left: 0;
    z-index: 10;
    width: 250px;
    height: 100vh;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    padding: 2rem 1.25rem 1.5rem;
    border-right: 1px solid rgba(255, 255, 255, 0.08);
    background: rgba(16, 17, 19, 0.78);
  }

  .brand-mark {
    display: grid;
    place-items: center;
    width: 42px;
    height: 42px;
    border: 1px solid rgba(255, 255, 255, 0.22);
    border-radius: 12px;
    color: #f7c66b;
    font-size: 0.72rem;
    font-weight: 800;
    letter-spacing: 0.12em;
  }

  .brand-copy {
    display: flex;
    flex-direction: column;
    margin: 0.8rem 0 3.5rem;
    font-weight: 700;
    letter-spacing: -0.02em;
  }

  .brand-copy small {
    margin-top: 0.25rem;
    color: var(--text-secondary);
    font-size: 0.7rem;
    font-weight: 500;
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  .side-label,
  .eyebrow,
  .panel-label,
  .meta-label {
    color: var(--text-secondary);
    font-size: 0.68rem;
    font-weight: 700;
    letter-spacing: 0.14em;
    text-transform: uppercase;
  }

  .side-label {
    margin: 0 0 0.8rem 0.75rem;
  }

  nav {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }

  .menu-item {
    display: flex;
    align-items: center;
    gap: 0.8rem;
    padding: 0.75rem;
    border-radius: 9px;
    background: transparent;
    color: var(--text-secondary);
    text-align: left;
    transition: color 0.2s, background 0.2s;
  }

  .menu-item:hover {
    background: var(--bg-card);
    color: var(--text-primary);
  }

  .menu-index,
  .rail-index,
  .scan-time,
  .launcher-footer,
  .track-source,
  .band-label {
    font-family: "SF Mono", "Fira Code", monospace;
  }

  .menu-index {
    color: #6d7078;
    font-size: 0.7rem;
  }

  .sidebar-foot {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    margin-top: auto;
    color: var(--text-secondary);
    font-size: 0.75rem;
  }

  .status-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: var(--success);
    box-shadow: 0 0 12px rgba(130, 201, 155, 0.8);
  }

  .launcher-main {
    margin-left: 250px;
    display: flex;
    flex-direction: column;
    width: min(100%, 1180px);
    padding: 5rem clamp(2rem, 7vw, 7rem) 2rem;
  }

  .launcher-header,
  .tool-heading {
    display: flex;
    align-items: end;
    justify-content: space-between;
    gap: 2rem;
  }

  .launcher-header {
    margin-bottom: 3.5rem;
  }

  h1 {
    margin: 0.65rem 0 0;
    color: var(--text-primary);
    font-size: clamp(2.2rem, 5vw, 4.5rem);
    font-weight: 600;
    letter-spacing: -0.07em;
    line-height: 0.98;
  }

  h2 {
    margin-top: 0.35rem;
    color: var(--text-primary);
    font-size: 1.2rem;
    font-weight: 600;
    letter-spacing: -0.04em;
  }

  .lede,
  .tool-heading p:last-child {
    max-width: 34rem;
    margin-top: 1.15rem;
    color: var(--text-secondary);
    font-size: 1rem;
    line-height: 1.6;
  }

  .header-meta {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
    min-width: 130px;
    padding-bottom: 0.3rem;
    color: var(--text-primary);
    font-size: 0.8rem;
  }

  .app-grid {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 1rem;
  }

  .app-card {
    position: relative;
    display: flex;
    min-height: 300px;
    flex-direction: column;
    align-items: flex-start;
    padding: 1.35rem;
    overflow: hidden;
    border: 1px solid rgba(255, 255, 255, 0.08);
    border-radius: var(--border-radius);
    background: var(--bg-card);
    text-align: left;
    transition: border-color 0.2s, transform 0.2s, background 0.2s;
  }

  .app-card::after {
    position: absolute;
    right: -3rem;
    bottom: -5rem;
    width: 12rem;
    height: 12rem;
    border-radius: 50%;
    background: var(--card-color);
    content: "";
    filter: blur(45px);
    opacity: 0.12;
    transition: opacity 0.2s;
  }

  .app-card:hover {
    border-color: var(--card-color);
    background: #25272c;
    transform: translateY(-3px);
  }

  .app-card:hover::after {
    opacity: 0.25;
  }

  .tone-coral {
    --card-color: #f06b4f;
  }

  .tone-blue {
    --card-color: #77a6d8;
  }

  .tone-gold {
    --card-color: #f7c66b;
  }

  .card-topline {
    display: flex;
    width: 100%;
    justify-content: space-between;
    color: #6d7078;
    font-family: "SF Mono", "Fira Code", monospace;
    font-size: 0.72rem;
  }

  .open-label {
    color: var(--card-color);
    font-size: 0.65rem;
    letter-spacing: 0.12em;
    text-transform: uppercase;
  }

  .card-symbol {
    margin-top: auto;
    margin-bottom: 1.75rem;
    color: var(--card-color);
    font-family: "SF Mono", "Fira Code", monospace;
    font-size: 0.72rem;
    font-weight: 700;
    letter-spacing: 0.16em;
  }

  .app-card strong,
  .card-description {
    position: relative;
    z-index: 1;
  }

  .app-card strong {
    font-size: 1.3rem;
    font-weight: 600;
    letter-spacing: -0.04em;
  }

  .card-description {
    max-width: 18rem;
    margin-top: 0.45rem;
    color: var(--text-secondary);
    font-size: 0.82rem;
    line-height: 1.5;
  }

  .card-arrow {
    position: absolute;
    right: 1.35rem;
    bottom: 1.35rem;
    z-index: 1;
    color: var(--card-color);
    font-size: 1.1rem;
  }

  .launcher-footer {
    display: flex;
    justify-content: space-between;
    margin-top: auto;
    padding-top: 4rem;
    color: #666970;
    font-size: 0.68rem;
    text-transform: uppercase;
  }

  .workspace {
    display: block;
    min-height: 100vh;
  }

  .workspace-sidebar {
    position: fixed;
    top: 0;
    left: 0;
    z-index: 10;
    display: flex;
    height: 100vh;
    flex-direction: column;
    align-items: center;
    padding: 1rem 0.7rem;
    border-right: 1px solid rgba(255, 255, 255, 0.08);
    background: rgba(16, 17, 19, 0.88);
  }

  .home-button {
    display: flex;
    width: 100%;
    flex-direction: column;
    align-items: center;
    gap: 0.45rem;
    padding: 0.45rem 0.25rem 0.7rem;
    background: transparent;
    color: var(--text-secondary);
    font-size: 0.62rem;
    font-weight: 700;
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }

  .home-button:hover {
    color: var(--text-primary);
  }

  .home-glyph {
    display: grid;
    width: 38px;
    height: 38px;
    place-items: center;
    border: 1px solid rgba(247, 198, 107, 0.5);
    border-radius: 11px;
    color: #f7c66b;
    font-size: 0.65rem;
    letter-spacing: 0.08em;
  }

  .rail-divider {
    width: 30px;
    height: 1px;
    margin: 0.55rem 0 1rem;
    background: rgba(255, 255, 255, 0.12);
  }

  .workspace-nav {
    width: 100%;
    gap: 0.45rem;
  }

  .workspace-menu-item {
    display: flex;
    width: 100%;
    min-height: 58px;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 0.35rem;
    border-left: 2px solid transparent;
    border-radius: 7px;
    background: transparent;
    color: #696c74;
    transition: color 0.2s, background 0.2s, border-color 0.2s;
  }

  .workspace-menu-item:hover,
  .workspace-menu-item.active {
    border-left-color: var(--card-color);
    background: rgba(255, 255, 255, 0.06);
    color: var(--text-primary);
  }

  .workspace-menu-item.active .rail-index {
    color: var(--card-color);
  }

  .rail-index {
    font-size: 0.64rem;
  }

  .rail-name {
    max-width: 68px;
    overflow: hidden;
    font-size: 0.58rem;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .workspace-stage {
    margin-left: 88px;
    display: flex;
    min-width: 0;
    min-height: 100vh;
    flex-direction: column;
  }

  .titlebar {
    display: flex;
    align-items: center;
    min-height: 64px;
    padding: 0 1.3rem;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    background: rgba(17, 18, 20, 0.86);
  }

  .back-button,
  .window-actions button {
    background: transparent;
    color: var(--text-secondary);
    font-size: 0.75rem;
    transition: color 0.2s, background 0.2s;
  }

  .back-button {
    display: flex;
    align-items: center;
    gap: 0.55rem;
    min-width: 130px;
  }

  .back-button:hover,
  .window-actions button:hover {
    color: var(--text-primary);
  }

  .titlebar-name {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    margin: 0 auto;
    font-size: 0.82rem;
  }

  .titlebar-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: var(--card-color);
  }

  .titlebar-path {
    color: #666970;
    font-size: 0.72rem;
  }

  .window-actions {
    display: flex;
    min-width: 130px;
    justify-content: flex-end;
    gap: 0.2rem;
  }

  .window-actions button {
    padding: 0.5rem 0.45rem;
    border-radius: 5px;
    font-size: 0.65rem;
  }

  .window-actions .close-button:hover {
    background: #b54d4d;
    color: white;
  }

  .workspace-error,
  .error {
    color: #ffb3bf;
    font-size: 0.85rem;
  }

  .workspace-error {
    margin: 1rem 2rem 0;
  }

  .workspace-body {
    display: grid;
    flex: 1;
    place-items: center;
    padding: clamp(2rem, 6vw, 6rem);
  }

  .tool-page {
    width: min(100%, 1080px);
  }

  .tool-heading {
    margin-bottom: 2.5rem;
  }

  .tool-heading h1 {
    font-size: clamp(2.8rem, 6vw, 5.6rem);
  }

  .mock-badge,
  .panel-status {
    border: 1px solid rgba(247, 198, 107, 0.35);
    border-radius: 100px;
    color: #f7c66b;
    font-family: "SF Mono", "Fira Code", monospace;
    font-size: 0.65rem;
    letter-spacing: 0.08em;
    padding: 0.5rem 0.75rem;
    text-transform: uppercase;
    white-space: nowrap;
  }

  .disk-grid,
  .equalizer-grid {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
    gap: 1rem;
  }

  .tool-panel {
    padding: clamp(1.25rem, 3vw, 2rem);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: var(--border-radius);
    background: rgba(32, 34, 38, 0.82);
    box-shadow: 0 24px 70px rgba(0, 0, 0, 0.2);
  }

  .panel-heading {
    display: flex;
    align-items: start;
    justify-content: space-between;
    gap: 1rem;
    margin-bottom: 2rem;
  }

  .panel-heading h2 {
    font-size: 1.4rem;
  }

  .panel-status {
    border: 0;
    padding: 0;
    color: var(--success);
    font-size: 0.6rem;
  }

  .select-label {
    display: block;
    margin-bottom: 0.45rem;
    color: var(--text-secondary);
    font-size: 0.75rem;
  }

  select {
    width: 100%;
    padding: 0.8rem;
    border: 1px solid rgba(255, 255, 255, 0.15);
    border-radius: 7px;
    outline: 0;
    background: var(--bg-secondary);
    color: var(--text-primary);
  }

  .volume-summary,
  .storage-footer,
  .master-row,
  .transport-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .volume-summary {
    margin-top: 1.5rem;
  }

  .volume-summary div {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .volume-summary strong {
    font-size: 1.25rem;
  }

  .volume-summary span,
  .panel-note,
  .scan-time,
  .track-source {
    color: var(--text-secondary);
    font-size: 0.72rem;
  }

  .progress-track,
  .folder-track,
  .transport-track {
    height: 6px;
    overflow: hidden;
    border-radius: 20px;
    background: rgba(255, 255, 255, 0.1);
  }

  .progress-track {
    margin: 1rem 0 1.5rem;
  }

  .progress-track span,
  .folder-track span,
  .transport-track span {
    display: block;
    height: 100%;
    border-radius: inherit;
    background: var(--card-color, var(--accent));
  }

  .primary-button,
  .secondary-button,
  .toggle-button {
    padding: 0.75rem 1rem;
    border-radius: 7px;
    background: var(--accent);
    color: white;
    font-size: 0.78rem;
    font-weight: 700;
  }

  .primary-button:hover,
  .toggle-button:hover {
    background: var(--accent-hover);
  }

  .panel-note {
    margin-top: 1rem;
    line-height: 1.5;
  }

  .folder-list {
    display: flex;
    flex-direction: column;
    gap: 1.35rem;
  }

  .folder-copy {
    display: flex;
    justify-content: space-between;
    margin-bottom: 0.55rem;
    color: var(--text-secondary);
    font-size: 0.78rem;
  }

  .folder-copy strong {
    color: var(--text-primary);
  }

  .folder-track {
    height: 4px;
  }

  .folder-track span {
    background: #f7c66b;
  }

  .storage-footer {
    margin-top: 2rem;
    padding-top: 1rem;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
    color: var(--text-secondary);
    font-size: 0.78rem;
  }

  .storage-footer strong {
    color: var(--success);
  }

  .notes-layout {
    display: grid;
    grid-template-columns: minmax(220px, 0.65fr) minmax(0, 1.35fr);
    gap: 1rem;
  }

  .notes-list-panel {
    min-height: 480px;
  }

  .notes-list-heading,
  .note-editor-heading,
  .note-meta-row,
  .note-editor-footer {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 1rem;
  }

  .notes-list-heading {
    align-items: start;
    margin-bottom: 1.3rem;
  }

  .notes-list-heading h2 {
    font-size: 1.35rem;
  }

  .new-note-button,
  .export-button {
    padding: 0.55rem 0.75rem;
    border-radius: 6px;
    background: #f7c66b;
    color: #24252a;
    font-size: 0.7rem;
    font-weight: 800;
  }

  .new-note-button:hover,
  .export-button:hover {
    background: #ffda8b;
  }

  .search-field input {
    width: 100%;
    padding: 0.7rem 0.75rem;
    border: 1px solid rgba(255, 255, 255, 0.12);
    border-radius: 6px;
    outline: 0;
    background: var(--bg-secondary);
    color: var(--text-primary);
    font: inherit;
    font-size: 0.75rem;
  }

  .notes-list {
    display: flex;
    flex-direction: column;
    gap: 0.35rem;
    margin-top: 1rem;
  }

  .note-list-item {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 0.35rem;
    padding: 0.8rem;
    border-left: 2px solid transparent;
    border-radius: 5px;
    background: transparent;
    text-align: left;
  }

  .note-list-item:hover,
  .note-list-item.active {
    border-left-color: #f7c66b;
    background: rgba(247, 198, 107, 0.08);
  }

  .note-list-meta {
    display: flex;
    width: 100%;
    justify-content: space-between;
    color: #f7c66b;
    font-family: "SF Mono", "Fira Code", monospace;
    font-size: 0.58rem;
    text-transform: uppercase;
  }

  .note-list-meta span:last-child {
    color: #6d7078;
    text-transform: none;
  }

  .note-list-item strong {
    color: var(--text-primary);
    font-size: 0.82rem;
    font-weight: 600;
  }

  .note-list-item > span:last-child {
    display: -webkit-box;
    overflow: hidden;
    color: var(--text-secondary);
    font-size: 0.68rem;
    line-height: 1.4;
    -webkit-box-orient: vertical;
    -webkit-line-clamp: 2;
  }

  .empty-notes {
    padding: 1rem 0.8rem;
    color: var(--text-secondary);
    font-size: 0.75rem;
  }

  .note-editor {
    display: flex;
    min-height: 480px;
    flex-direction: column;
  }

  .note-editor-heading {
    align-items: start;
  }

  .note-saved {
    display: block;
    margin-top: 0.45rem;
    color: var(--success);
    font-family: "SF Mono", "Fira Code", monospace;
    font-size: 0.6rem;
  }

  .note-title-input {
    width: 100%;
    margin-top: 2.5rem;
    padding: 0 0 0.8rem;
    border: 0;
    border-bottom: 1px solid rgba(255, 255, 255, 0.12);
    outline: 0;
    background: transparent;
    color: var(--text-primary);
    font: inherit;
    font-size: clamp(1.6rem, 3vw, 2.4rem);
    font-weight: 600;
    letter-spacing: -0.06em;
  }

  .note-title-input:focus {
    border-color: #f7c66b;
  }

  .note-meta-row {
    justify-content: flex-start;
    gap: 1rem;
    margin-top: 0.75rem;
    color: var(--text-secondary);
    font-family: "SF Mono", "Fira Code", monospace;
    font-size: 0.62rem;
  }

  .note-body-input {
    width: 100%;
    flex: 1;
    min-height: 190px;
    margin-top: 1.5rem;
    padding: 0;
    border: 0;
    outline: 0;
    resize: vertical;
    background: transparent;
    color: #d8d7d2;
    font: inherit;
    font-size: 0.92rem;
    line-height: 1.8;
  }

  .note-body-input:focus {
    color: var(--text-primary);
  }

  .note-editor-footer {
    align-items: end;
    margin-top: 1.5rem;
    padding-top: 1rem;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
    color: var(--text-secondary);
    font-size: 0.7rem;
  }

  .text-button {
    flex: 0 0 auto;
    background: transparent;
    color: #f7c66b;
    font-size: 0.72rem;
    font-weight: 700;
  }

  .text-button:hover {
    color: #ffda8b;
  }

  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
  }

  .audio-console {
    margin-bottom: 1rem;
  }

  .track-meta {
    display: flex;
    align-items: center;
    gap: 1rem;
  }

  .album-art {
    display: grid;
    flex: 0 0 58px;
    width: 58px;
    height: 58px;
    place-items: center;
    border-radius: 9px;
    background: linear-gradient(145deg, #77a6d8, #33465f);
    color: #111214;
    font-size: 0.7rem;
    font-weight: 800;
    letter-spacing: 0.1em;
  }

  .track-meta h2 {
    margin: 0.35rem 0;
  }

  .toggle-button {
    margin-left: auto;
    background: var(--bg-secondary);
    color: var(--text-secondary);
  }

  .toggle-button.enabled {
    border: 1px solid rgba(130, 201, 155, 0.4);
    color: var(--success);
  }

  .visualizer {
    display: flex;
    align-items: end;
    gap: 0.35rem;
    height: 110px;
    margin: 2rem 0 1rem;
    padding: 0 0.25rem;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  }

  .visualizer span {
    flex: 1;
    min-width: 3px;
    border-radius: 3px 3px 0 0;
    background: #77a6d8;
    opacity: 0.65;
  }

  .visualizer span.accent-bar {
    background: #f7c66b;
    opacity: 0.9;
  }

  .transport-row {
    gap: 0.8rem;
    color: var(--text-secondary);
    font-family: "SF Mono", "Fira Code", monospace;
    font-size: 0.65rem;
  }

  .transport-track {
    flex: 1;
    height: 3px;
  }

  .transport-track span {
    width: 38%;
    background: #77a6d8;
  }

  .equalizer-grid {
    grid-template-columns: minmax(0, 1.5fr) minmax(220px, 0.5fr);
  }

  .bands {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 0.7rem;
    min-height: 190px;
  }

  .band {
    display: flex;
    height: 180px;
    flex: 1;
    flex-direction: column;
    align-items: center;
    gap: 0.65rem;
  }

  .band input {
    width: 160px;
    height: 20px;
    margin-top: 65px;
    transform: rotate(-90deg);
    accent-color: #77a6d8;
  }

  .band-value {
    color: var(--text-primary);
    font-family: "SF Mono", "Fira Code", monospace;
    font-size: 0.68rem;
  }

  .band-label {
    color: var(--text-secondary);
    font-size: 0.62rem;
  }

  .master-row {
    gap: 1rem;
    margin-top: 1rem;
    padding-top: 1rem;
    border-top: 1px solid rgba(255, 255, 255, 0.1);
    color: var(--text-secondary);
    font-size: 0.72rem;
  }

  .master-row input {
    flex: 1;
    accent-color: #77a6d8;
  }

  .master-row strong {
    min-width: 2.5rem;
    color: var(--text-primary);
    text-align: right;
  }

  .presets-panel {
    display: flex;
    flex-direction: column;
  }

  .preset-list {
    display: flex;
    flex-direction: column;
    gap: 0.45rem;
    margin-top: 1.25rem;
  }

  .preset-list button {
    padding: 0.7rem 0.8rem;
    border: 1px solid transparent;
    border-radius: 6px;
    background: var(--bg-secondary);
    color: var(--text-secondary);
    text-align: left;
    transition: border-color 0.2s, color 0.2s;
  }

  .preset-list button:hover,
  .preset-list button.active {
    border-color: #77a6d8;
    color: var(--text-primary);
  }

  @media (max-width: 900px) {
    .launcher-main {
      padding-right: 2rem;
      padding-left: 2rem;
    }

    .disk-grid,
    .equalizer-grid,
    .notes-layout {
      grid-template-columns: 1fr;
    }
  }

  @media (max-width: 700px) {
    .launcher {
      display: block;
    }

    .sidebar {
      position: static;
      width: auto;
      height: auto;
      overflow: visible;
      z-index: auto;
      display: block;
      min-height: auto;
      padding: 1rem;
      border-right: 0;
      border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    }

    .brand-mark,
    .brand-copy,
    .side-label,
    .sidebar-foot {
      display: none;
    }

    .launcher .sidebar nav {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
    }

    .launcher-main {
      margin-left: 0;
      padding: 3rem 1.25rem 1.5rem;
    }

    .launcher-header,
    .tool-heading {
      align-items: flex-start;
      flex-direction: column;
      margin-bottom: 2rem;
    }

    .app-grid {
      grid-template-columns: 1fr;
    }

    .app-card {
      min-height: 220px;
    }

    .workspace {
      display: block;
    }

    .workspace-sidebar {
      width: 68px;
      padding-right: 0.35rem;
      padding-left: 0.35rem;
    }

    .workspace-stage {
      margin-left: 68px;
    }

    .workspace-menu-item {
      min-height: 52px;
    }

    .home-glyph {
      width: 32px;
      height: 32px;
    }

    .titlebar {
      flex-wrap: wrap;
      gap: 0.7rem;
      padding: 0.7rem 0.8rem;
    }

    .back-button,
    .window-actions {
      min-width: auto;
    }

    .titlebar-name {
      order: -1;
      width: 100%;
      margin: 0;
    }

    .workspace-body {
      padding: 3rem 1.25rem;
    }

    .track-meta {
      align-items: flex-start;
      flex-wrap: wrap;
    }

    .toggle-button {
      margin-left: 0;
    }

    .bands {
      gap: 0.15rem;
    }

    .notes-list-panel,
    .note-editor {
      min-height: auto;
    }

    .note-editor {
      min-height: 430px;
    }

    .note-editor-footer {
      align-items: flex-start;
      flex-direction: column;
    }
  }
  }
</style>
