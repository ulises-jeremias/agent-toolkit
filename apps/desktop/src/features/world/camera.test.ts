import { describe, expect, it } from 'vitest';
import { clampCamera, fitCamera, WORLD_ZOOMS, zoomCamera } from './camera';

describe('WORLD_ZOOMS', () => {
  it('stays integer and starts at one source pixel', () => {
    expect(WORLD_ZOOMS).toEqual([16, 32, 48, 64, 80]);
    for (const step of WORLD_ZOOMS) {
      expect(Number.isInteger(step)).toBe(true);
    }
  });
});

describe('fitCamera', () => {
  it('picks the largest zoom that fits with the 24px gutter', () => {
    // 40x30 tiles: at 32px/tile the world is 1280x960 — fits a 1328x1008 viewport.
    const camera = fitCamera({ x: 1328, y: 1008 }, { x: 40, y: 30 });
    expect(camera.zoom).toBe(32);
    expect(camera.pan).toEqual({ x: 24, y: 24 });
  });

  it('falls back to 16px/tile on a small viewport', () => {
    // 40x30 tiles at 16px/tile = 640x480; viewport 664x504 minus gutter fits.
    const camera = fitCamera({ x: 664, y: 504 }, { x: 40, y: 30 });
    expect(camera.zoom).toBe(16);
  });

  it('keeps a compact valley at 32px when the whole map fits edge-to-edge', () => {
    const camera = fitCamera({ x: 896, y: 416 }, { x: 28, y: 13 });
    expect(camera.zoom).toBe(32);
    expect(camera.pan).toEqual({ x: 0, y: 0 });
  });

  it('centers a world smaller than the viewport', () => {
    // 10x8 tiles at 64px/tile = 640x512, the largest step that fits 776x576.
    const camera = fitCamera({ x: 800, y: 600 }, { x: 10, y: 8 });
    expect(camera.zoom).toBe(64);
    expect(camera.pan.x).toBe(80);
    expect(camera.pan.y).toBe(44);
  });

  it('uses crisp 5x scale when a compact interior fits a large window', () => {
    const camera = fitCamera({ x: 1920, y: 900 }, { x: 14, y: 10 });
    expect(camera.zoom).toBe(80);
    expect(camera.pan).toEqual({ x: 400, y: 50 });
  });

  it('frames a large window at readable integer scale while retaining a strict fit', () => {
    const viewport = { x: 1920, y: 900 };
    const tiles = { x: 30, y: 20 };
    expect(fitCamera(viewport, tiles).zoom).toBe(32);
    expect(fitCamera(viewport, tiles, 48).zoom).toBe(48);
  });
});

describe('clampCamera', () => {
  it('centers when the world fits the viewport', () => {
    const clamped = clampCamera({ x: -500, y: -500 }, { x: 800, y: 600 }, { x: 160, y: 128 });
    expect(clamped).toEqual({ x: 320, y: 236 });
  });

  it('clamps a pannable world inside the 24px gutter on both sides', () => {
    // World 1280x960 in a 800x600 viewport: pan range [-504, 24] x [-384, 24].
    expect(clampCamera({ x: 9999, y: 9999 }, { x: 800, y: 600 }, { x: 1280, y: 960 })).toEqual({ x: 24, y: 24 });
    expect(clampCamera({ x: -9999, y: -9999 }, { x: 800, y: 600 }, { x: 1280, y: 960 })).toEqual({
      x: -504,
      y: -384,
    });
  });
});

describe('zoomCamera', () => {
  it('keeps the viewport center anchored while zooming in', () => {
    // Viewport 800x600, world 640x480 at 16px/tile (centered pan 80,60).
    // Zoom to 32: world becomes 1280x960; the center of the world stays under the viewport center.
    const pan = zoomCamera({ x: 80, y: 60 }, 16, 32, { x: 800, y: 600 }, { x: 40, y: 30 });
    expect(pan).toEqual({ x: -240, y: -180 });
  });

  it('keeps the center anchored while zooming out', () => {
    const pan = zoomCamera({ x: -240, y: -180 }, 32, 16, { x: 800, y: 600 }, { x: 40, y: 30 });
    expect(pan).toEqual({ x: 80, y: 60 });
  });
});
