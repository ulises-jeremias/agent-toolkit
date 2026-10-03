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

/** Smooth seeded value noise for broad terrain patches, never per-tile noise. */
function meadowField(x: number, y: number, scale: number, salt: number): number {
  const gx = Math.floor(x / scale);
  const gy = Math.floor(y / scale);
  const fx = (x - gx * scale) / scale;
  const fy = (y - gy * scale) / scale;
  const smooth = (value: number) => value * value * (3 - 2 * value);
  const sx = smooth(fx);
  const sy = smooth(fy);
  const value = (cx: number, cy: number) => h2(cx, cy, salt) / 0xffffffff;
  const north = value(gx, gy) * (1 - sx) + value(gx + 1, gy) * sx;
  const south = value(gx, gy + 1) * (1 - sx) + value(gx + 1, gy + 1) * sx;
  return north * (1 - sy) + south * sy;
}

/** Irregular grove patches seeded on a coarse lattice, not checkerboard tiles. */
function insideGrove(x: number, y: number): boolean {
  const cellSize = 9;
  const cellX = Math.floor(x / cellSize);
  const cellY = Math.floor(y / cellSize);
  for (let gy = cellY - 1; gy <= cellY + 1; gy++) {
    for (let gx = cellX - 1; gx <= cellX + 1; gx++) {
      const seedX = gx * cellSize + 2 + (h2(gx, gy, 23) % 5);
      const seedY = gy * cellSize + 2 + (h2(gx, gy, 29) % 5);
      const radius = 3 + (h2(gx, gy, 31) % 4);
      const dx = x - seedX;
      const dy = (y - seedY) * 1.15;
      if (dx * dx + dy * dy <= radius * radius) return true;
    }
  }
  return false;
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
      const moisture = meadowField(x, y, 7, 11) * 0.65 + meadowField(x, y, 15, 17) * 0.35;
      const bloom = meadowField(x, y, 4, 19);
      const roll = h2(x, y, 1) % 23;
      if (bloom > 0.82 && roll < 14) {
        p.set(x, y, ['flowers-poppy', 'flowers-daisy', 'flowers-lavender', 'flowers-gold'][h2(x, y, 12) % 4]!);
      } else {
        const grass =
          moisture < 0.16
            ? 4
            : moisture < 0.36
              ? 2
              : moisture < 0.68
                ? 0
                : moisture < 0.84
                  ? 1
                  : moisture < 0.94
                    ? 3
                    : 5;
        p.set(x, y, `grass-${grass}`);
      }
    }
  }
}

/** Raster a short segment so curved footpaths never leave diagonal gaps. */
function rasterLine(p: Painter, x0: number, y0: number, x1: number, y1: number) {
  let x = x0;
  let y = y0;
  const dx = Math.abs(x1 - x0);
  const sx = x0 < x1 ? 1 : -1;
  const dy = -Math.abs(y1 - y0);
  const sy = y0 < y1 ? 1 : -1;
  let error = dx + dy;
  for (;;) {
    p.path(x, y);
    if (x === x1 && y === y1) break;
    const twice = error * 2;
    if (twice >= dy) {
      error += dy;
      x += sx;
      p.path(x, y);
    }
    if (twice <= dx) {
      error += dx;
      y += sy;
      p.path(x, y);
    }
  }
}

/** A soft, deterministic curve between two meaningful door/road anchors. */
function curvedPath(p: Painter, x0: number, y0: number, x1: number, y1: number, salt: number, amplitude = 1.25) {
  const distance = Math.max(Math.abs(x1 - x0), Math.abs(y1 - y0));
  const steps = Math.max(1, distance * 4);
  const bend = Math.min(amplitude, distance < 3 ? distance * 0.07 : Math.max(1.15, distance * 0.07));
  const phase = ((h2(x0 + x1, y0 + y1, salt) % 1000) / 1000) * Math.PI * 2;
  let previousX = x0;
  let previousY = y0;
  for (let i = 0; i <= steps; i++) {
    const t = i / steps;
    const wave = Math.sin(t * Math.PI) * Math.sin(t * Math.PI * 2 + phase) * bend;
    const x = Math.round(x0 + (x1 - x0) * t + (Math.abs(y1 - y0) > Math.abs(x1 - x0) ? wave : 0));
    const y = Math.round(y0 + (y1 - y0) * t + (Math.abs(x1 - x0) >= Math.abs(y1 - y0) ? wave : 0));
    rasterLine(p, previousX, previousY, x, y);
    previousX = x;
    previousY = y;
  }
}

