import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { parse } from "yaml";

// Astro prerenders this module from a bundled chunk under dist/.prerender, so
// import.meta.url no longer points beside this source file. Package scripts
// execute from apps/web, which keeps the canonical repository root stable.
const repositoryRoot = path.resolve(process.cwd(), "../..");

export interface CapabilityEntry {
  id: string;
  name: string;
  description: string;
  kind: "Skill" | "Agent Definition" | "Loop" | "MCP provider" | "Distribution";
  detail?: string;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readEntries(
  value: unknown,
  key: string,
  source: string,
): Record<string, unknown>[] {
  if (!isRecord(value) || !Array.isArray(value[key])) {
    throw new Error(`${source} must contain a ${key} array`);
  }
  return value[key].filter(isRecord);
}

function text(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value : fallback;
}

async function readYaml(relativePath: string): Promise<unknown> {
  return parse(
    await readFile(path.join(repositoryRoot, relativePath), "utf8"),
  ) as unknown;
}

export async function getCapabilities(): Promise<CapabilityEntry[]> {
  const [skillCatalog, agentCatalog, loopCatalog, productCatalog] =
    await Promise.all([
      readYaml("catalogs/skill-catalog.yaml"),
      readYaml("catalogs/agent-catalog.yaml"),
      readYaml("catalogs/loop-catalog.yaml"),
      readYaml("distributions/products.yaml"),
    ]);

  const skills = readEntries(
    skillCatalog,
    "skills",
    "catalogs/skill-catalog.yaml",
  ).map((entry) => ({
    id: text(entry.id),
    name: text(entry.name, text(entry.id).split("/").at(-1) ?? ""),
    description: text(entry.description),
    kind: "Skill" as const,
    detail: text(entry.domain),
  }));
  const agents = readEntries(
    agentCatalog,
    "agents",
    "catalogs/agent-catalog.yaml",
  ).map((entry) => ({
    id: text(entry.id),
    name: text(entry.name, text(entry.id)),
    description: text(entry.description),
    kind: "Agent Definition" as const,
    detail: text(entry.kind),
  }));
  const loops = readEntries(
    loopCatalog,
    "loops",
    "catalogs/loop-catalog.yaml",
  ).map((entry) => ({
    id: text(entry.id),
    name: text(entry.name, text(entry.id)),
    description: text(entry.description),
    kind: "Loop" as const,
    detail: [text(entry.tier), text(entry.cadence)].filter(Boolean).join(" · "),
  }));

  const mcpDirectory = path.join(repositoryRoot, "mcp/registry");
  const mcpFiles = (await readdir(mcpDirectory))
    .filter((name) => name.endsWith(".yaml"))
    .sort();
  const providers = await Promise.all(
    mcpFiles.map(
      async (name) =>
        parse(await readFile(path.join(mcpDirectory, name), "utf8")) as unknown,
    ),
  );
  const mcp = providers.filter(isRecord).map((entry) => ({
    id: text(entry.id),
    name: text(entry.display_name, text(entry.id)),
    description: text(entry.purpose),
    kind: "MCP provider" as const,
    detail: text(
      (entry.implementation as Record<string, unknown> | undefined)?.provenance,
    ),
  }));
  const products = readEntries(
    productCatalog,
    "products",
    "distributions/products.yaml",
  ).map((entry) => ({
    id: text(entry.id),
    name: text(entry.name, text(entry.id)),
    description: text(entry.description),
    kind: "Distribution" as const,
    detail: text(entry.stability, "stable"),
  }));

  return [...skills, ...agents, ...loops, ...mcp, ...products].filter(
    (entry) => entry.id && entry.name,
  );
}

export function countByKind(
  entries: CapabilityEntry[],
): Map<CapabilityEntry["kind"], number> {
  return new Map(
    (
      [
        "Skill",
        "Agent Definition",
        "Loop",
        "MCP provider",
        "Distribution",
      ] as const
    ).map((kind) => [
      kind,
      entries.filter((entry) => entry.kind === kind).length,
    ]),
  );
}
