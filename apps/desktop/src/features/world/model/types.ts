/**
 * Semantic world types — projections of domain state, never sprites.
 * Contract: docs/desktop/SEMANTIC_WORLD.md, ADR-034.
 */

export type SemanticKey =
  | 'workspace.grounds'
  | 'knowledge.workspace'
  | 'knowledge.project'
  | 'project.building'
  | 'memory.entry'
  | 'memory.index'
  | 'tool.terminal'
  | 'tool.coding'
  | 'capability.shelf'
  | 'agent.catalog'
  | 'agent.working'
  | 'agent.blocked'
  | 'agent.idle'
  | 'swarm.table'
  | 'loop.clock'
  | 'ops.crate'
  | 'attention.inbox'
  | 'ops.lamp';

export type EntityKind = 'place' | 'object' | 'character' | 'marker';

export type EntityAvailability = 'present' | 'empty' | 'unavailable' | 'omitted';

export interface SemanticEntity {
  /** Stable id for layout + a11y list (not a display name). */
  id: string;
  kind: EntityKind;
  concept: string;
  name: string;
  state: string;
  themeKey: SemanticKey;
  availability: EntityAvailability;
  /** Destination path opened on activate (without session query). */
  hrefPath: string;
  hrefExtra?: Record<string, string | undefined>;
  /** Optional project scope when inside a project building. */
  projectId?: string;
  /** Provenance note for tooltips (e.g. job id, memory count). */
  detail?: string;
}

export interface LaidOutEntity extends SemanticEntity {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface WorldModel {
  workspacePath: string;
  workspaceLabel: string;
  focusProjectId: string | null;
  entities: SemanticEntity[];
}

export interface WorldLayout {
  cols: number;
  rows: number;
  entities: LaidOutEntity[];
}

export interface ProjectRecord {
  name: string;
  target: string;
  status: 'ok' | 'broken';
}

export interface MemorySummary {
  /** True when the typed memory API answered successfully. */
  available: boolean;
  entryCount: number;
  /** Distinct project provenance values when present. */
  projectKeys: string[];
}

export interface WorldDomainInput {
  workspacePath: string;
  harnessNotice?: string | null;
  projects: ProjectRecord[];
  projectsKnown: boolean;
  memory: MemorySummary;
  jobs: ReadonlyArray<{
    id: string;
    cmd: string;
    args: string[];
    status: string;
    workspace: string;
  }>;
  focusProjectId?: string | null;
}
