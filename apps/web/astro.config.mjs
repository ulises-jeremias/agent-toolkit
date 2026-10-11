import { fileURLToPath } from "node:url";
import { defineConfig } from "astro/config";
import sitemap from "@astrojs/sitemap";
import { satteri } from "@astrojs/markdown-satteri";
import { sourceLinks } from "./src/lib/remark-source-links.mjs";

const repoRoot = fileURLToPath(new URL("../../", import.meta.url));

export default defineConfig({
  site: "https://agenttoolkit.dev",
  output: "static",
  trailingSlash: "always",
  publicDir: fileURLToPath(new URL("../../static", import.meta.url)),
  integrations: [sitemap()],
  markdown: {
    processor: satteri({ mdastPlugins: [sourceLinks({ repoRoot })] }),
  },
  vite: {
    resolve: {
      alias: {
        "@": fileURLToPath(new URL("./src", import.meta.url)),
      },
    },
  },
});
