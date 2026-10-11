import { defineConfig } from "eslint/config";
import astro from "eslint-plugin-astro";
import typescriptEslint from "typescript-eslint";
import eslintConfigPrettier from "eslint-config-prettier";

export default defineConfig(
  {
    ignores: [
      ".astro/",
      "node_modules/",
      "dist/",
      "test-results/",
      "playwright-report/",
    ],
  },
  ...astro.configs["flat/recommended"],
  {
    files: ["**/*.{js,mjs,ts}"],
    languageOptions: {
      globals: {
        console: "readonly",
        document: "readonly",
        fetch: "readonly",
        URL: "readonly",
        window: "readonly",
      },
    },
    extends: [typescriptEslint.configs.recommended],
  },
  eslintConfigPrettier,
);
