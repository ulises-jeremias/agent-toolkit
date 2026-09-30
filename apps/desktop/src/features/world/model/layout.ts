import type { LaidOutEntity, SemanticEntity, WorldLayout, WorldModel } from './types';

const PLACE_W = 3;
const PLACE_H = 3;
const OBJECT_W = 2;
const OBJECT_H = 2;
const CHAR_W = 1;
const CHAR_H = 1;

function sizeFor(entity: SemanticEntity): { w: number; h: number } {
  if (entity.kind === 'character') return { w: CHAR_W, h: CHAR_H };
  if (entity.kind === 'object' || entity.kind === 'marker') return { w: OBJECT_W, h: OBJECT_H };
  return { w: PLACE_W, h: PLACE_H };
}

function layoutInterior(entities: SemanticEntity[]): WorldLayout {
  const sorted = [...entities].sort((a, b) => a.id.localeCompare(b.id));
  const laid: LaidOutEntity[] = [];
  let maxX = 0;
  let maxY = 0;

  const place = (entity: SemanticEntity, x: number, y: number) => {
    const { w, h } = sizeFor(entity);
    laid.push({ ...entity, x, y, w, h });
    maxX = Math.max(maxX, x + w);
    maxY = Math.max(maxY, y + h);
  };

  const exit = sorted.find((e) => e.id === 'object:exit-grounds');
  const room = sorted.find((e) => e.id.startsWith('place:project:'));
  const memory = sorted.find((e) => e.id.startsWith('place:memory-project:'));
  const terminal = sorted.find((e) => e.id.startsWith('object:terminal-project:'));
  const tools = sorted.filter((e) => e.id.startsWith('object:tool:') || e.id === 'object:tools-empty');
  const memoryEntries = sorted.filter((e) => e.id.startsWith('object:memory:'));
  const characters = sorted.filter((e) => e.kind === 'character');
  const used = new Set(
    [exit, room, memory, terminal, ...tools, ...memoryEntries, ...characters].filter(Boolean).map((e) => e!.id),
  );
  const rest = sorted.filter((e) => !used.has(e.id));

  // Room frame at origin; exit door left; furniture along the south wall.
  if (room) place(room, 2, 0);
  if (exit) place(exit, 0, 0);
  if (memory) place(memory, 2 + PLACE_W + 1, 0);
  if (terminal) place(terminal, 0, PLACE_H + 1);

  let toolX = OBJECT_W + 1;
  const toolY = PLACE_H + 1;
  for (const tool of tools) {
    place(tool, toolX, toolY);
    toolX += OBJECT_W + 1;
  }

  let entryX = 0;
  const entryY = toolY + OBJECT_H + 1;
  for (const entry of memoryEntries) {
    place(entry, entryX, entryY);
    entryX += OBJECT_W + 1;
  }

  let charX = 2;
  const charY = Math.max(1, PLACE_H - 1);
  for (const character of characters) {
    place(character, charX, charY);
    charX += CHAR_W + 1;
  }

  for (const entity of rest) {
    place(entity, maxX + 1, 0);
  }

  return {
    cols: Math.max(maxX, 10),
    rows: Math.max(maxY, 8),
    entities: laid,
  };
}

/**
 * Deterministic layout from structured entities. Same ids → same slots.
 * Grounds: houses on a stable grid; characters stand at their house when
 * project-scoped. Interior: room furniture, not a second dashboard.
 */
export function layoutWorld(model: WorldModel): WorldLayout {
  if (model.focusProjectId) {
    return layoutInterior(model.entities);
  }

  const entities = [...model.entities].sort((a, b) => a.id.localeCompare(b.id));
  const laid: LaidOutEntity[] = [];

  const grounds = entities.find((e) => e.id === 'place:workspace');
  const memoryPlace = entities.find((e) => e.id === 'place:memory');
  const sharedObjects = entities.filter(
    (e) =>
      e.id === 'object:terminal' ||
      e.id === 'object:library' ||
      e.id === 'object:attention' ||
      e.id === 'object:memory-index' ||
      e.id === 'place:projects-empty',
  );
  const projects = entities.filter((e) => e.id.startsWith('place:project:'));
  const characters = entities.filter((e) => e.kind === 'character');
  const rest = entities.filter(
    (e) =>
      e !== grounds &&
      e !== memoryPlace &&
      !sharedObjects.includes(e) &&
      !projects.includes(e) &&
      !characters.includes(e),
  );

  let maxX = 0;
  let maxY = 0;

  const place = (entity: SemanticEntity, x: number, y: number) => {
    const { w, h } = sizeFor(entity);
    laid.push({ ...entity, x, y, w, h });
    maxX = Math.max(maxX, x + w);
    maxY = Math.max(maxY, y + h);
  };

  if (grounds) place(grounds, 0, 0);
  if (memoryPlace) place(memoryPlace, PLACE_W + 1, 0);

  let objX = 0;
  const objY = PLACE_H + 1;
  for (const obj of sharedObjects) {
    place(obj, objX, objY);
    objX += OBJECT_W + 1;
  }

  const projectStartY = objY + OBJECT_H + 1;
  const cols = Math.max(1, Math.ceil(Math.sqrt(Math.max(projects.length, 1))));
  const projectSlots = new Map<string, { x: number; y: number }>();
  projects.forEach((project, index) => {
    const col = index % cols;
    const row = Math.floor(index / cols);
    const x = col * (PLACE_W + 1);
    const y = projectStartY + row * (PLACE_H + 1);
    place(project, x, y);
    if (project.projectId) projectSlots.set(project.projectId, { x, y });
  });

  // Characters at their house porch; unmatched walk the grounds row.
  let orphanX = 0;
  const orphanY = Math.max(1, PLACE_H - 1);
  for (const character of characters) {
    const slot = character.projectId ? projectSlots.get(character.projectId) : undefined;
    if (slot) {
      place(character, slot.x + 1, slot.y + PLACE_H - 1);
    } else {
      place(character, orphanX + 1, orphanY);
      orphanX += CHAR_W + 1;
    }
  }

  for (const entity of rest) {
    place(entity, maxX + 1, 0);
  }

  return {
    cols: Math.max(maxX, 8),
    rows: Math.max(maxY, 8),
    entities: laid,
  };
}
