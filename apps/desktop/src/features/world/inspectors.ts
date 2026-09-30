/**
 * World → inspector activation. Only paths that already exist as destinations;
 * never invent screens. Entities without hrefPath stay non-activating.
 */

import type { SemanticEntity } from './model/types';

export function entityHasInspector(entity: Pick<SemanticEntity, 'hrefPath'>): boolean {
  return typeof entity.hrefPath === 'string' && entity.hrefPath.length > 0;
}

/** Accessible name for map tiles and list rows — name + concept + state (no color). */
export function entityAccessibleName(entity: Pick<SemanticEntity, 'name' | 'concept' | 'state' | 'detail' | 'activity'>): string {
  const parts = [entity.name, entity.concept, entity.state];
  if (entity.detail) parts.push(entity.detail);
  if (entity.activity && entity.activity !== 'calm') parts.push(`activity ${entity.activity}`);
  return parts.join(' · ');
}

export function entityActivateLabel(entity: Pick<SemanticEntity, 'hrefPath' | 'name' | 'concept' | 'state' | 'detail' | 'activity'>): string {
  const base = entityAccessibleName(entity);
  return entityHasInspector(entity) ? `${base}. Activate to inspect.` : `${base}. No inspector for this object.`;
}
