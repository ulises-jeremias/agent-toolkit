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
    const bridge = decor.find((cell) => cell.kind === 'bridge');
    expect(bridge).toMatchObject({ y: house.y - 1, x: layout.cols - 1, variant: 'bridge' });
    const creek = decor.filter((cell) => cell.kind === 'creek');
    expect(creek.length).toBeGreaterThan(0);
    expect(creek.every((cell) => cell.x === layout.cols - 1)).toBe(true);
  });

  it('is deterministic', () => {
    const layout = layoutWorld(buildWorldModel(input(['a', 'b', 'c'])));
    expect(groundDecor(layout.entities, layout.cols, layout.rows)).toEqual(
      groundDecor(layout.entities, layout.cols, layout.rows),
    );
  });
});
