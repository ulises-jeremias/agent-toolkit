import { useEffect, useMemo, useRef } from 'react';
import { useAppearance } from '../../design/theme';
import type { TerrainCell } from './model/terrain';
import { resolveDecor, resolveInterior, type ThemeAsset, type WorldThemePack } from './theme/types';

/**
 * TerrainCanvas — paints the world's ground layer (terrain cells and
 * animated water) into one canvas. Buffer is in source pixels (16px grid);
 * CSS scales it with nearest-neighbor at the current integer zoom, so pixels
 * stay crisp. DOM layers above carry oversized décor sprites and entities.
 */

interface SpriteInfo {
  image: HTMLImageElement;
  frames: number;
  frameW: number;
}

interface PlannedTile {
  src: string;
  frames: number;
  name: string;
}

const imageCache = new Map<string, Promise<SpriteInfo>>();

function loadSprite(src: string, frames: number): Promise<SpriteInfo> {
  let hit = imageCache.get(src);
  if (!hit) {
    hit = new Promise((resolve, reject) => {
      const image = new Image();
      image.onload = () => resolve({ image, frames, frameW: image.width / frames });
      image.onerror = () => reject(new Error(`sprite failed: ${src}`));
      image.src = src;
    });
    imageCache.set(src, hit);
  }
  return hit;
}

/** Frame step (ms) for 2-frame loops; water drifts slower than glow flicker. */
function frameMs(name: string): number {
  if (name.startsWith('water')) return 900;
  return 800;
}

export function terrainAnimationInterval(
  tiles: Iterable<{ frames: number; name: string }>,
  animate: boolean,
  reducedMotion: boolean,
): number | null {
  if (!animate || reducedMotion) return null;
  let interval: number | null = null;
  for (const tile of tiles) {
    if (tile.frames <= 1) continue;
    const step = frameMs(tile.name);
    interval = interval === null ? step : Math.min(interval, step);
  }
  return interval;
}

function assetFor(theme: WorldThemePack, mode: 'grounds' | 'interior', tile: string): ThemeAsset | undefined {
  return mode === 'interior' ? resolveInterior(theme, tile) : resolveDecor(theme, tile);
}

export interface TerrainCanvasProps {
  theme: WorldThemePack;
  cells: readonly TerrainCell[];
  cols: number;
  rows: number;
  mode: 'grounds' | 'interior';
  animate: boolean;
  /** Display px per source tile (the shared camera zoom). */
  tileSize: number;
}

export function TerrainCanvas({ theme, cells, cols, rows, mode, animate, tileSize }: TerrainCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const { motion } = useAppearance();
  const ts = theme.sourceTile;

  const plan = useMemo(() => {
    const byCell = new Map<string, PlannedTile>();
    for (const cell of cells) {
      const asset = assetFor(theme, mode, cell.tile);
      if (!asset || asset.kind !== 'sprite') continue;
      byCell.set(`${cell.x},${cell.y}`, { src: asset.src, frames: asset.frames ?? 1, name: cell.tile });
    }
    return byCell;
  }, [theme, cells, mode]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.imageSmoothingEnabled = false;

    let alive = true;
    let timer = 0;
    const sprites = new Map<string, SpriteInfo>();
    const sources = new Map<string, number>();
    const sourceCells = new Map<string, { x: number; y: number; tile: PlannedTile }[]>();
    for (const [at, tile] of plan) {
      if (!sources.has(tile.src)) sources.set(tile.src, tile.frames);
      const [xs, ys] = at.split(',');
      const x = Number(xs);
      const y = Number(ys);
      if (!Number.isFinite(x) || !Number.isFinite(y)) continue;
      const cells = sourceCells.get(tile.src) ?? [];
      cells.push({ x, y, tile });
      sourceCells.set(tile.src, cells);
    }
    const interval = terrainAnimationInterval(plan.values(), animate, motion === 'reduced');

    const drawSource = (src: string, sprite: SpriteInfo, now: number) => {
      for (const { x, y, tile } of sourceCells.get(src) ?? []) {
        const frame = animate && tile.frames > 1 ? Math.floor(now / frameMs(tile.name)) % tile.frames : 0;
        ctx.drawImage(
          sprite.image,
          frame * sprite.frameW,
          0,
          sprite.frameW,
          sprite.image.height,
          x * ts,
          y * ts,
          ts,
          ts,
        );
      }
    };

    const draw = (now: number) => {
      if (!alive) return;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      for (const [src, sprite] of sprites) {
        drawSource(src, sprite, now);
      }
      if (interval !== null) {
        timer = window.setTimeout(() => draw(performance.now()), interval);
      }
    };

    ctx.clearRect(0, 0, canvas.width, canvas.height);
    void Promise.all(
      [...sources].map(async ([src, frames]) => {
        try {
          const sprite = await loadSprite(src, frames);
          if (!alive) return;
          sprites.set(src, sprite);
          drawSource(src, sprite, performance.now());
        } catch {
          /* failed sprite — the cell stays empty; fallback remains CSS-side */
        }
      }),
    ).then(() => {
      if (alive && interval !== null) timer = window.setTimeout(() => draw(performance.now()), interval);
    });
    return () => {
      alive = false;
      window.clearTimeout(timer);
    };
  }, [plan, animate, motion, ts, cols, rows]);

  return (
    <canvas
      ref={canvasRef}
      className="worldTerrain"
      width={cols * ts}
      height={rows * ts}
      aria-hidden="true"
      style={{ width: cols * tileSize, height: rows * tileSize }}
    />
  );
}
