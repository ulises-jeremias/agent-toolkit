/**
 * Shared camera math (Cozy Pixel World). Terrain, art and hit geometry share
 * one camera scale; sprites keep their manifest dimensions. The camera
 * quantizes to whole source pixels at integer zoom — never fractional
 * (ADR-035 craft rules: 16px source tiles, integer multiples).
 */

export const WORLD_ZOOMS = [16, 32, 48, 64, 80] as const;

export interface Point {
  x: number;
  y: number;
}

/** Largest crisp zoom with a 24px gutter, or edge-to-edge when that avoids halving scale. */
export function fitCamera(viewport: Point, tiles: Point, minimumZoom = 16): { zoom: number; pan: Point } {
  const largestFirst = [...WORLD_ZOOMS].reverse();
  const fittingZoom = largestFirst.find(
    (step) => tiles.x * step <= viewport.x - 24 && tiles.y * step <= viewport.y - 24,
  );
  // The world is already full-bleed. When it fits exactly inside the map
  // region, keep crisp pixels at the larger step instead of unexpectedly
  // halving the whole valley to preserve an empty gutter.
  const edgeToEdgeZoom = largestFirst.find((step) => tiles.x * step <= viewport.x && tiles.y * step <= viewport.y);
  const zoom = Math.max(fittingZoom ?? 0, edgeToEdgeZoom ?? WORLD_ZOOMS[0], minimumZoom);
  return {
    zoom,
    pan: {
      x: Math.floor((viewport.x - tiles.x * zoom) / 2),
      y: Math.floor((viewport.y - tiles.y * zoom) / 2),
    },
  };
}

/** Centered when the world fits; otherwise clamped inside the 24px gutter. */
export function clampCamera(pan: Point, viewport: Point, world: Point): Point {
  const axis = (value: number, view: number, size: number) =>
    size <= view ? Math.floor((view - size) / 2) : Math.round(Math.min(24, Math.max(view - size - 24, value)));
  return {
    x: axis(pan.x, viewport.x, world.x),
    y: axis(pan.y, viewport.y, world.y),
  };
}

/** Zoom keeping the viewport center anchored, then clamp. */
export function zoomCamera(pan: Point, oldZoom: number, zoom: number, viewport: Point, tiles: Point): Point {
  const ratio = zoom / oldZoom;
  const cx = viewport.x / 2;
  const cy = viewport.y / 2;
  return clampCamera({ x: cx - (cx - pan.x) * ratio, y: cy - (cy - pan.y) * ratio }, viewport, {
    x: tiles.x * zoom,
    y: tiles.y * zoom,
  });
}
