import type { LaidOutEntity, SemanticEntity, WorldLayout, WorldModel } from './types';

const PLACE_W = 3;
const PLACE_H = 3;
const OBJECT_W = 2;
const OBJECT_H = 2;
const CHAR_W = 1;
const CHAR_H = 1;

/** Fixed project-district width — never reshuffle when the roster grows past √n thresholds. */
export const PROJECT_DISTRICT_COLS = 4;

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
  const files = sorted.find((e) => e.id.startsWith('object:files-project:'));
  const tools = sorted.filter((e) => e.id.startsWith('object:tool:') || e.id === 'object:tools-empty');
  const memoryEntries = sorted.filter((e) => e.id.startsWith('object:memory:'));
  const characters = sorted.filter((e) => e.kind === 'character');
  const used = new Set(
    [exit, room, memory, terminal, files, ...tools, ...memoryEntries, ...characters].filter(Boolean).map((e) => e!.id),
  );
  const rest = sorted.filter((e) => !used.has(e.id));

  // Room frame at origin; exit door left; furniture along the south wall.
  if (room) place(room, 2, 0);
  if (exit) place(exit, 0, 0);
  if (memory) place(memory, 2 + PLACE_W + 1, 0);
  if (terminal) place(terminal, 0, PLACE_H + 1);
  if (files) place(files, OBJECT_W + 1, PLACE_H + 1);

  let toolX = (OBJECT_W + 1) * 2;
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

  // Characters at named interior objects when job.cmd matches; else room porch.
  let porchX = 2;
  const porchY = Math.max(1, PLACE_H - 1);
  for (const character of characters) {
    const anchor = character.standAtId ? laid.find((row) => row.id === character.standAtId) : undefined;
    if (anchor) {
      place(character, anchor.x + Math.max(0, anchor.w - 1), anchor.y + Math.max(0, anchor.h - 1));
    } else {
      place(character, porchX, porchY);
      porchX += CHAR_W + 1;
    }
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
 * Grounds: commons strip (workspace, memory, inspectors) then a fixed-width
 * project district — never a √n reshape. Characters stand at their house porch.
 * Interior: room furniture, not a second dashboard.
 */
export function layoutWorld(model: WorldModel): WorldLayout {
  if (model.focusProjectId) {
    return layoutInterior(model.entities);
  }

  const entities = [...model.entities].sort((a, b) => a.id.localeCompare(b.id));
  const laid: LaidOutEntity[] = [];

  const grounds = entities.find((e) => e.id === 'place:workspace');
  const memoryPlace = entities.find((e) => e.id === 'place:memory');
  const memoryEntries = entities.filter((e) => e.id.startsWith('object:memory:'));
  const sharedObjects = entities.filter(
    (e) =>
      e.id === 'object:terminal' ||
      e.id === 'object:library' ||
      e.id === 'object:files' ||
      e.id === 'object:operations' ||
      e.id === 'object:settings' ||
      e.id === 'object:attention' ||
      e.id === 'place:projects-empty',
  );
  const projects = entities.filter((e) => e.id.startsWith('place:project:'));
  const characters = entities.filter((e) => e.kind === 'character');
  const rest = entities.filter(
    (e) =>
      e !== grounds &&
      e !== memoryPlace &&
      !memoryEntries.includes(e) &&
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

  // Commons district — workspace lot + memory archive on the north strip.
  if (grounds) place(grounds, 0, 0);
  if (memoryPlace) place(memoryPlace, PLACE_W + 1, 0);

  let entryX = (PLACE_W + 1) * 2;
  for (const entry of memoryEntries) {
    place(entry, entryX, 0);
    entryX += OBJECT_W + 1;
  }

  let objX = 0;
  const objY = PLACE_H + 1;
  for (const obj of sharedObjects) {
    place(obj, objX, objY);
    objX += OBJECT_W + 1;
  }

  // Project district — sorted names, fixed column count (stable as roster grows).
  const projectStartY = objY + OBJECT_H + 1;
  const projectSlots = new Map<string, { x: number; y: number }>();
  projects.forEach((project, index) => {
    const col = index % PROJECT_DISTRICT_COLS;
    const row = Math.floor(index / PROJECT_DISTRICT_COLS);
    const x = col * (PLACE_W + 1);
    const y = projectStartY + row * (PLACE_H + 1);
    place(project, x, y);
    if (project.projectId) projectSlots.set(project.projectId, { x, y });
  });

  // Characters: stand at named commons object when job.cmd matches; else house porch.
  let orphanX = 0;
  const orphanY = Math.max(1, PLACE_H - 1);
  for (const character of characters) {
    const anchor = character.standAtId ? laid.find((row) => row.id === character.standAtId) : undefined;
    if (anchor) {
      place(character, anchor.x + Math.max(0, anchor.w - 1), anchor.y + Math.max(0, anchor.h - 1));
      continue;
    }
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
    cols: Math.max(maxX, PROJECT_DISTRICT_COLS * (PLACE_W + 1)),
    rows: Math.max(maxY, 8),
    entities: laid,
  };
}
