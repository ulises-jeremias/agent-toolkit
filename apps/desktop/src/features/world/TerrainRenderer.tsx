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
}

export function TerrainCanvas({ theme, cells, cols, rows, mode, animate }: TerrainCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const { motion } = useAppearance();
  const ts = theme.sourceTile;

  const plan = useMemo(() => {
    const byCell = new Map<string, { src: string; frames: number; name: string }>();
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

    const draw = (now: number) => {
      if (!alive) return;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      for (const [at, tile] of plan) {
        const [xs, ys] = at.split(',');
        const x = Number(xs);
        const y = Number(ys);
        if (!Number.isFinite(x) || !Number.isFinite(y)) continue;
        void loadSprite(tile.src, tile.frames)
          .then((sprite) => {
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
          })
          .catch(() => {
            /* failed sprite — the cell stays empty; fallback remains CSS-side */
          });
      }
      if (animate && motion !== 'reduced') {
        timer = window.setTimeout(() => draw(performance.now()), 140);
      }
    };

    draw(performance.now());
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
      style={{ width: cols * theme.tileSize, height: rows * theme.tileSize }}
    />
  );
}
