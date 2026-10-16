import type { LaidOutEntity } from './model/types';

export const PLAYER_SPEED_TILES_PER_SECOND = 4.5;
const PLAYER_RADIUS = 0.22;

export interface WorldPoint {
  x: number;
  y: number;
}

export interface WorldInput {
  north: boolean;
  south: boolean;
  east: boolean;
  west: boolean;
}

export interface CollisionMap {
  cols: number;
  rows: number;
  blocked: ReadonlySet<string>;
}

export const worldCellKey = (x: number, y: number) => `${x},${y}`;

function canOccupy(point: WorldPoint, map: CollisionMap): boolean {
  if (point.x < PLAYER_RADIUS || point.y < PLAYER_RADIUS) return false;
  if (point.x > map.cols - PLAYER_RADIUS || point.y > map.rows - PLAYER_RADIUS) return false;

  const left = Math.floor(point.x - PLAYER_RADIUS);
  const right = Math.floor(point.x + PLAYER_RADIUS);
  const top = Math.floor(point.y - PLAYER_RADIUS);
  const bottom = Math.floor(point.y + PLAYER_RADIUS);
  for (let y = top; y <= bottom; y += 1) {
    for (let x = left; x <= right; x += 1) {
      if (map.blocked.has(worldCellKey(x, y))) return false;
    }
  }
  return true;
}

/** Move in world-tile coordinates, sliding along walls and preventing tunneling. */
export function stepWorldPlayer(
  current: WorldPoint,
  input: WorldInput,
  elapsedMs: number,
  map: CollisionMap,
): WorldPoint {
  let dx = Number(input.east) - Number(input.west);
  let dy = Number(input.south) - Number(input.north);
  if (dx === 0 && dy === 0) return current;
  const magnitude = Math.hypot(dx, dy);
  dx /= magnitude;
  dy /= magnitude;
  const seconds = Math.min(50, Math.max(0, elapsedMs)) / 1000;
  const distance = PLAYER_SPEED_TILES_PER_SECOND * seconds;
  const next = { ...current };
  const horizontal = { x: current.x + dx * distance, y: current.y };
  if (canOccupy(horizontal, map)) next.x = horizontal.x;
  const vertical = { x: next.x, y: current.y + dy * distance };
  if (canOccupy(vertical, map)) next.y = vertical.y;
  return next;
}

/** Move directly toward a path waypoint without overshooting it. */
export function stepWorldPlayerToward(
  current: WorldPoint,
  target: WorldPoint,
  elapsedMs: number,
  map: CollisionMap,
): WorldPoint {
  const dx = target.x - current.x;
  const dy = target.y - current.y;
  const distance = Math.hypot(dx, dy);
  if (distance === 0) return current;
  const travel = Math.min(distance, (PLAYER_SPEED_TILES_PER_SECOND * Math.min(50, Math.max(0, elapsedMs))) / 1000);
  const next = { x: current.x + (dx / distance) * travel, y: current.y + (dy / distance) * travel };
  if (canOccupy(next, map)) return next;

  // A waypoint may be diagonally offset from the current player position even
  // when the route itself is orthogonal. Keep the path moving along the clear
  // axis instead of freezing against a corner; every partial step still uses
  // the same player-footprint collision check as direct movement.
  const horizontal = { x: current.x + (dx / distance) * travel, y: current.y };
  const vertical = { x: current.x, y: current.y + (dy / distance) * travel };
  const slid = { ...current };
  if (canOccupy(horizontal, map)) slid.x = horizontal.x;
  const verticalAfterSlide = { x: slid.x, y: vertical.y };
  if (canOccupy(verticalAfterSlide, map)) slid.y = vertical.y;
  return slid;
}

