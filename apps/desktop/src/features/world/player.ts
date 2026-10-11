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
