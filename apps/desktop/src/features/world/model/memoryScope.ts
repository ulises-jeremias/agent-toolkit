import type { MemoryEntryRecord, ProjectRecord, ToolRecord } from './types';

/**
 * Project scope from typed memory provenance only.
 * - empty project → no location (workspace archive only; never every house)
 * - exact match to a roster project name → that house
 * - anything else (e.g. harness basename `.ai-workspace`) → workspace-level
 */
export function memoryProjectScope(entry: MemoryEntryRecord, projectNames: ReadonlySet<string>): string | null {
  const project = entry.provenance.project.trim();
  if (!project) return null;
  return projectNames.has(project) ? project : null;
}

/** Records that stay on the world Memory archive (not a named project house). */
export function workspaceLevelMemory(
  entries: readonly MemoryEntryRecord[],
  projects: readonly ProjectRecord[],
): MemoryEntryRecord[] {
  const names = new Set(projects.map((row) => row.name));
  return entries.filter((entry) => memoryProjectScope(entry, names) === null);
}

/** Records whose provenance.project exactly names this project. */
export function projectScopedMemory(entries: readonly MemoryEntryRecord[], projectName: string): MemoryEntryRecord[] {
  const needle = projectName.trim();
  if (!needle) return [];
  return entries.filter((entry) => entry.provenance.project.trim() === needle);
}

export interface JobStandTarget {
  tools: readonly ToolRecord[];
  memoryPlaceId?: string;
  terminalObjectId?: string;
}

/**
 * Where a job character stands — only when job.cmd exactly names a known
 * interior/grounds object (memory, terminal, or a detected tool id/name).
 * No pathfinding; no invented targets from args prose.
 */
export function jobStandAtId(job: { cmd: string; args: string[] }, target: JobStandTarget): string | undefined {
  const cmd = job.cmd.trim().toLowerCase();
  if (!cmd) return undefined;

  if (cmd === 'memory' && target.memoryPlaceId) return target.memoryPlaceId;
  if ((cmd === 'terminal' || cmd === 'pty') && target.terminalObjectId) {
    return target.terminalObjectId;
  }

  for (const tool of target.tools) {
    if (!tool.detected) continue;
    const id = tool.id.trim().toLowerCase();
    const name = tool.toolName.trim().toLowerCase();
    if (cmd === id || (name.length > 0 && cmd === name)) {
      return `object:tool:${tool.id}`;
    }
  }

  return undefined;
}
