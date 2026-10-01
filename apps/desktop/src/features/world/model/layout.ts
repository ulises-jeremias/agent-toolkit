import type { LaidOutEntity, SemanticEntity, WorldLayout, WorldModel } from './types';

/**
 * Layout (Cozy Pixel World). Footprints come from the semantic footprint
 * table (facade-aware), not a single square: the hall is 5×4, landmarks 4×4,
 * small posts 3×3, objects 2×2, characters 1×2. Positions are tile units;
 * the renderer multiplies by the integer display tile size.
 */

const OBJECT_W = 2;
const OBJECT_H = 2;
const CHAR_W = 1;
const CHAR_H = 2;

/** Facade-aware footprints (tile units) — one art direction, varied lots. */
export const FOOTPRINTS: Record<string, { w: number; h: number }> = {
  'landmark-workspace': { w: 5, h: 4 },
  'landmark-archive': { w: 4, h: 4 },
  'landmark-library': { w: 4, h: 4 },
  'landmark-operations': { w: 4, h: 4 },
  'landmark-terminal': { w: 4, h: 4 },
  'landmark-files': { w: 3, h: 3 },
  'landmark-settings': { w: 3, h: 3 },
  'landmark-attention': { w: 3, h: 3 },
  'memory-index-object': { w: 2, h: 2 },
  'attention-inbox': { w: 2, h: 2 },
  'ops-crate': { w: 2, h: 2 },
  'tool-terminal-desk': { w: 2, h: 2 },
};

export function footprintFor(entity: SemanticEntity): { w: number; h: number } {
  if (entity.kind === 'character') return { w: CHAR_W, h: CHAR_H };
  if (entity.kind === 'object' || entity.kind === 'marker') {
    if (entity.facade && FOOTPRINTS[entity.facade]) return FOOTPRINTS[entity.facade]!;
    if (entity.themeKey === 'memory.entry') return { w: 1, h: 1 };
    return { w: OBJECT_W, h: OBJECT_H };
  }
  // place
  if (entity.facade && FOOTPRINTS[entity.facade]) return FOOTPRINTS[entity.facade]!;
  return { w: 3, h: 3 };
}

function sizeFor(entity: SemanticEntity): { w: number; h: number } {
  return footprintFor(entity);
}

/** Project district columns adapt to roster size (1 → 3 → 5 lanes). */
export function projectDistrictCols(count: number): number {
  if (count <= 3) return 3;
  if (count <= 10) return 5;
  return 7;
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

  // Room: exit door at the west wall; furniture along walls; floor stays open.
  if (exit) place(exit, 0, 1);
  if (room) place(room, 1, 0);
  if (memory) place(memory, 8, 0);
  if (terminal) place(terminal, 0, 6);
  if (files) place(files, 3, 6);

  let toolX = 6;
  const toolY = 6;
  for (const tool of tools) {
    place(tool, toolX, toolY);
    toolX += OBJECT_W + 1;
  }

  let entryX = 0;
  const entryY = toolY + OBJECT_H + 1;
  for (const entry of memoryEntries) {
    place(entry, entryX, entryY);
    entryX += 2;
  }

  // Characters at named interior objects when job.cmd matches; else by the door.
  let porchX = 2;
  const porchY = 9;
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
    cols: Math.max(maxX, 12),
    rows: Math.max(maxY, 10),
    entities: laid,
  };
}

/**
 * Deterministic layout from structured entities. Same ids → same slots.
 * Grounds compose a valley: plaza core with the workspace hall (north),
 * memory archive beside it, the commons landmarks along a mid lane, and the
 * project district south of the road. Streets run between districts; a creek
 * crosses the east edge with a bridge at the road. Characters stand at their
 * house porch or named commons object. Interior: room furniture, not a
 * second dashboard.
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
  // Stable commons lane order (scannable settlement, not alpha noise).
  const landmarkOrder = [
    'object:attention',
    'object:library',
    'object:files',
    'object:operations',
    'object:terminal',
    'object:settings',
    'place:projects-empty',
  ];
  const sharedById = new Map(entities.filter((e) => landmarkOrder.includes(e.id)).map((e) => [e.id, e] as const));
  const sharedObjects = landmarkOrder.map((id) => sharedById.get(id)).filter(Boolean) as SemanticEntity[];
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

  // District widths first so the core is centered on the map, not the lane.
  const districtCols = projectDistrictCols(projects.length);
  const districtW = Math.max(0, districtCols * 4 - 1); // 3-wide houses + gutters
  const commonsW = Math.max(
    0,
    sharedObjects.reduce((acc, e) => acc + sizeFor(e).w + 1, -1),
  );
  const contentW = Math.max(districtW, commonsW, 10); // hall + gap + archive
  const mapW = contentW + 8; // 4-tile forest frame each side

  // North core: hall west, memory archive east, ledgers beside it.
  const coreX = 4 + Math.max(0, Math.floor((contentW - 10) / 2));
  if (grounds) place(grounds, coreX, 1);
  if (memoryPlace) place(memoryPlace, coreX + 6, 1);
  let entryX = coreX + 11;
  for (const entry of memoryEntries) {
    place(entry, entryX, 2);
    entryX += 2;
  }

  // Commons lane: directly south of the hall, centered under the core.
  const laneY = 6;
  let laneX = 4 + Math.max(0, Math.floor((contentW - commonsW) / 2));
  for (const landmark of sharedObjects) {
    place(landmark, laneX, laneY);
    laneX += sizeFor(landmark).w + 1;
  }

  // Project district: south of the lane, centered, row-major.
  const districtY = laneY + 5;
  const districtX = 4 + Math.max(0, Math.floor((contentW - districtW) / 2));
  const projectSlots = new Map<string, { x: number; y: number }>();
  projects.forEach((project, index) => {
    const col = index % districtCols;
    const row = Math.floor(index / districtCols);
    const x = districtX + col * 4;
    const y = districtY + row * 4;
    place(project, x, y);
    if (project.projectId) projectSlots.set(project.projectId, { x, y });
  });

  // Characters: stand at named commons object when job.cmd matches; else house porch.
  let orphanX = coreX;
  const orphanY = Math.max(1, laneY - 1);
  for (const character of characters) {
    const anchor = character.standAtId ? laid.find((row) => row.id === character.standAtId) : undefined;
    if (anchor) {
      place(character, anchor.x + Math.max(0, anchor.w - 1), anchor.y + Math.max(0, anchor.h - 1));
      continue;
    }
    const slot = character.projectId ? projectSlots.get(character.projectId) : undefined;
    if (slot) {
      place(character, slot.x + 1, slot.y + 2);
    } else {
      place(character, orphanX + 1, orphanY);
      orphanX += CHAR_W + 1;
    }
  }

  for (const entity of rest) {
    place(entity, maxX + 1, 0);
  }

  const districtRows = Math.ceil(projects.length / Math.max(1, districtCols));
  const mapRows = districtY + Math.max(0, districtRows) * 4 + 3;
  return {
    cols: Math.max(mapW, maxX + 4),
    rows: Math.max(maxY + 3, mapRows),
    entities: laid,
  };
}
