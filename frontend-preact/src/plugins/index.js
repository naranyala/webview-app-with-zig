import { AcademicPaper } from './academic-paper.jsx';
import { AudioEqualizer } from './audio-equalizer.jsx';
import { ChainNotes } from './chain-notes.jsx';
import { defineFrontendPlugin } from './contract.js';
import { DiskScanner } from './disk-scanner.jsx';
import { Quiz } from './quiz.jsx';
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

export const quizPlugin = defineFrontendPlugin({
  id: 'quiz',
  index: '05',
  title: 'Quiz',
  description:
    'Practice Blender 3D and audio programming with focused prompts.',
  tone: 'violet',
  symbol: 'RECALL',
  component: Quiz
});

export const academicPaperPlugin = defineFrontendPlugin({
  id: 'paper',
  index: '06',
  title: 'Academic Paper',
  description: 'Read two-column papers and export them to PDF.',
  tone: 'green',
  symbol: 'SCHOLAR',
  component: AcademicPaper
});

const registeredPlugins = [
  diskScannerPlugin,
  audioEqualizerPlugin,
  chainNotesPlugin,
  todoPlugin,
  quizPlugin,
  academicPaperPlugin
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
