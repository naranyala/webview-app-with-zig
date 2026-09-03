import { AudioEqualizer } from './audio-equalizer.jsx';
import { ChainNotes } from './chain-notes.jsx';
import { defineFrontendPlugin } from './contract.js';
import { DiskScanner } from './disk-scanner.jsx';
import { TodoApp } from './todo.jsx';

export const diskScannerPlugin = defineFrontendPlugin({
  id: 'disk',
  index: '01',
  title: 'Disk Scanner',
  description: 'Map storage usage and find what is consuming space.',
  tone: 'coral',
  symbol: 'STORAGE',
  component: DiskScanner
});

export const audioEqualizerPlugin = defineFrontendPlugin({
  id: 'equalizer',
  index: '02',
  title: 'Audio Equalizer',
  description: 'Shape the listening profile for every sound source.',
  tone: 'blue',
  symbol: 'SIGNAL',
  component: AudioEqualizer
});

export const chainNotesPlugin = defineFrontendPlugin({
  id: 'notes',
  index: '03',
  title: 'Chain Notes',
  description: 'Capture connected thoughts and carry them anywhere.',
  tone: 'gold',
  symbol: 'WRITING',
  component: ChainNotes
});

export const todoPlugin = defineFrontendPlugin({
  id: 'todos',
  index: '04',
  title: 'Todos',
  description: 'Capture what matters. Finish what you start.',
  tone: 'gold',
  symbol: 'TODO',
  component: TodoApp
});

const registeredPlugins = [
  diskScannerPlugin,
  audioEqualizerPlugin,
  chainNotesPlugin,
  todoPlugin
];
const pluginIds = new Set();

for (const plugin of registeredPlugins) {
  if (pluginIds.has(plugin.id))
    throw new Error(`Duplicate frontend plugin id: ${plugin.id}`);
  pluginIds.add(plugin.id);
}

export const frontendPlugins = Object.freeze(registeredPlugins);

export function getFrontendPlugin(id) {
  return frontendPlugins.find((plugin) => plugin.id === id);
}
