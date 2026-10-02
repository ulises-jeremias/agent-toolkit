import type { LaidOutEntity } from './types';

/**
 * Terrain painter (Cozy Pixel World). Turns the laid-out entity grid into a
 * composed valley: grass base, plaza core, winding roads with soft edges,
 * an eastern creek with bridges, forest frame, flower beds, and ambient
 * wildlife spawn points. Everything is deterministic — same entity layout →
 * same valley. Nothing here encodes domain state (ADR-034/035).
 */

export interface TerrainCell {
  x: number;
  y: number;
  /** Tile id resolved against theme.decor / theme.interior. */
  tile: string;
}

export interface DecorSprite {
  id: string;
  x: number;
  y: number;
  /** Sprite id in theme.decor. */
  sprite: string;
  /** Source width/height in px (drives DOM size; may exceed one tile). */
  w: number;
  h: number;
  /** px offset within the anchor tile's top-left corner. */
  dx: number;
  dy: number;
  /** Render above entities (tree canopies) or below (flat décor). */
  over: boolean;
  /** Ambient critter — animated, clearly not an agent. */
  ambient?: boolean;
}

export interface TerrainPlan {
  cells: TerrainCell[];
  decor: DecorSprite[];
}

/* Deterministic hash → small int (layout stability across days). */
function h2(x: number, y: number, salt = 0): number {
  let h = (x * 374761393 + y * 668265263 + salt * 2246822519) >>> 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177) >>> 0;
  return (h ^ (h >>> 16)) >>> 0;
}

function key(x: number, y: number) {
  return `${x},${y}`;
}

class Painter {
  cells = new Map<string, string>();
  paths = new Set<string>();
  decor: DecorSprite[] = [];
  blocked = new Set<string>();
  cols: number;
  rows: number;

  constructor(cols: number, rows: number, entities: readonly LaidOutEntity[]) {
    this.cols = cols;
    this.rows = rows;
    for (const e of entities) {
      for (let y = e.y; y < e.y + e.h; y++) for (let x = e.x; x < e.x + e.w; x++) this.blocked.add(key(x, y));
    }
  }

  set(x: number, y: number, tile: string, overwrite = false) {
    if (x < 0 || y < 0 || x >= this.cols || y >= this.rows) return;
    if (!overwrite && this.blocked.has(key(x, y))) return;
    this.cells.set(key(x, y), tile);
  }

  get(x: number, y: number): string {
    return this.cells.get(key(x, y)) ?? 'grass';
  }

  isBlocked(x: number, y: number) {
    return x < 0 || y < 0 || x >= this.cols || y >= this.rows || this.blocked.has(key(x, y));
  }

  sprite(
    id: string,
    x: number,
    y: number,
    sprite: string,
    w: number,
    h: number,
    dx = 0,
    dy = 0,
    over = false,
    ambient = false,
  ) {
    this.decor.push({ id, x, y, sprite, w, h, dx, dy, over, ambient });
  }

  path(x: number, y: number) {
    if (x < 0 || y < 0 || x >= this.cols || y >= this.rows || this.blocked.has(key(x, y))) return;
    this.paths.add(key(x, y));
  }
}

/* ------------------------------------------------------------------ */

/** Grass base everywhere; small flower beds only in a few calm pockets. */
function baseGround(p: Painter) {
  for (let y = 0; y < p.rows; y++) {
    for (let x = 0; x < p.cols; x++) {
      if (p.isBlocked(x, y)) continue;
      const bed = h2(x >> 2, y >> 2, 11) % 11;
      const roll = h2(x, y, 1) % 23;
      if (bed === 0 && roll < 11) {
        p.set(x, y, ['flowers-poppy', 'flowers-daisy', 'flowers-lavender', 'flowers-gold'][h2(x, y, 12) % 4]!);
      } else {
        p.set(x, y, `grass-${h2(x, y, 2) % 3}`);
      }
    }
  }
}

/** Main commons path. Its Y is chosen in the open lane between districts. */
function road(p: Painter, y: number) {
  for (let x = 4; x < p.cols - 4; x++) p.path(x, y);
}

