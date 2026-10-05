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
  'project-board': { w: 3, h: 3 },
  'door-exit': { w: 1, h: 2 },
  'landmark-workspace': { w: 5, h: 4 },
  'landmark-archive': { w: 4, h: 4 },
  'landmark-library': { w: 4, h: 4 },
  'landmark-workshop': { w: 5, h: 4 },
  'landmark-operations': { w: 4, h: 4 },
  'landmark-terminal': { w: 4, h: 4 },
  'landmark-files': { w: 4, h: 4 },
  'landmark-settings': { w: 4, h: 4 },
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

/** Project district columns adapt to roster size (1 → 2 → 5 → 7 lanes). */
export function projectDistrictCols(count: number): number {
  if (count <= 1) return 1;
  if (count <= 3) return 2;
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
    const roomX = x + 1;
    const roomY = y + 1;
    laid.push({ ...entity, x: roomX, y: roomY, w, h });
    maxX = Math.max(maxX, roomX + w);
    maxY = Math.max(maxY, roomY + h);
  };

  const exit = sorted.find((e) => e.id === 'object:exit-grounds');
  const room = sorted.find((e) => e.id.startsWith('place:project:'));
  const memory = sorted.find((e) => e.id.startsWith('place:memory-project:'));
  const terminal = sorted.find((e) => e.id.startsWith('object:terminal-project:'));
  const files = sorted.find((e) => e.id.startsWith('object:files-project:'));
  const memoryEntries = sorted.filter((e) => e.id.startsWith('object:memory:'));
  const characters = sorted.filter((e) => e.kind === 'character');
  const used = new Set(
    [exit, room, memory, terminal, files, ...memoryEntries, ...characters].filter(Boolean).map((e) => e!.id),
  );
  const rest = sorted.filter((e) => !used.has(e.id));

  // Project room: real resources form two compact wall stations around a
  // navigable central aisle. Keep the useful room filled at normal zoom.
  if (exit) place(exit, 0, 5);
  if (room) place(room, 3, 0);
  if (memory) place(memory, 11, 0);
  if (terminal) place(terminal, 3, 6);
  if (files) place(files, 11, 6);

  let entryX = 11;
  const entryY = 5;
  for (const entry of memoryEntries) {
    place(entry, entryX, entryY);
    entryX += 2;
  }

  // Characters at named interior objects when job.cmd matches; else by the door.
  let porchX = 2;
  const porchY = Math.max(10, maxY + 1);
  for (const character of characters) {
    const anchor = character.standAtId ? laid.find((row) => row.id === character.standAtId) : undefined;
    if (anchor) {
      place(character, anchor.x + anchor.w - 1, anchor.y + Math.max(0, anchor.h - 1) - 1);
    } else {
      place(character, porchX, porchY);
      porchX += CHAR_W + 1;
    }
  }

  for (const entity of rest) {
    place(entity, maxX + 1, 0);
  }

  return {
    // Keep the real project stations close enough to read as one room. Only
    // actual records or active sessions expand the space beyond this footprint.
    cols: Math.max(maxX, 18),
    rows: Math.max(maxY, 11),
    entities: laid,
  };
}

