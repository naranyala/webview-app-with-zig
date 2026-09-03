import { useState } from 'preact/hooks';

const equalizerPresets = [
  { name: 'Flat', values: [0, 0, 0, 0, 0, 0, 0] },
  { name: 'Focus', values: [-2, 1, 3, 4, 2, -1, -2] },
  { name: 'Warm', values: [4, 3, 1, -1, -2, -2, -1] },
  { name: 'Vocal', values: [-3, -1, 2, 4, 3, 1, -2] }
];

const bandLabels = ['60', '150', '400', '1k', '2.4k', '6k', '14k'];
const visualizerLevels = [
  42, 66, 52, 78, 58, 86, 69, 48, 72, 54, 80, 62, 44, 74, 57, 68
];

export function AudioEqualizer() {
  const [activePreset, setActivePreset] = useState('Focus');
  const [equalizerEnabled, setEqualizerEnabled] = useState(true);
  const [bandValues, setBandValues] = useState([-2, 1, 3, 4, 2, -1, -2]);
  const [masterVolume, setMasterVolume] = useState(68);

  function choosePreset(preset) {
    setActivePreset(preset.name);
    setBandValues([...preset.values]);
  }

  function updateBand(index, event) {
    const next = [...bandValues];
    next[index] = Number(event.currentTarget.value);
    setBandValues(next);
    setActivePreset('Custom');
  }

  return (
    <section className="tool-page">
      <div className="tool-heading">
        <div>
          <p className="eyebrow">Sound</p>
          <h1>Equalizer</h1>
          <p>Tune the mix. Changes are local for now.</p>
        </div>
        <span className="mock-badge">Mock</span>
      </div>

      <div className="audio-console tool-panel">
        <div className="track-meta">
          <div className="album-art">AUX</div>
          <div>
            <span className="panel-label">Source</span>
            <h2>Night drive</h2>
            <span className="track-source">Local mock</span>
          </div>
          <button
            type="button"
            className={`toggle-button${equalizerEnabled ? ' enabled' : ''}`}
            onClick={() => setEqualizerEnabled((value) => !value)}
          >
            {equalizerEnabled ? 'Enabled' : 'Bypassed'}
          </button>
        </div>
        <div
          className="visualizer"
          role="img"
          aria-label="Mock audio visualizer"
        >
          {visualizerLevels.map((level, index) => (
            <span
              key={index}
              className={index % 4 === 0 ? 'accent-bar' : undefined}
              style={`height: ${level}%`}
            />
          ))}
        </div>
        <div className="transport-row">
          <span>01:24</span>
          <div className="transport-track">
            <span />
          </div>
          <span>03:48</span>
        </div>
      </div>

      <div className="equalizer-grid">
        <div className="tool-panel equalizer-panel">
          <div className="panel-heading">
            <div>
              <span className="panel-label">Bands</span>
              <h2>{activePreset}</h2>
            </div>
            <span className="panel-status">Local</span>
          </div>
          <div className="bands">
            {bandValues.map((value, index) => (
              <label className="band" key={bandLabels[index]}>
                <input
                  type="range"
                  min="-12"
                  max="12"
                  value={value}
                  onInput={(event) => updateBand(index, event)}
                  aria-label={`${bandLabels[index]} Hz gain`}
                />
                <span className="band-value">
                  {value > 0 ? '+' : ''}
                  {value}
                </span>
                <span className="band-label">{bandLabels[index]}</span>
              </label>
            ))}
          </div>
          <div className="master-row">
            <span>Master</span>
            <input
              type="range"
              min="0"
              max="100"
              value={masterVolume}
              onInput={(event) =>
                setMasterVolume(Number(event.currentTarget.value))
              }
              aria-label="Master volume"
            />
            <strong>{masterVolume}%</strong>
          </div>
        </div>

        <div className="tool-panel presets-panel">
          <span className="panel-label">Presets</span>
          <div className="preset-list">
            {equalizerPresets.map((preset) => (
              <button
                type="button"
                key={preset.name}
                className={activePreset === preset.name ? 'active' : undefined}
                onClick={() => choosePreset(preset)}
              >
                {preset.name}
              </button>
            ))}
          </div>
          <p className="panel-note">
            Presets update controls only until the backend connects.
          </p>
        </div>
      </div>
    </section>
  );
}
