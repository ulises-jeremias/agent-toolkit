import type { LaidOutEntity } from './types';

export type GroundDecorKind = 'path' | 'tree' | 'creek';

export interface GroundDecor {
  x: number;
  y: number;
  kind: GroundDecorKind;
  /** Visual variant only — never a domain id. */
  variant: 'round' | 'tall' | 'dirt' | 'water';
}

/**
 * Decorative grounds only. Empty cells get trees, the gutter under the
 * landmark boulevard becomes a path, and the east edge gets a creek when
 * it is not already occupied. Nothing here is a semantic entity.
 */
export function groundDecor(entities: readonly LaidOutEntity[], cols: number, rows: number): GroundDecor[] {
  if (cols <= 0 || rows <= 0) return [];
  const occupied = new Set<string>();
  for (const entity of entities) {
    for (let y = entity.y; y < entity.y + entity.h; y += 1) {
      for (let x = entity.x; x < entity.x + entity.w; x += 1) {
        occupied.add(`${x},${y}`);
      }
    }
  }

  const projectYs = entities.filter((entity) => entity.id.startsWith('place:project:')).map((entity) => entity.y);
  const pathY = projectYs.length > 0 ? Math.min(...projectYs) - 1 : -1;
  const decor: GroundDecor[] = [];

  for (let y = 0; y < rows; y += 1) {
    for (let x = 0; x < cols; x += 1) {
      const key = `${x},${y}`;
      if (occupied.has(key)) continue;
      if (y === pathY && pathY >= 0) {
        decor.push({ x, y, kind: 'path', variant: 'dirt' });
        continue;
      }
      if (x === cols - 1 && y % 2 === 0) {
        decor.push({ x, y, kind: 'creek', variant: 'water' });
        continue;
      }
      const n = (x * 7 + y * 3) % 5;
      if (n === 0 || n === 2) {
        decor.push({ x, y, kind: 'tree', variant: n === 0 ? 'round' : 'tall' });
      }
    }
  }

  return decor;
}
