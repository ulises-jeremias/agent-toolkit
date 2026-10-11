import { describe, expect, it } from 'vitest';
import { buildWorldModel } from './model/buildWorld';
import { layoutWorld } from './model/layout';
import { paintTerrain } from './model/terrain';
import type { LaidOutEntity } from './model/types';
import {
  findWorldSpawn,
  nearbyWorldTarget,
  restoreWorldPosition,
  stepWorldPlayer,
  worldCellKey,
  type CollisionMap,
  type WorldInput,
} from './player';

const openMap: CollisionMap = { cols: 8, rows: 8, blocked: new Set() };

describe('world player movement', () => {
  it('moves evenly in a direction and normalizes diagonal speed', () => {
    const start = { x: 3.5, y: 3.5 };
    const east = stepWorldPlayer(start, { north: false, south: false, east: true, west: false }, 50, openMap);
    const diagonal = stepWorldPlayer(start, { north: true, south: false, east: true, west: false }, 50, openMap);
    expect(east.x).toBeGreaterThan(start.x);
    expect(east.y).toBe(start.y);
    expect(Math.hypot(diagonal.x - start.x, diagonal.y - start.y)).toBeCloseTo(east.x - start.x);
  });

  it('stops at water and slides along a wall', () => {
    const map = { ...openMap, blocked: new Set([worldCellKey(4, 3)]) };
    const start = { x: 3.5, y: 3.5 };
    const hit = stepWorldPlayer(start, { north: false, south: false, east: true, west: false }, 50, map);
    const slide = stepWorldPlayer(start, { north: false, south: true, east: true, west: false }, 50, map);
    expect(hit.x).toBeLessThan(3.78);
    expect(stepWorldPlayer(hit, { north: false, south: false, east: true, west: false }, 50, map).x).toBe(hit.x);
    expect(slide.x).toBeLessThan(3.78);
    expect(slide.y).toBeGreaterThan(start.y);
  });

  it('keeps the player inside map boundaries and rejects blocked restored coordinates', () => {
    const map = { ...openMap, blocked: new Set([worldCellKey(2, 2)]) };
    const moved = stepWorldPlayer({ x: 0.5, y: 0.5 }, { north: true, south: false, east: false, west: true }, 50, map);
    expect(moved.x).toBeGreaterThanOrEqual(0.22);
    expect(moved.y).toBeGreaterThanOrEqual(0.22);
    expect(restoreWorldPosition('{"x":2.5,"y":2.5}', { x: 1.5, y: 1.5 }, map)).toEqual({ x: 1.5, y: 1.5 });
    expect(restoreWorldPosition('{"x":3.5,"y":3.5}', { x: 1.5, y: 1.5 }, map)).toEqual({ x: 3.5, y: 3.5 });
  });

  it('walks across the generated bridge but cannot walk through the adjacent creek', () => {
    const layout = layoutWorld(
      buildWorldModel({
        workspacePath: '/ws',
        projects: [],
        projectsKnown: true,
        memory: { available: false, entries: [], projectKeys: [] },
        tools: [],
        toolsKnown: false,
        jobs: [],
      }),
    );
    const terrain = paintTerrain(layout.entities, layout.cols, layout.rows);
    const bridge = terrain.decor.find((item) => item.sprite === 'bridge');
    expect(bridge).toBeTruthy();
    if (!bridge) return;
    const bridgeRow = bridge.y + 1;
    const map: CollisionMap = {
      cols: layout.cols,
      rows: layout.rows,
      blocked: new Set(terrain.collisionCells),
    };
    const east: WorldInput = { north: false, south: false, east: true, west: false };
    let crossing = { x: bridge.x - 1.5, y: bridgeRow + 0.5 };
    for (let frame = 0; frame < 40; frame += 1) crossing = stepWorldPlayer(crossing, east, 50, map);
    expect(crossing.x).toBeGreaterThan(bridge.x + 3.5);

    const north: WorldInput = { north: true, south: false, east: false, west: false };
    let creekBank = { x: bridge.x + 1.5, y: bridgeRow + 0.5 };
    for (let frame = 0; frame < 40; frame += 1) creekBank = stepWorldPlayer(creekBank, north, 50, map);
    expect(creekBank.y).toBeGreaterThan(bridgeRow - 0.23);
  });

  it('chooses a nearby walkable spawn and a single nearby canonical target', () => {
    const map = { ...openMap, blocked: new Set([worldCellKey(3, 3), worldCellKey(4, 3)]) };
    expect(findWorldSpawn(map, { x: 3.5, y: 3.5 }, new Set([worldCellKey(2, 3)]))).toEqual({ x: 2.5, y: 3.5 });

    const terminal: LaidOutEntity = {
      id: 'terminal',
      name: 'Terminal',
      kind: 'object',
      concept: 'Real PTY',
      state: 'ready',
      themeKey: 'tool.terminal',
      availability: 'present',
      hrefPath: '/terminal',
      x: 2,
      y: 2,
      w: 2,
      h: 2,
    };
    expect(nearbyWorldTarget({ x: 1.5, y: 2.5 }, [terminal], () => true)).toBe(terminal);
    expect(nearbyWorldTarget({ x: 7.5, y: 7.5 }, [terminal], () => true)).toBeNull();
  });
});
