import ChainNotes from "./ChainNotes.svelte";
import { defineFrontendPlugin } from "./contract.js";

export const chainNotesPlugin = defineFrontendPlugin({
  id: "notes",
  index: "03",
  title: "Chain Notes",
  description: "Capture connected thoughts and carry them anywhere.",
  tone: "gold",
  symbol: "WRITING",
  component: ChainNotes,
});
