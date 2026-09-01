import { audioEqualizerPlugin } from "./audio-equalizer.js";
import { chainNotesPlugin } from "./chain-notes.js";
import { diskScannerPlugin } from "./disk-scanner.js";

const registeredPlugins = [diskScannerPlugin, audioEqualizerPlugin, chainNotesPlugin];
const pluginIds = new Set();

for (const plugin of registeredPlugins) {
  if (pluginIds.has(plugin.id)) throw new Error(`Duplicate frontend plugin id: ${plugin.id}`);
  pluginIds.add(plugin.id);
}

export const frontendPlugins = Object.freeze(registeredPlugins);

export function getFrontendPlugin(id) {
  return frontendPlugins.find((plugin) => plugin.id === id);
}
