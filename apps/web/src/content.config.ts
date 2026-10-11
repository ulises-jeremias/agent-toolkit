import { defineCollection } from "astro:content";
import { glob } from "astro/loaders";

const docs = defineCollection({
  loader: glob({ base: "../../docs", pattern: "**/*.md" }),
});

const changelog = defineCollection({
  loader: glob({ base: "../..", pattern: "CHANGELOG.md" }),
});

export const collections = { docs, changelog };