/** Vertical lane (village street) connecting two road rows at column x. */
function lane(p: Painter, x: number, y0: number, y1: number) {
  for (let y = Math.min(y0, y1); y <= Math.max(y0, y1); y++) p.path(x, y);
}

/** Resolve the actual path network into connected, correctly shaped tiles. */
function renderPaths(p: Painter) {
  const names = [
    'dot',
    'end-n',
    'end-s',
    'v',
    'end-w',
    'turn-nw',
    'turn-sw',
    'tee-e',
    'end-e',
    'turn-ne',
    'turn-se',
    'tee-w',
    'h',
    'tee-s',
    'tee-n',
    'cross',
  ];
  for (const at of p.paths) {
    const [xText, yText] = at.split(',');
    const x = Number(xText);
    const y = Number(yText);
    let mask = 0;
    if (p.paths.has(key(x, y - 1))) mask |= 1;
    if (p.paths.has(key(x, y + 1))) mask |= 2;
    if (p.paths.has(key(x - 1, y))) mask |= 4;
    if (p.paths.has(key(x + 1, y))) mask |= 8;
    p.set(x, y, `trail-${names[mask] ?? 'dot'}`, true);
  }
}

/** Creek down a column band with shoreline edges. Returns the creek column. */
function creek(p: Painter, preferredX: number, bridgeRows: ReadonlySet<number>) {
  let x = Math.max(6, Math.min(p.cols - 3, preferredX));
  for (let y = 0; y < p.rows; y++) {
    // gentle meander
    if (y % 5 === 4 && !bridgeRows.has(y)) x += h2(y, 0, 9) % 2 ? 1 : -1;
    x = Math.max(5, Math.min(p.cols - 3, x));
    for (const cx of [x, x + 1]) {
      if (bridgeRows.has(y)) {
        p.set(cx, y, 'dirt', true);
        continue;
      }
      p.set(cx, y, 'water', true);
      // soft shore on both banks
      const west = p.get(x - 1, y);
      if (west.startsWith('grass') || west.startsWith('flowers')) p.set(x - 1, y, 'water-edge-e');
      const east = p.get(x + 2, y);
      if (east.startsWith('grass') || east.startsWith('flowers')) p.set(x + 2, y, 'water-edge-w');
    }
  }
  return x;
}

function creekSafe(p: Painter): number {
  return (p as unknown as { creekX: number }).creekX ?? p.cols - 4;
}

/** Feather hard road/shore lines into the grass (game-map finish). */
function feather(p: Painter) {
  const snap = new Map(p.cells);
  for (const [at, tile] of snap) {
    const [xs, ys] = at.split(',');
    const x = Number(xs);
    const y = Number(ys);
    if (tile !== 'dirt') continue;
    const n = (snap.get(`${x},${y - 1}`) ?? 'grass').startsWith('grass');
    const s2 = (snap.get(`${x},${y + 1}`) ?? 'grass').startsWith('grass');
    const w = (snap.get(`${x - 1},${y}`) ?? 'grass').startsWith('grass');
    const e = (snap.get(`${x + 1},${y}`) ?? 'grass').startsWith('grass');
    if (n && s2) continue; // mid crossing stays clean
    if (n) p.set(x, y, 'dirt-n');
    else if (s2) p.set(x, y, 'dirt-s');
    else if (w) p.set(x, y, 'dirt-w');
    else if (e) p.set(x, y, 'dirt-e');
  }
}

/** Bridge planks where a road crosses the creek. */
function bridgeAt(p: Painter, creekX: number, y: number) {
  p.sprite(`bridge:${creekX},${y}`, creekX - 1, y - 1, 'bridge', 48, 48, 0, -8, false);
}

