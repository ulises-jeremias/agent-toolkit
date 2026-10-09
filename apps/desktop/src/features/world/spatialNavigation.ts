import type { LaidOutEntity } from './model/types';

export type WorldDirection = 'up' | 'down' | 'left' | 'right';

/** Find the closest inspectable world place in a direction from the current entity. */
export function nearestWorldNeighbor(
  entities: readonly Pick<LaidOutEntity, 'id' | 'x' | 'y' | 'w' | 'h' | 'hrefPath'>[],
  currentId: string,
  direction: WorldDirection,
): string | null {
  const current = entities.find((entity) => entity.id === currentId);
  if (!current) return null;

  const center = (entity: Pick<LaidOutEntity, 'x' | 'y' | 'w' | 'h'>) => ({
    x: entity.x + entity.w / 2,
    y: entity.y + entity.h / 2,
  });
  const origin = center(current);
  const candidates = entities.flatMap((entity) => {
    if (entity.id === currentId || !entity.hrefPath) return [];
    const target = center(entity);
    const dx = target.x - origin.x;
    const dy = target.y - origin.y;
    const primary = direction === 'left' ? -dx : direction === 'right' ? dx : direction === 'up' ? -dy : dy;
    if (primary <= 0) return [];
    const cross = direction === 'left' || direction === 'right' ? Math.abs(dy) : Math.abs(dx);
    return [{ id: entity.id, score: primary + cross * 1.5, primary, cross }];
  });

  candidates.sort(
    (a, b) => a.score - b.score || a.primary - b.primary || a.cross - b.cross || a.id.localeCompare(b.id),
  );
  return candidates[0]?.id ?? null;
}
