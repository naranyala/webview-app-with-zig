import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { viteSingleFile } from "vite-plugin-singlefile";

export default defineConfig({
  plugins: [
    svelte(),
    viteSingleFile({
      // The Zig backend embeds this one generated HTML file.
      removeViteModuleLoader: true,
      deleteInlinedFiles: true,
    }),
  ],
  build: {
    target: "esnext",
    assetsInlineLimit: 100000000,
    cssCodeSplit: false,
    outDir: "dist",
  },
});