/** Framing groves with natural gaps around buildings and paths. */
function forest(p: Painter, creekX: number) {
  const planted = new Set<string>();
  for (let y = 0; y < p.rows; y++) {
    for (let x = 0; x < p.cols; x++) {
      if (p.isBlocked(x, y)) continue;
      if (!p.get(x, y).startsWith('grass')) continue;
      const edge = x < 4 || x >= p.cols - 4 || y < 2 || y >= p.rows - 3;
      const nearCreek = Math.abs(x - creekX) <= 2;
      const roll = h2(x, y, 3) % 31;
      const nearBuilding = [-1, 0, 1].some((dy) => [-1, 0, 1].some((dx) => p.blocked.has(key(x + dx, y + dy))));
      const nearTree = [-1, 0, 1].some((dy) => [-1, 0, 1].some((dx) => planted.has(key(x + dx, y + dy))));
      const grove = h2(x >> 2, y >> 2, 23) % 6 === 0;
      const wantTree = !nearBuilding && !nearTree && (edge ? roll < 11 : nearCreek ? roll < 5 : grove && roll < 12);
      if (wantTree) {
        const kind = h2(x, y, 4) % 12;
        const tree = kind < 3 ? 'tree-pine' : kind === 3 ? 'tree-blossom' : kind === 4 ? 'tree-amber' : 'tree-round';
        p.sprite(`tree:${x},${y}`, x, y, tree, 32, 40, -8, -26, true);
        planted.add(key(x, y));
      } else if (roll === 6) p.sprite(`bush:${x},${y}`, x, y, 'bush', 16, 12, 0, 4);
      else if (roll === 7) p.sprite(`rock:${x},${y}`, x, y, 'rock', 16, 12, 0, 5);
      else if (roll === 8) p.sprite(`grass-tuft:${x},${y}`, x, y, 'tall-grass', 16, 8, 0, 8);
      else if (roll === 9 && edge) p.sprite(`shroom:${x},${y}`, x, y, 'mushroom', 16, 12, 0, 5);
    }
  }
}

/** Plaza stones behind the hall; sign + lamps on the commons edge. */
function plazaCore(p: Painter, hall: LaidOutEntity | undefined, commons: readonly LaidOutEntity[]) {
  if (hall) {
    const y = hall.y + hall.h;
    if (y < p.rows) {
      const center = hall.x + Math.floor(hall.w / 2);
      for (let x = center - 1; x <= center + 1; x++) {
        if (!p.isBlocked(x, y)) p.set(x, y, (x + y) % 2 ? 'plaza' : 'plaza-b', true);
      }
    }
    // A small paved commons gives the two civic streets a readable center.
    const center = hall.x + Math.floor(hall.w / 2);
    for (let y = 9; y <= 10; y++) {
      for (let x = center - 1; x <= center + 1; x++) {
        if (!p.isBlocked(x, y) && p.get(x, y).startsWith('grass')) {
          p.set(x, y, (x + y) % 2 ? 'plaza' : 'plaza-b');
        }
      }
    }
  }
  // lamps flank the commons lane
  const lampYs = new Set<number>();
  for (const c of commons) {
    const ly = c.y + c.h;
    if (ly < p.rows && !p.isBlocked(c.x - 1, ly) && p.get(c.x - 1, ly).startsWith('grass')) {
      if (h2(c.x, ly, 5) % 2 === 0) {
        p.sprite(`lamp:${c.x},${ly}`, c.x - 1, ly, 'lamp', 16, 24, 0, -10);
        lampYs.add(ly);
      }
    }
  }
  if (hall && !p.isBlocked(hall.x + hall.w, hall.y + hall.h - 1)) {
    p.sprite(`sign:${hall.x},${hall.y}`, hall.x + hall.w, hall.y + hall.h - 1, 'sign', 16, 16, 0, 1);
  }
}

/** One hornero perched near the hall + butterflies over flower beds. */
function wildlife(p: Painter, hall: LaidOutEntity | undefined) {
  if (hall) {
    p.sprite('hornero:hall', hall.x + hall.w, hall.y - 1, 'hornero', 16, 12, 4, 6, true, true);
  }
  let seen = 0;
  for (const [at, tile] of p.cells) {
    if (!tile.startsWith('flowers')) continue;
    const [xs, ys] = at.split(',');
    const x = Number(xs);
    const y = Number(ys);
    if (!Number.isFinite(x) || !Number.isFinite(y)) continue;
    if (h2(x, y, 6) % 3 !== 0) continue;
    p.sprite(`butterfly:${at}`, x, y, 'butterfly', 8, 8, 4, 2, true, true);
    if (++seen >= 6) break;
  }
  // two fireflies hover near the creek's north end (subtle dusk sparkle)
  for (const y of [1, 3]) {
    const t = p.get(creekSafe(p) - 2, y);
    if (t.startsWith('grass')) {
      p.sprite(`firefly:${y}`, creekSafe(p) - 2, y, 'firefly', 6, 6, 5, 5, true, true);
    }
  }
}

