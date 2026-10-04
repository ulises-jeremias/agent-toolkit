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

/** Grass base everywhere; broad color shifts keep the lawn calm, not flat. */
function baseGround(p: Painter) {
  for (let y = 0; y < p.rows; y++) {
    for (let x = 0; x < p.cols; x++) {
      if (p.isBlocked(x, y)) continue;
      const moisture = meadowField(x, y, 7, 11) * 0.65 + meadowField(x, y, 15, 17) * 0.35;
      const bloom = meadowField(x, y, 4, 19);
      const roll = h2(x, y, 1) % 23;
      if (bloom > 0.77 && roll < 17) {
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
        // Each moisture band has four authored tile patterns. Spatially
        // seeded choice breaks up repeated 16px stamps without adding noise.
        const texture = Math.min(3, Math.floor(meadowField(x, y, 5, 59) * 4));
        p.set(x, y, `grass-${grass * 4 + texture}`);
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

/** Main commons route meanders, but meets the bridge at its exact level. */
function road(p: Painter, y: number, bridgeX: number, routeEndX: number, startX: number) {
  let previous = { x: startX, y };
  const phase = ((h2(0, y, 31) % 1000) / 1000) * Math.PI * 2;
  const endX = Math.max(bridgeX + 1, Math.min(p.cols - 1, routeEndX));
  for (let x = startX; x <= endX; x++) {
    const sideStart = x <= bridgeX ? 4 : bridgeX;
    const sideEnd = x <= bridgeX ? bridgeX : endX;
    const t = (x - sideStart) / Math.max(1, sideEnd - sideStart);
    const bend = Math.sin(t * Math.PI) * Math.sin(t * Math.PI * 2 + phase);
    // Keep the immediate approach and all three bridge tiles level so the
    // meandering footpath visibly meets the crossing without a one-tile step.
    const crossing = x >= bridgeX - 1 && x < bridgeX + 3;
    // The commons road can sway gently on either bank. Keep the approach to
    // the project lane bowed south: its houses sit immediately beyond it.
    const bank = x < bridgeX - 1 ? Math.round(bend * 1.35) : Math.max(0, Math.round(bend * 1.35));
    const current = { x, y: crossing ? y : y + bank };
    rasterLine(p, previous.x, previous.y, current.x, current.y);
    previous = current;
  }
}

/** Connect a real entrance to the existing street without crossing buildings or water. */
function connectEntrance(p: Painter, startX: number, startY: number) {
  const start = key(startX, startY);
  if (p.paths.has(start)) return;

  const queue = [start];
  const parent = new Map<string, string | null>([[start, null]]);
  let target: string | undefined;
  const steps = [
    [0, -1],
    [-1, 0],
    [1, 0],
    [0, 1],
  ] as const;

  for (let head = 0; head < queue.length && !target; head++) {
    const at = queue[head]!;
    const [x = 0, y = 0] = at.split(',').map(Number);
    for (const [dx, dy] of steps) {
      const nx = x + dx;
      const ny = y + dy;
      const next = key(nx, ny);
      if (parent.has(next) || p.isBlocked(nx, ny)) continue;
      if (p.paths.has(next)) {
        parent.set(next, at);
        target = next;
        break;
      }
      if (p.get(nx, ny) === 'water') continue;
      parent.set(next, at);
      queue.push(next);
    }
  }

  if (!target) return;
  let cursor: string | null = parent.get(target)!;
  while (cursor) {
    const [x = 0, y = 0] = cursor.split(',').map(Number);
    p.path(x, y);
    cursor = parent.get(cursor) ?? null;
  }
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

/** A winding east-valley stream that bends around real building footprints. */
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
  const runMinX = Math.max(6, minCenterX - 5);
  const preferredFitsBank = preferredX >= minCenterX && preferredX <= maxCenterX;
  const bankCenter = Math.round((minCenterX + maxCenterX) / 2);
  const baseX = preferredFitsBank ? preferredX : bankCenter;
  const corridorRadius = (maxCenterX - runMinX) / 2;
  const broadBend = Math.min(3.4, corridorRadius * 1.25);
  const softBend = Math.min(0.9, corridorRadius * 0.32);
  const creekRows = Array.from({ length: p.rows }, (_, y) => {
    const along = y - bridgeY;
    // The bridge remains the fixed crossing while the stream swings through a
    // wide, low-frequency S-curve. A shorter bend keeps its banks irregular
    // without creating per-row jitter.
    const anchoredSoftBend = Math.sin(along * 0.31 + 0.7) - Math.sin(0.7);
    const desiredX = baseX + Math.sin(along * 0.22) * broadBend + anchoredSoftBend * softBend;
    const pool = Math.sin(along * 0.25 + 0.9);
    const width = pool > 0.45 ? 3 : 2;
    // Prefer the east-valley corridor and search the full map only when a real
    // footprint closes it. Never invent a fallback coordinate through a lot.
    const preferredCenters = Array.from({ length: maxCenterX - runMinX + 1 }, (_, offset) => runMinX + offset);
    const safeInCorridor = preferredCenters.filter((candidate) =>
      Array.from({ length: width }, (_, offset) => candidate + offset).every((column) => !p.isBlocked(column, y)),
    );
    const safeCenters =
      safeInCorridor.length > 0
        ? safeInCorridor
        : Array.from({ length: p.cols - width - 2 }, (_, offset) => offset + 1).filter((candidate) =>
            Array.from({ length: width }, (_, offset) => candidate + offset).every((column) => !p.isBlocked(column, y)),
          );
    return { y, width, desiredX, safeCenters };
  });

  // Plan the whole stream before painting it. A row-by-row greedy choice can
  // push the creek sharply against a façade at the last moment; this tiny
  // dynamic program keeps it within one tile of the next row while finding a
  // clear course around each occupied lot.
  const candidateRows = creekRows.map((row) => row.safeCenters);
  // An exceptional full-width obstruction has no valid continuous route.
  // Omit the creek instead of drawing through a project or landmark.
  if (candidateRows.some((candidates) => candidates.length === 0)) return null;
  const costs: number[][] = [];
  const parents: number[][] = [];
  creekRows.forEach((row, rowIndex) => {
    const candidates = candidateRows[rowIndex]!;
    costs[rowIndex] = candidates.map((candidate, candidateIndex) => {
      if (rowIndex === 0) return Math.abs(candidate - row.desiredX);
      const previousCandidates = candidateRows[rowIndex - 1]!;
      const previousCosts = costs[rowIndex - 1]!;
      const transitions = previousCandidates
        .map((previous, previousIndex) => ({
          previous,
          previousIndex,
          cost: previousCosts[previousIndex]!,
        }))
        .filter(({ previous, cost }) => Number.isFinite(cost) && Math.abs(candidate - previous) <= 1);
      if (transitions.length === 0) return Number.POSITIVE_INFINITY;
      const best = transitions.reduce((left, right) => (right.cost < left.cost ? right : left));
      parents[rowIndex] ??= [];
      parents[rowIndex]![candidateIndex] = best.previousIndex;
      return Math.abs(candidate - row.desiredX) + best.cost;
    });
  });
  if (!costs.at(-1)!.some(Number.isFinite)) return null;
  const creekCenters = new Array<number>(p.rows);
  let routeIndex = costs
    .at(-1)!
    .reduce((bestIndex, cost, index, all) => (cost < all[bestIndex]! ? index : bestIndex), 0);
  for (let rowIndex = creekRows.length - 1; rowIndex >= 0; rowIndex -= 1) {
    const row = creekRows[rowIndex]!;
    creekCenters[row.y] = candidateRows[rowIndex]![routeIndex]!;
    routeIndex = parents[rowIndex]?.[routeIndex] ?? 0;
  }
  const crossingX = creekCenters[bridgeY] ?? baseX;
  for (let y = 0; y < p.rows; y++) {
    const x = creekCenters[y] ?? baseX;
    const { width } = creekRows[y]!;
    for (let cx = x; cx < x + width; cx++) {
      if (p.isBlocked(cx, y)) continue;
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

function nearStructureOrPath(p: Painter, x: number, y: number, radius: number): boolean {
  for (let dy = -radius; dy <= radius; dy++) {
    for (let dx = -radius; dx <= radius; dx++) {
      if (p.isBlocked(x + dx, y + dy) || p.paths.has(key(x + dx, y + dy))) return true;
    }
  }
  return false;
}

/** Broad irregular flower beds give open lawns a visible meadow rhythm. */
function flowerGlades(p: Painter): { x: number; y: number; kind: number }[] {
  // Give the quiet spaces a visible meadow rhythm at overview scale. Glades
  // stay grouped and seed-stable so additional color does not become speckle.
  const target = Math.min(18, Math.max(5, Math.floor((p.cols * p.rows) / 54)));
  const candidates: { x: number; y: number; rank: number }[] = [];
  for (let y = 3; y < p.rows - 2; y++) {
    for (let x = 2; x < p.cols - 2; x++) {
      if (!p.get(x, y).startsWith('grass') || nearStructureOrPath(p, x, y, 0)) continue;
      candidates.push({ x, y, rank: h2(x, y, 131) });
    }
  }
  candidates.sort((a, b) => a.rank - b.rank || a.y - b.y || a.x - b.x);

  const centers: { x: number; y: number }[] = [];
  const glades: { x: number; y: number; kind: number }[] = [];
  for (const candidate of candidates) {
    if (centers.length >= target) break;
    if (centers.some((center) => Math.hypot(center.x - candidate.x, center.y - candidate.y) < 6)) continue;
    centers.push(candidate);

    const radiusX = 3 + (h2(candidate.x, candidate.y, 137) % 2);
    const radiusY = 2 + (h2(candidate.x, candidate.y, 139) % 2);
    const blooms = ['flowers-poppy', 'flowers-daisy', 'flowers-lavender', 'flowers-gold'] as const;
    const primary = h2(candidate.x, candidate.y, 149) % blooms.length;
    const secondary = (primary + 1 + (h2(candidate.x, candidate.y, 157) % 3)) % blooms.length;
    glades.push({ x: candidate.x, y: candidate.y, kind: primary });
    for (let dy = -radiusY; dy <= radiusY; dy++) {
      for (let dx = -radiusX; dx <= radiusX; dx++) {
        const distance = (dx * dx) / (radiusX * radiusX) + (dy * dy) / (radiusY * radiusY);
        const x = candidate.x + dx;
        const y = candidate.y + dy;
        if (
          distance <= 1.25 &&
          h2(x, y, 151) % 9 !== 0 &&
          p.get(x, y).startsWith('grass') &&
          !nearStructureOrPath(p, x, y, 0)
        ) {
          const accent = h2(x, y, 163) % 5 === 0;
          p.set(x, y, blooms[accent ? secondary : primary]!);
        }
      }
    }
  }
  return glades;
}

/** Larger blossoms punctuate a few clearings; their footprints avoid paths and buildings. */
function flowerPatchSprites(p: Painter, glades: readonly { x: number; y: number; kind: number }[]) {
  const patchNames = ['wildflower-patch-rose', 'wildflower-patch-lilac', 'wildflower-patch-gold'] as const;
  for (const [index, glade] of glades.entries()) {
    if (index % 2 !== 0 || nearStructureOrPath(p, glade.x, glade.y, 2)) continue;
    const hasTreeCanopy = p.decor.some(
      (decor) =>
        decor.sprite.startsWith('tree-') && Math.abs(decor.x - glade.x) <= 2 && Math.abs(decor.y - glade.y) <= 2,
    );
    if (hasTreeCanopy) continue;
    p.sprite(
      `flower-patch:${glade.x},${glade.y}`,
      glade.x,
      glade.y + 1,
      patchNames[glade.kind % patchNames.length]!,
      32,
      24,
      -8,
      -8,
    );
  }
}

/** Pick a few stable grove hearts inside the settlement, away from its paths. */
function groveAnchors(p: Painter, meadowHeart?: { x: number; y: number }): Set<string> {
  const target = Math.min(5, Math.max(1, Math.floor((p.cols * p.rows) / 240)));
  const candidates: { x: number; y: number; rank: number }[] = [];
  for (let y = 3; y < p.rows - 3; y++) {
    for (let x = 4; x < p.cols - 4; x++) {
      if (!p.get(x, y).startsWith('grass') && !p.get(x, y).startsWith('flowers')) continue;
      if (nearStructureOrPath(p, x, y, 2)) continue;
      candidates.push({ x, y, rank: h2(x, y, 173) });
    }
  }
  if (meadowHeart) {
    const heart = candidates.find((candidate) => candidate.x === meadowHeart.x && candidate.y === meadowHeart.y);
    if (heart) heart.rank = -1;
  }
  candidates.sort((a, b) => a.rank - b.rank || a.y - b.y || a.x - b.x);

  const centers: { x: number; y: number }[] = [];
  const anchors = new Set<string>();
  const offsets = [
    [0, 0],
    [-2, 0],
    [2, 0],
    [-1, 1],
    [1, 1],
  ] as const;
  for (const candidate of candidates) {
    if (centers.length >= target) break;
    if (centers.some((center) => Math.hypot(center.x - candidate.x, center.y - candidate.y) < 9)) continue;
    centers.push(candidate);
    for (const [dx, dy] of offsets) {
      const x = candidate.x + dx;
      const y = candidate.y + dy;
      if (p.get(x, y).startsWith('grass') || p.get(x, y).startsWith('flowers')) anchors.add(key(x, y));
    }
  }
  return anchors;
}

/** Framing groves with natural gaps around buildings and paths. */
function forest(p: Painter, projectlessMeadow = false) {
  const creeksideHeart = projectlessMeadow ? { x: creekSafe(p) + 4, y: 3 } : undefined;
  const plantedGroves = groveAnchors(p, creeksideHeart);
  for (let y = 0; y < p.rows; y++) {
    for (let x = 0; x < p.cols; x++) {
      if (p.isBlocked(x, y)) continue;
      const ground = p.get(x, y);
      // A tree may root among flowers; the crown and shaded trunk naturally
      // interrupt a meadow patch without turning the blossom cells into noise.
      if (!ground.startsWith('grass') && !ground.startsWith('flowers')) continue;
      const edge = x < 6 || x >= p.cols - 6 || y < 3 || y >= p.rows - 4;
      const nearCreek = [-4, -3, -2, -1, 0, 1, 2, 3, 4].some((dx) => p.get(x + dx, y) === 'water');
      const roll = h2(x, y, 3) % 31;
      // Reserve the whole oversized canopy footprint around real buildings.
      // Checking only the tree anchor lets a bright crown crowd a nearby
      // façade even though its trunk is technically on free ground.
      const canopyOverBuilding = [-2, -1, 0, 1].some((dy) =>
        [-2, -1, 0, 1, 2].some((dx) => p.blocked.has(key(x + dx, y + dy))),
      );
      const nearTrail = [-2, -1, 0, 1, 2].some((dy) =>
        [-2, -1, 0, 1, 2].some((dx) => p.paths.has(key(x + dx, y + dy))),
      );
      const grove = insideGrove(x, y);
      // Keep tall canopies fully inside the framed world; low grass and
      // flowers can still reach the edge without looking accidentally cut.
      const treeInsideFrame = x >= 1 && x < p.cols - 1 && y >= 3;
      const naturallyWooded = edge ? roll < (x >= p.cols - 6 ? 14 : 23) : nearCreek ? roll < 11 : grove && roll < 12;
      const woodlandCell = plantedGroves.has(key(x, y)) || naturallyWooded;
      const wantTree = treeInsideFrame && !canopyOverBuilding && !nearTrail && woodlandCell;
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
        p.sprite(`tree:${x},${y}`, x, y, tree, 48, 48, -16 + canopyOffsetX, -32 + canopyOffsetY, false);
      } else if (roll === 5 || roll === 6) p.sprite(`bush:${x},${y}`, x, y, 'bush', 16, 12, 0, 4);
      else if (roll === 7 || roll === 8) p.sprite(`rock:${x},${y}`, x, y, 'rock', 16, 12, 0, 5);
      else if (roll === 9 || roll === 10) p.sprite(`grass-tuft:${x},${y}`, x, y, 'tall-grass', 16, 8, 0, 8);
      else if (roll === 11 && edge) p.sprite(`shroom:${x},${y}`, x, y, 'mushroom', 16, 12, 0, 5);
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
    for (let dy = -1; dy <= 2; dy++) {
      for (let dx = -5; dx <= 5; dx++) {
        const inside = (dx * dx) / 30 + (dy * dy) / 4 <= 1;
        const x = centerX + dx;
        const y = frontY + dy;
        // Stone belongs on the real connected approach, not as a decorative
        // patch on otherwise empty grass beside a building.
        if (inside && p.paths.has(key(x, y)) && !p.isBlocked(x, y)) {
          p.set(x, y, (x + y) % 2 ? 'plaza' : 'plaza-b', true);
        }
      }
    }
  }
}

/** One hornero perched near the hall + butterflies over flower beds. */
function wildlife(p: Painter, hall: LaidOutEntity | undefined) {
  if (hall) {
    p.sprite('hornero:hall', hall.x + hall.w, hall.y + 1, 'hornero', 16, 12, 4, 6, true, true);
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
  // Fireflies trace quiet stretches of the real creek, not runtime activity.
  const fireflyRows = new Set([
    2,
    Math.floor(p.rows * 0.28),
    Math.floor(p.rows * 0.52),
    Math.floor(p.rows * 0.76),
    p.rows - 3,
  ]);
  let fireflyCount = 0;
  for (const y of fireflyRows) {
    const x = creekSafe(p) - 2;
    if (p.get(x, y).startsWith('grass')) {
      p.sprite(`firefly:${y}`, x, y, 'firefly', 6, 6, 5, 5, true, true);
      if (++fireflyCount >= 4) break;
    }
  }
  // A few sharp glints sit directly on real water tiles; they are ambient
  // scenery, and never encode a job, session, or other runtime state.
  let sparkleCount = 0;
  let moteCount = 0;
  for (const [at, tile] of p.cells) {
    const [xs, ys] = at.split(',');
    const x = Number(xs);
    const y = Number(ys);
    if (!Number.isFinite(x) || !Number.isFinite(y)) continue;
    if (tile === 'water' && h2(x, y, 83) % 6 === 0 && sparkleCount < 5) {
      p.sprite(`water-sparkle:${at}`, x, y, 'water-sparkle', 8, 8, 4, 4, true, true);
      sparkleCount += 1;
    }
    if (
      tile.startsWith('grass') &&
      Math.abs(x - creekSafe(p)) <= 5 &&
      y > 4 &&
      h2(x, y, 97) % 43 === 0 &&
      moteCount < 4
    ) {
      p.sprite(`mote:${at}`, x, y, 'mote', 5, 5, 5, 5, true, true);
      moteCount += 1;
    }
  }
}

/** Paired lanterns mark the shared bridge as a welcoming route at dusk. */
function bridgeLanterns(p: Painter, creekX: number, roadY: number) {
  for (const [side, bankTiles] of [
    ['west', [creekX - 2, creekX - 1, creekX - 3]],
    ['east', [creekX + 3, creekX + 4, creekX + 2]],
  ] as const) {
    // The crossing row is paved across the water, so both posts stand on a
    // real bank-side ground cell instead of appearing to float in the stream.
    // A nearby project porch may claim the preferred post tile; slide one
    // tile along the same bank so the bridge still reads as a paired welcome.
    const y = roadY;
    const x = bankTiles.find((candidate) => !p.isBlocked(candidate, y) && p.get(candidate, y) !== 'water');
    if (x === undefined) continue;
    p.sprite(`bridge-lantern:${side}`, x, y, 'lamp', 16, 24, 0, -10, false);
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
  const marker = entities.find((e) => e.id === 'place:projects-empty');
  const firstProjectY = projects.length ? Math.min(...projects.map((project) => project.y)) : undefined;
  const firstStreetProjects =
    firstProjectY === undefined ? [] : projects.filter((project) => project.y <= firstProjectY + 2);
  const firstStreetDoorY = firstStreetProjects.length
    ? Math.max(...firstStreetProjects.map((project) => project.y + project.h))
    : marker
      ? marker.y + marker.h
      : undefined;
  const roadY = firstStreetDoorY ?? Math.floor(rows / 2);

  // creek first so roads bridge it
  const workshop = entities.find((e) => e.id === 'object:workshop');
  const riverAnchorX = projects.length
    ? Math.min(...projects.map((project) => project.x))
    : (marker?.x ?? Math.floor(cols / 2));
  const riverX = riverAnchorX - (projects.length ? 2 : 8);
  // Start the street on the actual west bank so the crossing is always joined
  // to the path network, even when a civic building sits farther east.
  const plannedCreekX = creek(p, riverX, new Set([roadY]), riverAnchorX - 3, workshop ? workshop.x + workshop.w : 6);
  const creekX = plannedCreekX ?? Math.max(4, Math.min(cols - 5, riverX));
  (p as unknown as { creekX: number }).creekX = creekX;
  const routeEndX = projects.length
    ? Math.max(...projects.map((project) => project.x + Math.floor(project.w / 2)))
    : marker
      ? marker.x + Math.floor(marker.w / 2)
      : cols - 4;
  road(p, roadY, creekX, routeEndX, creekX - 1);
  // Join each real front door to the street. A grid search avoids routing
  // through another building when project lanes share a column.
  if (hall) connectEntrance(p, hall.x + Math.floor(hall.w / 2), hall.y + hall.h);
  for (const place of commons) {
    if (place.id === 'place:memory') continue;
    const doorX = place.x + Math.floor(place.w / 2);
    const doorY = place.y + place.h;
    connectEntrance(p, doorX, doorY);
  }
  for (const project of projects) {
    const doorX = project.x + Math.floor(project.w / 2);
    const doorY = project.y + project.h;
    connectEntrance(p, doorX, doorY);
  }
  projectGardens(p, projects);
  if (projects.length === 0) {
    if (marker) {
      const doorX = marker.x + Math.floor(marker.w / 2);
      const doorY = marker.y + marker.h;
      connectEntrance(p, doorX, doorY);
    }
  }
  renderPaths(p);
  if (plannedCreekX !== null) {
    bridgeAt(p, creekX, roadY);
    bridgeLanterns(p, creekX, roadY);
  }
  feather(p);
  plazaCore(p, hall, commons);
  const glades = flowerGlades(p);
  forest(p, projects.length === 0);
  flowerPatchSprites(p, glades);
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
