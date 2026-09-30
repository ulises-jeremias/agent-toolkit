import { describe, expect, it } from 'vitest';
import { buildWorldModel } from './buildWorld';
import { groundDecor } from './groundDecor';
import { layoutWorld } from './layout';
import type { WorldDomainInput } from './types';

function input(projects: string[]): WorldDomainInput {
  return {
    workspacePath: '/ws',
    projects: projects.map((name) => ({ name, target: `/${name}`, status: 'ok' as const })),
    projectsKnown: true,
    memory: { available: false, entries: [], projectKeys: [] },
    tools: [],
    toolsKnown: false,
    jobs: [],
  };
}

describe('groundDecor', () => {
  it('never covers a building or character cell', () => {
    const layout = layoutWorld(buildWorldModel(input(['alpha', 'beta'])));
    const decor = groundDecor(layout.entities, layout.cols, layout.rows);
    const occupied = new Set<string>();
    for (const entity of layout.entities) {
      for (let y = entity.y; y < entity.y + entity.h; y += 1) {
        for (let x = entity.x; x < entity.x + entity.w; x += 1) occupied.add(`${x},${y}`);
      }
    }
    for (const cell of decor) {
      expect(occupied.has(`${cell.x},${cell.y}`)).toBe(false);
    }
  });

  it('places a path gutter above the project district and no characters', () => {
    const layout = layoutWorld(buildWorldModel(input(['alpha'])));
    const house = layout.entities.find((entity) => entity.id === 'place:project:alpha')!;
    const decor = groundDecor(layout.entities, layout.cols, layout.rows);
    expect(decor.some((cell) => cell.kind === 'path' && cell.y === house.y - 1)).toBe(true);
    const bridges = decor.filter((cell) => cell.kind === 'bridge' && cell.y === house.y - 1);
    expect(bridges.map((cell) => cell.x).sort()).toEqual([layout.cols - 2, layout.cols - 1]);
    const creek = decor.filter((cell) => cell.kind === 'creek');
    expect(creek.length).toBeGreaterThan(0);
    expect(creek.every((cell) => cell.x >= layout.cols - 2)).toBe(true);
  });

  it('lays a street in the gutter between neighboring houses', () => {
    const layout = layoutWorld(buildWorldModel(input(['alpha', 'beta'])));
    const alpha = layout.entities.find((entity) => entity.id === 'place:project:alpha')!;
    const beta = layout.entities.find((entity) => entity.id === 'place:project:beta')!;
    const decor = groundDecor(layout.entities, layout.cols, layout.rows);
    const gutterX = Math.min(alpha.x, beta.x) + alpha.w;
    expect(gutterX).toBeLessThan(Math.max(alpha.x, beta.x));
    expect(decor.some((cell) => cell.kind === 'path' && cell.x === gutterX && cell.y === alpha.y)).toBe(true);
  });

  it('is deterministic', () => {
    const layout = layoutWorld(buildWorldModel(input(['a', 'b', 'c'])));
    expect(groundDecor(layout.entities, layout.cols, layout.rows)).toEqual(
      groundDecor(layout.entities, layout.cols, layout.rows),
    );
  });
});
