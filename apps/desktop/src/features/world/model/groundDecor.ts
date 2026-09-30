import type { LaidOutEntity } from './types';

export type GroundDecorKind = 'path' | 'tree' | 'creek' | 'bridge';

export interface GroundDecor {
  x: number;
  y: number;
  kind: GroundDecorKind;
  /** Visual variant only — never a domain id. */
  variant: 'round' | 'tall' | 'dirt' | 'water' | 'bridge';
}

function occupiedCells(entities: readonly LaidOutEntity[]): Set<string> {
  const occupied = new Set<string>();
  for (const entity of entities) {
    for (let y = entity.y; y < entity.y + entity.h; y += 1) {
      for (let x = entity.x; x < entity.x + entity.w; x += 1) {
        occupied.add(`${x},${y}`);
      }
    }
  }
  return occupied;
}

function besideBuilding(x: number, y: number, occupied: Set<string>): boolean {
  for (let dy = -1; dy <= 1; dy += 1) {
    for (let dx = -1; dx <= 1; dx += 1) {
      if (dx === 0 && dy === 0) continue;
      if (occupied.has(`${x + dx},${y + dy}`)) return true;
    }
  }
  return false;
}

function isStreet(x: number, y: number, houses: readonly LaidOutEntity[]): boolean {
  const left = houses.some((house) => house.x + house.w === x && y >= house.y && y < house.y + house.h);
  const right = houses.some((house) => house.x === x + 1 && y >= house.y && y < house.y + house.h);
  if (left && right) return true;
  const above = houses.some((house) => house.y + house.h === y && x >= house.x && x < house.x + house.w);
  const below = houses.some((house) => house.y === y + 1 && x >= house.x && x < house.x + house.w);
  return above && below;
}

/**
 * Decorative grounds only. A path runs above the project district and in the
 * gutters between houses. A two-tile creek runs down the east edge, with a
 * bridge where the path crosses it. Trees stand beside buildings. Nothing
 * here is a semantic entity.
 */
export function groundDecor(entities: readonly LaidOutEntity[], cols: number, rows: number): GroundDecor[] {
  if (cols <= 0 || rows <= 0) return [];
  const occupied = occupiedCells(entities);
  const houses = entities.filter((entity) => entity.id.startsWith('place:project:'));
  const projectYs = houses.map((entity) => entity.y);
  const pathY = projectYs.length > 0 ? Math.min(...projectYs) - 1 : -1;
  const decor: GroundDecor[] = [];

  for (let y = 0; y < rows; y += 1) {
    for (let x = 0; x < cols; x += 1) {
      if (occupied.has(`${x},${y}`)) continue;
      const onPath = (y === pathY && pathY >= 0) || isStreet(x, y, houses);
      const onCreek = x >= cols - 2;
      if (onPath && onCreek) {
        decor.push({ x, y, kind: 'bridge', variant: 'bridge' });
        continue;
      }
      if (onPath) {
        decor.push({ x, y, kind: 'path', variant: 'dirt' });
        continue;
      }
      if (onCreek) {
        decor.push({ x, y, kind: 'creek', variant: 'water' });
        continue;
      }
      if (besideBuilding(x, y, occupied) && (x * 3 + y) % 2 === 0) {
        decor.push({ x, y, kind: 'tree', variant: (x + y) % 4 === 0 ? 'tall' : 'round' });
      }
    }
  }

  return decor;
}
