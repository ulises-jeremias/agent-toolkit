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

/**
 * Decorative grounds only. A dirt path runs above the project district, a
 * creek runs down the east edge, and a bridge sits where they cross. Trees
 * stand beside buildings, not in a forest of empty cells. Nothing here is a
 * semantic entity.
 */
export function groundDecor(entities: readonly LaidOutEntity[], cols: number, rows: number): GroundDecor[] {
  if (cols <= 0 || rows <= 0) return [];
  const occupied = occupiedCells(entities);
  const projectYs = entities.filter((entity) => entity.id.startsWith('place:project:')).map((entity) => entity.y);
  const pathY = projectYs.length > 0 ? Math.min(...projectYs) - 1 : -1;
  const creekX = cols - 1;
  const decor: GroundDecor[] = [];

  for (let y = 0; y < rows; y += 1) {
    for (let x = 0; x < cols; x += 1) {
      if (occupied.has(`${x},${y}`)) continue;
      const onPath = y === pathY && pathY >= 0;
      const onCreek = x === creekX;
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
