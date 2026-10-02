/**
 * World detail inspectors for memory records and tools.
 * Stay on `/world` with query params — no new destination routes.
 * Endpoints: GET /api/v1/memory/file?path=, GET /api/v1/tools (catalog row).
 */

import type { MemoryEntryRecord, SemanticEntity } from './model/types';

export function entityHasInspector(entity: Pick<SemanticEntity, 'hrefPath'>): boolean {
  return typeof entity.hrefPath === 'string' && entity.hrefPath.length > 0;
}

/** Accessible name for map tiles and list rows — name + concept + state (no color). */
export function entityAccessibleName(
  entity: Pick<SemanticEntity, 'name' | 'concept' | 'state' | 'detail' | 'activity'>,
): string {
  const parts = [entity.name, entity.concept, entity.state];
  if (entity.detail) parts.push(entity.detail);
  if (entity.activity && entity.activity !== 'calm') parts.push(`activity ${entity.activity}`);
  return parts.join(' · ');
}

/** Short, truthful action label shared by map tooltips and the world index. */
export function entityActivateVerb(
  entity: Pick<SemanticEntity, 'id' | 'hrefPath' | 'name' | 'concept' | 'themeKey' | 'kind'>,
): string {
  if (!entityHasInspector(entity)) return 'No action available';
  if (entity.concept === 'Project overview board') return `Open ${entity.name} project overview`;
  if (entity.id.startsWith('place:project:')) return `Enter ${entity.name} house`;
  if (entity.id.startsWith('character:person:')) return `Inspect ${entity.name}'s active session`;
  if (entity.id.startsWith('character:job:')) return `Open ${entity.name} in Operations`;
  if (entity.id.startsWith('object:memory:')) return `Inspect ${entity.name} record`;

  const destination: Record<string, string> = {
    'capability.shelf': 'Library',
    'memory.index': 'Memory archive',
    'tool.terminal': 'Terminal',
    'ops.crate': 'Operations',
    'attention.inbox': 'Office',
    'files.workspace': 'Workspace files',
    'files.project': 'Project files',
    'workspace.grounds': 'Workspace inspector',
    'project.building': 'Project interior',
  };
  const label = destination[entity.themeKey] ?? entity.concept;
  return `Open ${label}`;
}

export function entityActivateLabel(
  entity: Pick<
    SemanticEntity,
    'id' | 'hrefPath' | 'name' | 'concept' | 'state' | 'detail' | 'activity' | 'themeKey' | 'kind'
  >,
): string {
  const base = entityAccessibleName(entity);
  return entityHasInspector(entity)
    ? `${base}. ${entityActivateVerb(entity)}.`
    : `${base}. No action available for this environmental object.`;
}

/** Path for GET /api/v1/memory/file — provenance.file when set, else list id. */
export function memoryFilePath(entry: Pick<MemoryEntryRecord, 'id' | 'provenance'>): string {
  const file = entry.provenance.file.trim();
  return file || entry.id.trim();
}

/** World query extras that open the memory-file inspector for one record. */
export function memoryInspectExtra(
  entry: Pick<MemoryEntryRecord, 'id' | 'provenance'>,
  projectId?: string,
): Record<string, string | undefined> {
  const trimmed = projectId?.trim() || '';
  return {
    project: trimmed || undefined,
    memory: memoryFilePath(entry),
    tool: undefined,
    place: undefined,
  };
}

/** World query extras that open the tools-catalog inspector for one tool id. */
export function toolInspectExtra(toolId: string, projectId?: string): Record<string, string | undefined> {
  const trimmed = projectId?.trim() || '';
  return {
    project: trimmed || undefined,
    tool: toolId,
    memory: undefined,
    place: undefined,
  };
}

/**
 * Leave a memory/tool detail inspector. Keeps `?project=` when set so Back
 * returns to the interior that opened the detail; otherwise returns to grounds.
 */
export function worldDetailBackExtra(project: string | null | undefined): Record<string, string | undefined> {
  const trimmed = project?.trim() || '';
  return {
    project: trimmed || undefined,
    memory: undefined,
    tool: undefined,
    place: undefined,
  };
}

export function worldDetailBackLabel(project: string | null | undefined): string {
  const trimmed = project?.trim() || '';
  return trimmed ? `Back to ${trimmed} house` : 'Back to world';
}