/* ------------------------------------------------------------------ */

/** Compose the valley terrain around the laid-out entities. */
export function paintTerrain(entities: readonly LaidOutEntity[], cols: number, rows: number): TerrainPlan {
  const p = new Painter(cols, rows, entities);
  baseGround(p);

  const hall = entities.find((e) => e.id === 'place:workspace');
  const projects = entities.filter((e) => e.id.startsWith('place:project:') && e.kind === 'place');
  const commons = entities.filter(
    (e) => e.kind === 'place' && e.id !== 'place:workspace' && !e.id.startsWith('place:project:'),
  );
  const projectYs = projects.map((e) => e.y);
  const roadY = projectYs.length ? Math.min(...projectYs) - 1 : 15;

  // creek first so roads bridge it
  const creekX = creek(p, cols - 4, new Set([roadY]));
  (p as unknown as { creekX: number }).creekX = creekX;
  road(p, roadY);
  // A continuous north-south path links the hall, civic square and projects.
  const hallCx = hall ? hall.x + Math.floor(hall.w / 2) : 3;
  lane(p, hallCx, roadY, hall ? hall.y + hall.h : 2);
  // Each landmark has a short approach from its front door to the civic path.
  for (const place of commons) {
    if (place.id === 'place:memory') continue;
    const doorX = place.x + Math.floor(place.w / 2);
    const doorY = place.y + place.h;
    const targetY = doorY <= 11 ? 10 : roadY;
    lane(p, doorX, doorY, targetY);
    if (targetY === 10) {
      for (let x = Math.min(doorX, hallCx); x <= Math.max(doorX, hallCx); x++) p.path(x, targetY);
    }
  }
  // street lanes between project columns
  const colXs = [...new Set(projects.map((e) => e.x))].sort((a, b) => a - b);
  const projectBottom = projects.length ? Math.max(...projects.map((e) => e.y + e.h)) : roadY;
  for (let i = 0; i < colXs.length - 1; i++) {
    const gx = colXs[i]! + 3; // gutter between 3-wide houses
    lane(p, gx, roadY, projectBottom - 1);
  }
  if (projects.length === 0) {
    const marker = entities.find((e) => e.id === 'place:projects-empty');
    if (marker) lane(p, marker.x + Math.floor(marker.w / 2), marker.y + marker.h, roadY);
  }
  renderPaths(p);
  bridgeAt(p, creekX, roadY);
  feather(p);
  plazaCore(p, hall, commons);
  forest(p, creekX);
  wildlife(p, hall);

  return { cells: cellsToArray(p), decor: p.decor };
}

function cellsToArray(p: Painter): TerrainCell[] {
  const out: TerrainCell[] = [];
  for (const [at, tile] of p.cells) {
    const [xs, ys] = at.split(',');
    const x = Number(xs);
    const y = Number(ys);
    if (!Number.isFinite(x) || !Number.isFinite(y)) continue;
    out.push({ x, y, tile });
  }
  return out;
}

/** Interior room floor/walls + furniture footprint dressing. */
export function paintInterior(entities: readonly LaidOutEntity[], cols: number, rows: number): TerrainPlan {
  const p = new Painter(cols, rows, entities);
  for (let y = 0; y < rows; y++) {
    for (let x = 0; x < cols; x++) {
      if (p.isBlocked(x, y)) continue;
      p.set(x, y, y === 0 ? 'wall' : (x + y) % 2 ? 'floor-a' : 'floor-b', true);
    }
  }
  const exit = entities.find((e) => e.id === 'object:exit-grounds');
  if (exit) p.sprite('exit-door', exit.x, exit.y, 'exit', 16, 24, 8, -6, true);
  const room = entities.find((e) => e.id.startsWith('place:project:'));
  if (room) p.sprite('rug', room.x + 1, room.y + room.h, 'rug', 32, 16, 8, 2);
  return { cells: cellsToArray(p), decor: p.decor };
}
