<script>
  const equalizerPresets = [
    { name: "Flat", values: [0, 0, 0, 0, 0, 0, 0] },
    { name: "Focus", values: [-2, 1, 3, 4, 2, -1, -2] },
    { name: "Warm", values: [4, 3, 1, -1, -2, -2, -1] },
    { name: "Vocal", values: [-3, -1, 2, 4, 3, 1, -2] },
  ];

  const bandLabels = ["60", "150", "400", "1k", "2.4k", "6k", "14k"];
  const visualizerLevels = [42, 66, 52, 78, 58, 86, 69, 48, 72, 54, 80, 62, 44, 74, 57, 68];
  let activePreset = $state("Focus");
  let equalizerEnabled = $state(true);
  let bandValues = $state([-2, 1, 3, 4, 2, -1, -2]);
  let masterVolume = $state(68);

  function choosePreset(preset) {
    activePreset = preset.name;
    bandValues = [...preset.values];
  }

  function updateBand(index, event) {
    bandValues[index] = Number(event.currentTarget.value);
    activePreset = "Custom";
  }
</script>

<section class="tool-page">
  <div class="tool-heading">
    <div>
      <p class="eyebrow">Sound utility / Mock 02</p>
      <h1>Audio Equalizer</h1>
      <p>Build a listening profile with local controls while the audio engine is still to come.</p>
    </div>
    <span class="mock-badge">Engine pending</span>
  </div>

  <div class="audio-console tool-panel">
    <div class="track-meta">
      <div class="album-art">AUX</div>
      <div>
        <span class="panel-label">Current source</span>
        <h2>Night drive / Preview mix</h2>
        <span class="track-source">Local audio route mock</span>
      </div>
      <button class:enabled={equalizerEnabled} class="toggle-button" onclick={() => (equalizerEnabled = !equalizerEnabled)}>
        {equalizerEnabled ? "Enabled" : "Bypassed"}
      </button>
    </div>
    <div class="visualizer" aria-label="Mock audio visualizer">
      {#each visualizerLevels as level, index}
        <span class:accent-bar={index % 4 === 0} style={`height: ${level}%`}></span>
      {/each}
    </div>
    <div class="transport-row">
      <span>01:24</span>
      <div class="transport-track"><span></span></div>
      <span>03:48</span>
    </div>
  </div>

  <div class="equalizer-grid">
    <div class="tool-panel equalizer-panel">
      <div class="panel-heading">
        <div>
          <span class="panel-label">7-band profile</span>
          <h2>{activePreset}</h2>
        </div>
        <span class="panel-status">Local mock</span>
      </div>
      <div class="bands">
        {#each bandValues as value, index}
          <label class="band">
            <input type="range" min="-12" max="12" value={value} oninput={(event) => updateBand(index, event)} aria-label={`${bandLabels[index]} Hz gain`} />
            <span class="band-value">{value > 0 ? "+" : ""}{value}</span>
            <span class="band-label">{bandLabels[index]}</span>
          </label>
        {/each}
      </div>
      <div class="master-row">
        <span>Master volume</span>
        <input type="range" min="0" max="100" bind:value={masterVolume} aria-label="Master volume" />
        <strong>{masterVolume}%</strong>
      </div>
    </div>

    <div class="tool-panel presets-panel">
      <span class="panel-label">Quick presets</span>
      <div class="preset-list">
        {#each equalizerPresets as preset}
          <button class:active={activePreset === preset.name} onclick={() => choosePreset(preset)}>{preset.name}</button>
        {/each}
      </div>
      <p class="panel-note">Presets only update the visual controls until the audio backend is connected.</p>
    </div>
  </div>
</section>
