import { describe, expect, it } from 'vitest';
import { terrainAnimationInterval } from './TerrainRenderer';

describe('terrainAnimationInterval', () => {
  it('does not schedule redraws for static terrain', () => {
    expect(terrainAnimationInterval([{ name: 'grass-0', frames: 1 }], true, false)).toBeNull();
  });

  it('uses the real frame cadence of animated terrain', () => {
    expect(
      terrainAnimationInterval(
        [
          { name: 'grass-0', frames: 1 },
          { name: 'water-center', frames: 2 },
        ],
        true,
        false,
      ),
    ).toBe(900);
  });

  it('uses the shortest cadence when animated layers differ', () => {
    expect(
      terrainAnimationInterval(
        [
          { name: 'water-center', frames: 2 },
          { name: 'interior-glow', frames: 2 },
        ],
        true,
        false,
      ),
    ).toBe(800);
  });

  it('stops repainting when animation is disabled or reduced motion is active', () => {
    const water = [{ name: 'water-center', frames: 2 }];
    expect(terrainAnimationInterval(water, false, false)).toBeNull();
    expect(terrainAnimationInterval(water, true, true)).toBeNull();
  });
});
