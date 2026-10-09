import { describe, expect, it } from 'vitest';
import { nearestWorldNeighbor } from './spatialNavigation';

const places = [
  { id: 'current', x: 10, y: 10, w: 2, h: 2, hrefPath: '/world' },
  { id: 'near-right', x: 14, y: 10, w: 2, h: 2, hrefPath: '/library' },
  { id: 'far-right', x: 20, y: 10, w: 2, h: 2, hrefPath: '/terminal' },
  { id: 'near-up', x: 10, y: 6, w: 2, h: 2, hrefPath: '/operations' },
  { id: 'environment', x: 11, y: 12, w: 1, h: 1 },
];

describe('spatial world keyboard navigation', () => {
  it('chooses the nearest inspectable place in the requested direction', () => {
    expect(nearestWorldNeighbor(places, 'current', 'right')).toBe('near-right');
    expect(nearestWorldNeighbor(places, 'current', 'up')).toBe('near-up');
  });

  it('skips non-interactive scenery and returns no target at a world edge', () => {
    expect(nearestWorldNeighbor(places, 'current', 'down')).toBeNull();
    expect(nearestWorldNeighbor(places, 'missing', 'left')).toBeNull();
  });
});