/** Find the closest reachable tile to a pointer target, routing around terrain and buildings. */
export function findWorldPath(start: WorldPoint, target: WorldPoint, map: CollisionMap): WorldPoint[] {
  const startCell = { x: Math.floor(start.x), y: Math.floor(start.y) };
  const startKey = worldCellKey(startCell.x, startCell.y);
  const startCenter = { x: startCell.x + 0.5, y: startCell.y + 0.5 };
  if (!canOccupy(start, map) || !canOccupy(startCenter, map)) return [];

  const queue = [startCell];
  const previous = new Map<string, string | null>([[startKey, null]]);
  const cells = new Map<string, { x: number; y: number }>([[startKey, startCell]]);
  const directions = [
    { x: 0, y: -1 },
    { x: 1, y: 0 },
    { x: 0, y: 1 },
    { x: -1, y: 0 },
  ];
  for (let cursor = 0; cursor < queue.length; cursor += 1) {
    const cell = queue[cursor]!;
    for (const direction of directions) {
      const next = { x: cell.x + direction.x, y: cell.y + direction.y };
      const key = worldCellKey(next.x, next.y);
      if (previous.has(key) || !canOccupy({ x: next.x + 0.5, y: next.y + 0.5 }, map)) continue;
      previous.set(key, worldCellKey(cell.x, cell.y));
      cells.set(key, next);
      queue.push(next);
    }
  }

  const destination = [...cells.entries()].reduce((best, candidate) => {
    const point = { x: candidate[1].x + 0.5, y: candidate[1].y + 0.5 };
    const bestPoint = { x: best[1].x + 0.5, y: best[1].y + 0.5 };
    return Math.hypot(point.x - target.x, point.y - target.y) <
      Math.hypot(bestPoint.x - target.x, bestPoint.y - target.y)
      ? candidate
      : best;
  });
  const route: WorldPoint[] = [];
  let cursor: string | null = destination[0];
  while (cursor && cursor !== startKey) {
    const cell = cells.get(cursor);
    if (cell) route.push({ x: cell.x + 0.5, y: cell.y + 0.5 });
    cursor = previous.get(cursor) ?? null;
  }
  return route.reverse();
}

/** Pick the nearest safe tile, preferring a path tile when available. */
export function findWorldSpawn(
  collision: CollisionMap,
  preferred: WorldPoint,
  pathCells: ReadonlySet<string>,
): WorldPoint {
  const candidates: { point: WorldPoint; path: boolean; distance: number }[] = [];
  for (let y = 1; y < collision.rows - 1; y += 1) {
    for (let x = 1; x < collision.cols - 1; x += 1) {
      const point = { x: x + 0.5, y: y + 0.5 };
      if (!canOccupy(point, collision)) continue;
      candidates.push({
        point,
        path: pathCells.has(worldCellKey(x, y)),
        distance: (point.x - preferred.x) ** 2 + (point.y - preferred.y) ** 2,
      });
    }
  }
  candidates.sort((a, b) => a.distance - b.distance || Number(b.path) - Number(a.path));
  return candidates[0]?.point ?? { x: Math.max(0.5, collision.cols / 2), y: Math.max(0.5, collision.rows / 2) };
}

/** Discard saved coordinates if the workspace layout or collision map changed. */
export function restoreWorldPosition(value: string | null, fallback: WorldPoint, map: CollisionMap): WorldPoint {
  if (!value) return fallback;
  try {
    const candidate = JSON.parse(value) as Partial<WorldPoint>;
    if (typeof candidate.x !== 'number' || typeof candidate.y !== 'number') return fallback;
    return canOccupy(candidate as WorldPoint, map) ? (candidate as WorldPoint) : fallback;
  } catch {
    return fallback;
  }
}

function interactionPoint(entity: LaidOutEntity): WorldPoint {
  if (entity.kind === 'place') {
    return { x: entity.x + entity.w / 2, y: entity.y + entity.h + 0.5 };
  }
  return { x: entity.x + entity.w / 2, y: entity.y + entity.h / 2 };
}

/** The closest real inspector the player can interact with from this position. */
export function nearbyWorldTarget(
  position: WorldPoint,
  entities: readonly LaidOutEntity[],
  canInteract: (entity: LaidOutEntity) => boolean,
): LaidOutEntity | null {
  const nearby = entities
    .filter(canInteract)
    .map((entity) => {
      const point = interactionPoint(entity);
      return { entity, distance: Math.hypot(point.x - position.x, point.y - position.y) };
    })
    .filter(({ distance }) => distance <= 1.65)
    .sort((a, b) => a.distance - b.distance);
  return nearby[0]?.entity ?? null;
}
