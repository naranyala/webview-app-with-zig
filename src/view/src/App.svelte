<script>
  let count = $state(0);
  let systemInfo = $state("");
  let timestamp = $state("");

  async function increment(delta) {
    count = await window.increment(delta);
  }

  async function reset() {
    count = await window.reset();
  }

  async function loadSystemInfo() {
    systemInfo = await window.getSystemInfo();
  }

  async function loadTimestamp() {
    const ts = await window.getTimestamp();
    const date = new Date(Number(ts) * 1000);
    timestamp = date.toLocaleString();
  }

  $effect(() => {
    loadSystemInfo();
    loadTimestamp();
  });
</script>

<div class="app">
  <header>
    <h1>WebView App</h1>
    <p class="subtitle">Svelte + Zig Backend</p>
  </header>

  <section class="card">
    <h2>Counter</h2>
    <div class="counter-display" class:positive={count > 0} class:negative={count < 0}>
      {count}
    </div>
    <div class="counter-buttons">
      <button onclick={() => increment(-1)}>-1</button>
      <button onclick={reset} class="reset">Reset</button>
      <button onclick={() => increment(1)}>+1</button>
    </div>
  </section>

  <section class="card">
    <h2>System Info</h2>
    <div class="info-row">
      <span class="label">Platform:</span>
      <span class="value">{systemInfo || "Loading..."}</span>
    </div>
    <div class="info-row">
      <span class="label">Timestamp:</span>
      <span class="value">{timestamp || "Loading..."}</span>
    </div>
    <button onclick={loadTimestamp} class="refresh">Refresh Time</button>
  </section>
</div>

<style>
  .app {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
  }

  header {
    text-align: center;
    margin-bottom: 1rem;
  }

  h1 {
    font-size: 2rem;
    font-weight: 700;
    background: linear-gradient(135deg, #e94560, #ff6b81);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }

  .subtitle {
    color: var(--text-secondary);
    margin-top: 0.25rem;
  }

  .card {
    background: var(--bg-card);
    border-radius: var(--border-radius);
    padding: 1.5rem;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
  }

  h2 {
    font-size: 1.1rem;
    font-weight: 600;
    margin-bottom: 1rem;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  }

  .counter-display {
    font-size: 4rem;
    font-weight: 700;
    text-align: center;
    padding: 1rem;
    transition: color 0.2s;
  }

  .counter-display.positive {
    color: var(--success);
  }

  .counter-display.negative {
    color: var(--accent);
  }

  .counter-buttons {
    display: flex;
    gap: 0.75rem;
    justify-content: center;
    margin-top: 1rem;
  }

  button {
    padding: 0.6rem 1.5rem;
    border: none;
    border-radius: 8px;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    background: var(--accent);
    color: white;
    transition: all 0.2s;
  }

  button:hover {
    background: var(--accent-hover);
    transform: translateY(-1px);
  }

  button:active {
    transform: translateY(0);
  }

  button.reset {
    background: var(--bg-secondary);
    border: 1px solid var(--text-secondary);
  }

  button.reset:hover {
    background: var(--text-secondary);
    color: var(--bg-primary);
  }

  .info-row {
    display: flex;
    justify-content: space-between;
    padding: 0.5rem 0;
    border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  }

  .info-row:last-of-type {
    border-bottom: none;
  }

  .label {
    color: var(--text-secondary);
  }

  .value {
    font-weight: 600;
    font-family: "SF Mono", "Fira Code", monospace;
  }

  .refresh {
    margin-top: 1rem;
    width: 100%;
    background: var(--bg-secondary);
    border: 1px solid var(--text-secondary);
  }

  .refresh:hover {
    background: var(--text-secondary);
    color: var(--bg-primary);
  }
</style>
