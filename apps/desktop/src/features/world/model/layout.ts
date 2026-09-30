import type { LaidOutEntity, SemanticEntity, WorldLayout, WorldModel } from './types';

const PLACE_W = 3;
const PLACE_H = 3;
const OBJECT_W = 2;
const OBJECT_H = 2;
const CHAR_W = 1;
const CHAR_H = 1;

function sizeFor(entity: SemanticEntity): { w: number; h: number } {
  if (entity.kind === 'character') return { w: CHAR_W, h: CHAR_H };
  if (entity.kind === 'object' || entity.kind === 'marker') return { w: OBJECT_W, h: OBJECT_H };
  return { w: PLACE_W, h: PLACE_H };
}

/**
 * Deterministic layout from structured entities. Same ids → same slots.
 * Grounds stay at origin; projects fill a stable sorted grid; characters
 * stand on the grounds row after shared objects.
 */
export function layoutWorld(model: WorldModel): WorldLayout {
  const entities = [...model.entities].sort((a, b) => a.id.localeCompare(b.id));
  const laid: LaidOutEntity[] = [];

  const grounds = entities.find((e) => e.id === 'place:workspace');
  const knowledge = entities.find((e) => e.id === 'place:knowledge-workspace');
  const sharedObjects = entities.filter(
    (e) =>
      e.id === 'object:terminal' ||
      e.id === 'object:library' ||
      e.id === 'object:attention' ||
      e.id === 'place:projects-empty',
  );
  const projects = entities.filter((e) => e.id.startsWith('place:project:'));
  const projectExtras = entities.filter(
    (e) => e.id.startsWith('place:knowledge-project:') || e.id.startsWith('object:terminal-project:'),
  );
  const characters = entities.filter((e) => e.kind === 'character');
  const rest = entities.filter(
    (e) =>
      e !== grounds &&
      e !== knowledge &&
      !sharedObjects.includes(e) &&
      !projects.includes(e) &&
      !projectExtras.includes(e) &&
      !characters.includes(e),
  );

  let maxX = 0;
  let maxY = 0;

  const place = (entity: SemanticEntity, x: number, y: number) => {
    const { w, h } = sizeFor(entity);
    laid.push({ ...entity, x, y, w, h });
    maxX = Math.max(maxX, x + w);
    maxY = Math.max(maxY, y + h);
  };

  if (grounds) place(grounds, 0, 0);
  if (knowledge) place(knowledge, PLACE_W + 1, 0);

  let objX = 0;
  const objY = PLACE_H + 1;
  for (const obj of sharedObjects) {
    place(obj, objX, objY);
    objX += OBJECT_W + 1;
  }

  const projectStartY = objY + OBJECT_H + 1;
  const cols = Math.max(1, Math.ceil(Math.sqrt(Math.max(projects.length, 1))));
  projects.forEach((project, index) => {
    const col = index % cols;
    const row = Math.floor(index / cols);
    place(project, col * (PLACE_W + 1), projectStartY + row * (PLACE_H + 1));
  });

  let extraX = 0;
  const extraY = (laid.reduce((m, e) => Math.max(m, e.y + e.h), 0) || projectStartY) + 1;
  for (const extra of projectExtras) {
    place(extra, extraX, extraY);
    extraX += OBJECT_W + 1;
  }

  let charX = 0;
  const charY = Math.max(1, PLACE_H - 1);
  for (const character of characters) {
    place(character, charX + 1, charY);
    charX += CHAR_W + 1;
  }

  for (const entity of rest) {
    place(entity, maxX + 1, 0);
  }

  return {
    cols: Math.max(maxX, 8),
    rows: Math.max(maxY, 8),
    entities: laid,
  };
}
