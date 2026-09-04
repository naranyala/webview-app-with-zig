import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { viteSingleFile } from "vite-plugin-singlefile";

export default defineConfig({
  resolve: {
    conditions: ["browser"],
  },
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
  test: {
    environment: "jsdom",
    include: ["src/**/*.test.js"],
  },
});