/** Main commons route meanders, but meets the bridge at its exact level. */
function road(p: Painter, y: number, bridgeX: number, routeEndX: number): Map<number, number> {
  const rows = new Map<number, number>();
  let previous = { x: 4, y };
  const phase = ((h2(0, y, 31) % 1000) / 1000) * Math.PI * 2;
  const endX = Math.max(bridgeX + 1, Math.min(p.cols - 4, routeEndX));
  for (let x = 4; x <= endX; x++) {
    const sideStart = x <= bridgeX ? 4 : bridgeX;
    const sideEnd = x <= bridgeX ? bridgeX : endX;
    const t = (x - sideStart) / Math.max(1, sideEnd - sideStart);
    const bend = Math.sin(t * Math.PI) * Math.sin(t * Math.PI * 2 + phase) * 1.4;
    const crossing = x >= bridgeX && x < bridgeX + 3;
    const current = { x, y: crossing ? y : y + Math.round(bend) };
    rasterLine(p, previous.x, previous.y, current.x, current.y);
    rows.set(x, current.y);
    previous = current;
  }
  return rows;
}

/** Path from a building threshold to the closest street or common. */
function lane(p: Painter, x: number, y0: number, y1: number, salt = 0) {
  curvedPath(p, x, y0, x, y1, salt);
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

/** A broad east-valley creek with a slow, bridge-anchored meander. */
function creek(
  p: Painter,
  preferredX: number,
  bridgeRows: ReadonlySet<number>,
  eastLimit: number,
  workshopBankX: number,
) {
  const bridgeY = [...bridgeRows][0] ?? Math.floor(p.rows / 2);
  const maxCenterX = Math.max(7, Math.min(p.cols - 6, eastLimit));
  const minCenterX = Math.max(6, Math.min(maxCenterX, workshopBankX));
  const baseX = Math.max(7, Math.min(maxCenterX, preferredX));
  let x = baseX;
  let crossingX = x;
  for (let y = 0; y < p.rows; y++) {
    const along = y - bridgeY;
    // Two slow waves create natural reaches and gentle bends while preserving
    // the bridge crossing as a fixed, navigable landmark.
    x = baseX + Math.round(Math.sin(along * 0.15) * 5.5 + Math.sin(along * 0.05) * 2.25);
    x = Math.max(minCenterX, Math.min(maxCenterX, x));
    if (bridgeRows.has(y)) crossingX = x;
    const width = 3;
    for (let cx = x; cx < x + width; cx++) {
      if (bridgeRows.has(y)) {
        p.set(cx, y, 'dirt', true);
        continue;
      }
      p.set(cx, y, 'water', true);
    }
    if (!bridgeRows.has(y)) {
      // Bright shallow banks frame the water and give the path bridge a
      // visible approach. Existing flowers remain as natural river margins.
      const west = p.get(x - 1, y);
      if (west.startsWith('grass') || west.startsWith('flowers')) p.set(x - 1, y, 'water-edge-e');
      const east = p.get(x + width, y);
      if (east.startsWith('grass') || east.startsWith('flowers')) p.set(x + width, y, 'water-edge-w');
      if (y % 9 === 4 && h2(x, y, 37) % 2 === 0) {
        p.sprite(`lily:${x},${y}`, x + 1, y, 'lily', 16, 16, 0, 0, true);
      }
      const reedsSide = h2(x, y, 41) % 2 === 0 ? x - 1 : x + width;
      if (y % 7 === 3 && h2(x, y, 43) % 3 === 0) {
        p.sprite(`reeds:${reedsSide},${y}`, reedsSide, y, 'reeds', 16, 16, 0, 0, true);
      }
    }
  }
  return crossingX;
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
  p.sprite(`bridge:${creekX},${y}`, creekX, y - 1, 'bridge', 48, 48, 0, -8, false);
}

/** Small fenced garden beds make real project lots feel settled into the valley. */
function projectGardens(p: Painter, projects: readonly LaidOutEntity[]) {
  const blooms = ['flowers-daisy', 'flowers-lavender', 'flowers-gold'] as const;
  for (const project of projects) {
    const firstY = project.y + 1;
    const lastY = project.y + project.h - 1;
    const sides = [
      { bedX: project.x + project.w + 1, fenceX: project.x + project.w + 2 },
      { bedX: project.x - 1, fenceX: project.x - 2 },
    ];
    const garden = sides
      .map((side) => ({
        ...side,
        room: Array.from({ length: lastY - firstY + 1 }, (_, index) => firstY + index).filter(
          (y) =>
            !p.isBlocked(side.bedX, y) && !p.paths.has(key(side.bedX, y)) && p.get(side.bedX, y).startsWith('grass'),
        ).length,
      }))
      .sort((a, b) => b.room - a.room)[0]!;

    for (let y = firstY; y <= lastY; y += 1) {
      const fenceAt = key(garden.fenceX, y);
      if (!p.isBlocked(garden.fenceX, y) && !p.paths.has(fenceAt) && p.get(garden.fenceX, y).startsWith('grass')) {
        p.sprite(`project-fence:${project.id}:${y}`, garden.fenceX, y, 'fence-v', 16, 16);
      }
      const bedAt = key(garden.bedX, y);
      if (!p.isBlocked(garden.bedX, y) && !p.paths.has(bedAt) && p.get(garden.bedX, y).startsWith('grass')) {
        p.set(garden.bedX, y, blooms[h2(project.x, y, project.y) % blooms.length]!);
      }
    }

    const shrubX = garden.bedX;
    const shrubY = project.y + project.h;
    if (
      !p.isBlocked(shrubX, shrubY) &&
      !p.paths.has(key(shrubX, shrubY)) &&
      p.get(shrubX, shrubY).startsWith('grass')
    ) {
      p.sprite(`project-shrub:${project.id}`, shrubX, shrubY, 'bush', 16, 12, 0, 4);
    }
  }
}

/** Framing groves with natural gaps around buildings and paths. */
function forest(p: Painter) {
  const planted = new Set<string>();
  for (let y = 0; y < p.rows; y++) {
    for (let x = 0; x < p.cols; x++) {
      if (p.isBlocked(x, y)) continue;
      if (!p.get(x, y).startsWith('grass')) continue;
      const edge = x < 6 || x >= p.cols - 6 || y < 3 || y >= p.rows - 4;
      const nearCreek = [-4, -3, -2, -1, 0, 1, 2, 3, 4].some((dx) => p.get(x + dx, y) === 'water');
      const roll = h2(x, y, 3) % 31;
      const nearBuilding = [-1, 0, 1].some((dy) => [-1, 0, 1].some((dx) => p.blocked.has(key(x + dx, y + dy))));
      const nearTree = [-1, 0, 1].some((dy) => [-1, 0, 1].some((dx) => planted.has(key(x + dx, y + dy))));
      const nearTrail = [-2, -1, 0, 1, 2].some((dy) =>
        [-2, -1, 0, 1, 2].some((dx) => p.paths.has(key(x + dx, y + dy))),
      );
      const grove = insideGrove(x, y);
      const wantTree =
        !nearBuilding &&
        !nearTree &&
        !nearTrail &&
        (edge ? roll < 18 : nearCreek ? grove && roll < 12 : grove && roll < 17);
      if (wantTree) {
        const kind = h2(x, y, 4) % 12;
        const canopyOffsetX = (h2(x, y, 47) % 5) - 2;
        const canopyOffsetY = (h2(x, y, 53) % 3) - 1;
        const tree =
          nearCreek && kind < 4
            ? 'tree-willow'
            : kind < 2
              ? 'tree-pine'
              : kind < 6
                ? 'tree-blossom'
                : kind < 8
                  ? 'tree-amber'
                  : 'tree-round';
        p.sprite(`tree:${x},${y}`, x, y, tree, 32, 40, -8 + canopyOffsetX, -26 + canopyOffsetY, true);
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

  // The front doors of the three public service buildings face one shared
  // commons. Give that real junction a small stone forecourt, not another
  // anonymous road crossing.
  const publicPlaces = commons.filter((place) =>
    ['object:library', 'object:operations', 'object:terminal'].includes(place.id),
  );
  if (publicPlaces.length > 0) {
    const left = Math.min(...publicPlaces.map((place) => place.x));
    const right = Math.max(...publicPlaces.map((place) => place.x + place.w - 1));
    const centerX = Math.round((left + right) / 2);
    const frontY = Math.max(...publicPlaces.map((place) => place.y + place.h));
    for (let dy = 0; dy <= 2; dy++) {
      for (let dx = -5; dx <= 5; dx++) {
        const inside = (dx * dx) / 30 + (dy * dy) / 4 <= 1;
        const x = centerX + dx;
        const y = frontY + dy;
        if (inside && !p.isBlocked(x, y)) p.set(x, y, (x + y) % 2 ? 'plaza' : 'plaza-b', true);
      }
    }
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
  const marker = entities.find((e) => e.id === 'place:projects-empty');
  const roadY = projectYs.length ? Math.min(...projectYs) - 1 : marker ? marker.y - 1 : Math.floor(rows / 2);

  // creek first so roads bridge it
  const workshop = entities.find((e) => e.id === 'object:workshop');
  const riverAnchorX = projects.length
    ? Math.min(...projects.map((project) => project.x))
    : (marker?.x ?? Math.floor(cols / 2));
  const riverX = riverAnchorX - (projects.length ? 2 : 8);
  const creekX = creek(p, riverX, new Set([roadY]), riverAnchorX - 3, workshop ? workshop.x + workshop.w : 6);
  (p as unknown as { creekX: number }).creekX = creekX;
  const routeEndX = projects.length
    ? Math.max(...projects.map((project) => project.x + project.w)) + 2
    : marker
      ? marker.x + marker.w + 2
      : cols - 4;
  const roadRows = road(p, roadY, creekX, routeEndX);
  // A continuous north-south path links the hall, civic square and projects.
  const hallCx = hall ? hall.x + Math.floor(hall.w / 2) : 3;
  lane(p, hallCx, hall ? hall.y + hall.h : 2, roadRows.get(hallCx) ?? roadY, 7);
  // Each landmark has a short approach from its front door to the civic path.
  for (const place of commons) {
    if (place.id === 'place:memory') continue;
    const doorX = place.x + Math.floor(place.w / 2);
    const doorY = place.y + place.h;
    const targetY = doorY <= 11 ? 10 : (roadRows.get(doorX) ?? roadY);
    lane(p, doorX, doorY, targetY, h2(place.x, place.y, 19));
    if (targetY === 10) {
      curvedPath(p, doorX, targetY, hallCx, targetY, h2(place.x, place.y, 21), 0.8);
    }
  }
  for (const project of projects) {
    const doorX = project.x + Math.floor(project.w / 2);
    const doorY = project.y + project.h;
    // Give each house one direct, legible approach to the shared street.
    // Side-gutter spurs created square loops around close-set project lots.
    lane(p, doorX, doorY, roadRows.get(doorX) ?? roadY, h2(project.x, project.y, 27));
  }
  projectGardens(p, projects);
  if (projects.length === 0) {
    if (marker) {
      const doorX = marker.x + Math.floor(marker.w / 2);
      const doorY = marker.y + marker.h;
      lane(p, doorX, doorY, roadRows.get(doorX) ?? roadY, 31);
    }
  }
  renderPaths(p);
  bridgeAt(p, creekX, roadY);
  feather(p);
  plazaCore(p, hall, commons);
  forest(p);
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
      const wall = y === 0 || y === rows - 1 || x === 0 || x === cols - 1;
      // Alternate staggered plank courses so seams and grain do not line up
      // into broad stripes across the whole room.
      const floorVariant = (x + y) % 2 === 0 ? 'floor-a' : 'floor-b';
      p.set(x, y, wall ? 'wall' : floorVariant, true);
    }
  }
  return { cells: cellsToArray(p), decor: p.decor };
}
