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

/** House / place activity derived only from proven jobs (never invented). */
export type PlaceActivity = 'calm' | 'working' | 'blocked';

export interface SemanticEntity {
  /** Stable id for layout + a11y list (not a display name). */
  id: string;
  kind: EntityKind;
  concept: string;
  name: string;
  state: string;
  themeKey: SemanticKey;
  availability: EntityAvailability;
  /**
   * Destination path opened on activate (without session query).
   * Omit when no real inspector exists for this concept — tile stays
   * non-activating (never invent a dashboard or dead deep-link).
   */
  hrefPath?: string;
  hrefExtra?: Record<string, string | undefined>;
  /** Optional project scope when inside a project building. */
  projectId?: string;
  /** Provenance note for tooltips (e.g. job id, memory count). */
  detail?: string;
  /** Real activity for houses / lamps — omitted when calm/unknown. */
  activity?: PlaceActivity;
  /**
   * Optional layout anchor: entity id this character stands at when the job
   * cmd names that object. Missing → house porch / default slot.
   */
  standAtId?: string;
  /**
   * Theme-layer silhouette hint (cottage / library / ops HQ…). Never encodes
   * invented domain state — layout and inspectors ignore this field.
   */
  facade?: string;
  /** Durable Person appearance, only projected while its real PTY is alive. */
  characterSprite?: 'char-scout' | 'char-maker' | 'char-scholar' | 'char-keeper';
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

/** List-row projection of OpenAPI MemoryEntry (body empty on list). */
export interface MemoryEntryRecord {
  id: string;
  kind: string;
  title: string;
  snippet: string;
  tags: string[];
  provenance: {
    file: string;
    author: string;
    timestamp: string;
    project: string;
    agent: string;
  };
}

export interface MemorySummary {
  /**
   * True when GET /api/v1/memory succeeded. False on 404 / transport failure —
   * the world omits the memory place entirely (never fabricates an archive).
   */
  available: boolean;
  /** Real list rows only; never invent documents. */
  entries: MemoryEntryRecord[];
  /** Distinct project provenance values when present. */
  projectKeys: string[];
}

/** Coding tool row from GET /api/v1/tools — only real detections. */
export interface ToolRecord {
  id: string;
  toolName: string;
  detected: boolean;
  configured: boolean;
  enabled: string;
  verified: boolean;
  version: string;
}

export interface WorldDomainInput {
  workspacePath: string;
  harnessNotice?: string | null;
  projects: ProjectRecord[];
  projectsKnown: boolean;
  memory: MemorySummary;
  /** Detected tools from GET /api/v1/tools; empty when the call failed. */
  tools: ToolRecord[];
  toolsKnown: boolean;
  jobs: ReadonlyArray<{
    id: string;
    cmd: string;
    args: string[];
    status: string;
    workspace: string;
  }>;
  personSessions?: ReadonlyArray<{
    id: string;
    personId: string;
    name: string;
    role: string;
    cwd: string;
    projectId?: string;
    provider?: string;
    model?: string;
    avatarCharacter?: SemanticEntity['characterSprite'];
  }>;
  focusProjectId?: string | null;
}
