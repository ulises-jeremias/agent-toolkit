import { describe, expect, it } from "vitest";
import { rewriteSourceUrl } from "./remark-source-links.mjs";

describe("canonical documentation links", () => {
  it("routes curated guides internally and sends other sources to GitHub", () => {
    const source = "/repo/docs/PEOPLE.md";
    const rewrite = (url: string) => rewriteSourceUrl(url, source, "/repo");
    expect(rewrite("SWARMS.md#start-a-swarm")).toBe(
      "/docs/swarms/#start-a-swarm",
    );
    expect(rewrite("ARCHITECTURE.md")).toBe("/docs/architecture/");
    expect(rewrite("../CONTRIBUTING.md")).toBe(
      "https://github.com/ulises-jeremias/agent-toolkit/blob/main/CONTRIBUTING.md",
    );
    expect(rewrite("https://example.com/guide")).toBe(
      "https://example.com/guide",
    );
  });

  it("serves product screenshots from the shared static source", () => {
    expect(
      rewriteSourceUrl(
        "../static/screenshots/world.png",
        "/repo/docs/INSTALLATION.md",
        "/repo",
        true,
      ),
    ).toBe("/screenshots/world.png");
  });
});
