import DiskScanner from "./DiskScanner.svelte";
import { defineFrontendPlugin } from "./contract.js";

export const diskScannerPlugin = defineFrontendPlugin({
  id: "disk",
  index: "01",
  title: "Disk Scanner",
  description: "Map storage usage and find what is consuming space.",
  tone: "coral",
  symbol: "STORAGE",
  component: DiskScanner,
});
