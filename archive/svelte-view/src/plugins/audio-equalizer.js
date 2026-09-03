import AudioEqualizer from "./AudioEqualizer.svelte";
import { defineFrontendPlugin } from "./contract.js";

export const audioEqualizerPlugin = defineFrontendPlugin({
  id: "equalizer",
  index: "02",
  title: "Audio Equalizer",
  description: "Shape the listening profile for every sound source.",
  tone: "blue",
  symbol: "SIGNAL",
  component: AudioEqualizer,
});
