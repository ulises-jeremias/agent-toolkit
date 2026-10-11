import { describe, expect, it } from "vitest";
import { countByKind, getCapabilities } from "./catalog";

describe("canonical capability catalogs", () => {
  it("loads each supported catalog source and derives current counts", async () => {
    const capabilities = await getCapabilities();
    const counts = countByKind(capabilities);
    expect(capabilities.length).toBeGreaterThan(100);
    expect(counts.get("Skill")).toBeGreaterThan(100);
    expect(counts.get("Agent Definition")).toBeGreaterThan(10);
    expect(counts.get("MCP provider")).toBeGreaterThan(0);
    expect(
      new Set(capabilities.map((entry) => `${entry.kind}:${entry.id}`)).size,
    ).toBe(capabilities.length);
  });
});