/**
 * Deterministic layout from structured entities. Same ids → same slots.
 * Grounds compose a valley: the civic commons and shared landmarks sit west
 * of the creek; a bridge carries the main path to the project neighborhood on
 * the east bank. This makes the crossing useful and the project district a
 * real place. Characters stand at their house porch or named commons object.
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
  const workshop = entities.find((e) => e.id === 'object:workshop');
  const memoryEntries = entities.filter((e) => e.id.startsWith('object:memory:'));
  // Civic places occupy two small streets around a shared square. Their
  // positions communicate hierarchy without turning the valley into one row.
  const landmarkOrder = [
    'object:library',
    'object:workshop',
    'object:operations',
    'object:terminal',
    'object:attention',
    'object:files',
    'object:settings',
  ];
  const sharedById = new Map(entities.filter((e) => landmarkOrder.includes(e.id)).map((e) => [e.id, e] as const));
  const sharedObjects = landmarkOrder.map((id) => sharedById.get(id)).filter(Boolean) as SemanticEntity[];
  const emptyProject = entities.find((e) => e.id === 'place:projects-empty');
  const projects = entities.filter((e) => e.id.startsWith('place:project:'));
  const characters = entities.filter((e) => e.kind === 'character');
  const rest = entities.filter(
    (e) =>
      e !== grounds &&
      e !== memoryPlace &&
      e !== workshop &&
      !memoryEntries.includes(e) &&
      !sharedObjects.includes(e) &&
      e !== emptyProject &&
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

  // Keep the civic quarter compact; the natural creek marks its edge and the
  // project neighborhood begins on the opposite bank.
  const districtCols = projectDistrictCols(projects.length);
  // Size the camera bounds for occupied lots, not every available lane. The
  // previous reservation made one house inherit the width of a five-lot
  // district, which turned a small workspace into a mostly empty panorama.
  // Lot coordinates remain stable as projects are added.
  // Leave one clear garden tile between neighboring façades so projects read
  // as separate lots rather than touching storefronts.
  const projectLaneGap = 5;
  const districtW = projects.length ? (Math.min(projects.length, districtCols) - 1) * projectLaneGap + 3 : 0;
  // Put project homes across a visible creek crossing from the shared
  // services. Keep the bank gap compact enough that the project district
  // still reads as part of the same settlement at small window sizes.
  const projectDistrictX = 21;
  // With no houses yet, leave a small bank-side meadow between the bridge and
  // the create-project place. That gives the valley a real clearing instead
  // of putting its only destination directly against the crossing.
  const emptyMarkerX = projectDistrictX + 3;
  const mapW = Math.max(28, projectDistrictX + (projects.length ? districtW : 3));

  // North core: hall west, memory archive beside it, ledgers on the commons edge.
  const coreX = 1;
  if (grounds) place(grounds, coreX, 0);
  if (memoryPlace) place(memoryPlace, coreX + 6, 0);
  let entryX = coreX + 11;
  for (const entry of memoryEntries) {
    place(entry, entryX, 1);
    entryX += 2;
  }

  // Public landmarks gather around a shared clearing in a loose crescent.
  // The staggered fronts leave a readable plaza instead of two rigid rows;
  // smaller service places form its southern garden lane.
  const civicSlots: Record<string, { x: number; y: number }> = {
    'object:library': { x: 1, y: 4 },
    // Services sit on distinct garden lots around the commons rather than a
    // single storefront row. Their separate door heights shape short paths.
    'object:workshop': { x: 12, y: 8 },
    'object:operations': { x: 5, y: 3 },
    'object:terminal': { x: 11, y: 2 },
    'object:attention': { x: 0, y: 8 },
    'object:files': { x: 4, y: 8 },
    'object:settings': { x: 8, y: 7 },
  };
  for (const landmark of sharedObjects) {
    const slot = civicSlots[landmark.id]!;
    place(landmark, slot.x, slot.y);
  }

  // Project houses form a distinct neighborhood just beyond the creek. The
  // compact service quarter leaves room for a clear bank, bridge, and garden
  // lots without making a one-project workspace span an empty panorama.
  // Houses begin just beyond the creek crossing. Keeping the project lane
  // beside the civic commons gives compact windows a landscape-shaped valley
  // that can fit at 32px tiles instead of shrinking the whole world to 16px.
  const districtY = 4;
  const districtX = projectDistrictX;
  if (emptyProject) place(emptyProject, emptyMarkerX, districtY + 2);
  const projectSlots = new Map<string, { x: number; y: number }>();
  projects.forEach((project, index) => {
    const col = index % districtCols;
    const row = Math.floor(index / districtCols);
    // Keep existing lots fixed as a roster grows; only new lots are appended.
    // Stagger alternate streets so a rear house never shares its front-door
    // path with a house directly in front of it.
    const x = districtX + col * projectLaneGap + (row % 2 === 1 ? 2 : 0);
    // Alternate houses by two tiles along the bank so neighboring porches
    // read as a small lane instead of one storefront row.
    const y = districtY + row * 5 + (col % 2) * 2;
    place(project, x, y);
    if (project.projectId) projectSlots.set(project.projectId, { x, y });
  });

  // Characters: stand at named commons object when job.cmd matches; else house porch.
  let orphanX = coreX;
  const orphanY = 5;
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
  const projectRows = districtY + Math.max(0, districtRows - 1) * 5 + 3;
  // Give every civic front door at least one walkable tile inside the camera
  // bounds, including the southern workshop lane on empty workspaces.
  const landmarkRows = Math.max(
    0,
    ...sharedObjects.map((landmark) => civicSlots[landmark.id]!.y + sizeFor(landmark).h + 1),
  );
  const mapRows = Math.max(projectRows, landmarkRows);
  return {
    // maxX is already an exclusive tile bound; do not add a second padding
    // tile beyond it, which made short project rosters look needlessly wide.
    cols: Math.max(mapW, maxX),
    rows: Math.max(maxY, mapRows),
    entities: laid,
  };
}
