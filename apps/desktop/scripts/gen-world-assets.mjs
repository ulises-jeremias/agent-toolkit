#!/usr/bin/env node
/**
 * gen-world-assets.mjs — Cozy Pixel World asset generator (ADR-035).
 *
 * Generates the original pixel-art PNG set in ../public/world/ from the
 * palette + sprite definitions below. Everything here is original art
 * authored as code: no third-party assets, no tracing, no copied sprites.
 *
 * Craft rules (docs/desktop/DESIGN.md §7): 16px source tile grid, integer
 * multiples, one light direction (top-left), 1px darker silhouette outline,
 * limited ramps, hard pixel shadows (no blur), 2-frame animation strips
 * packed horizontally (frame width = tile width).
 *
 * Usage: node scripts/gen-world-assets.mjs [--check]
 *   --check  verify committed PNGs match a fresh generation (CI gate)
 */

import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.resolve(here, '..', 'public', 'world');

/* ------------------------------------------------------------------ *
 * 1. Minimal PNG encoder (8-bit RGBA, no filters) — zero dependencies.
 * ------------------------------------------------------------------ */

const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const out = Buffer.alloc(8 + data.length + 4);
  out.writeUInt32BE(data.length, 0);
  out.write(type, 4, 'ascii');
  data.copy(out, 8);
  out.writeUInt32BE(crc32(out.subarray(4, 8 + data.length)), 8 + data.length);
  return out;
}

function encodePng(width, height, rgba) {
  const sig = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  ihdr[10] = 0; // compression
  ihdr[11] = 0; // filter
  ihdr[12] = 0; // interlace
  const stride = width * 4;
  const raw = Buffer.alloc((stride + 1) * height);
  const src = Buffer.isBuffer(rgba) ? rgba : Buffer.from(rgba.buffer, rgba.byteOffset, rgba.byteLength);
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0;
    src.copy(raw, y * (stride + 1) + 1, y * stride, (y + 1) * stride);
  }
  return Buffer.concat([
    sig,
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

/* ------------------------------------------------------------------ *
 * 2. Pixel image helper. Cells hold palette keys; '.' is transparent.
 * ------------------------------------------------------------------ */

class Img {
  constructor(w, h) {
    this.w = w;
    this.h = h;
    this.g = Array.from({ length: h }, () => new Array(w).fill('.'));
  }
  ok(x, y) {
    return x >= 0 && y >= 0 && x < this.w && y < this.h;
  }
  set(x, y, k) {
    if (this.ok(x, y)) this.g[y][x] = k;
    return this;
  }
  get(x, y) {
    return this.ok(x, y) ? this.g[y][x] : '.';
  }
  rect(x0, y0, x1, y1, k) {
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) this.set(x, y, k);
    return this;
  }
  hline(x0, x1, y, k) {
    for (let x = x0; x <= x1; x++) this.set(x, y, k);
    return this;
  }
  vline(x, y0, y1, k) {
    for (let y = y0; y <= y1; y++) this.set(x, y, k);
    return this;
  }
  /** Filled trapezoid (roof slopes): rows y0..y1, half-width lerped. */
  trapezoid(cx, y0, y1, half0, half1, k, edgeK) {
    for (let y = y0; y <= y1; y++) {
      const t = (y - y0) / Math.max(1, y1 - y0);
      const half = Math.round(half0 + (half1 - half0) * t);
      this.hline(cx - half, cx + half, y, k);
      if (edgeK) this.set(cx + half, y, edgeK); // south-east light edge
    }
    return this;
  }
  /** Filled ellipse-ish blob (canopies, domes). */
  ellipse(cx, cy, rx, ry, k) {
    for (let y = -ry; y <= ry; y++) {
      const w = Math.round(rx * Math.sqrt(Math.max(0, 1 - (y * y) / (ry * ry))));
      this.hline(cx - w, cx + w, cy + y, k);
    }
    return this;
  }
  outlineRect(x0, y0, x1, y1, k) {
    this.hline(x0, x1, y0, k).hline(x0, x1, y1, k).vline(x0, y0, y1, k).vline(x1, y0, y1, k);
    return this;
  }
  toRgba(palette) {
    const out = Buffer.alloc(this.w * this.h * 4);
    for (let y = 0; y < this.h; y++) {
      for (let x = 0; x < this.w; x++) {
        const c = palette[this.g[y][x]] || [0, 0, 0, 0];
        const i = (y * this.w + x) * 4;
        out[i] = c[0];
        out[i + 1] = c[1];
        out[i + 2] = c[2];
        out[i + 3] = c.length > 3 ? c[3] : 255;
      }
    }
    return out;
  }
}

/** Hand-authored ASCII sprite → Img. */
function art(rows) {
  const h = rows.length;
  const w = Math.max(...rows.map((r) => r.length));
  const img = new Img(w, h);
  rows.forEach((row, y) => {
    for (let x = 0; x < row.length; x++) if (row[x] !== '.') img.set(x, y, row[x]);
  });
  return img;
}

/* ------------------------------------------------------------------ *
 * 3. Palette (docs/desktop/DESIGN.md §5 anchors; keys, not hex, below).
 * ------------------------------------------------------------------ */

const P = {
  k: [0x26, 0x20, 0x33],
  iv: [0xf3, 0xed, 0xda],
  // Fern, olive and spring-light form a softer valley base. This keeps
  // landmarks vivid without letting the lawn compete with their silhouettes.
  g: [0x68, 0xa8, 0x5f],
  gd: [0x4f, 0x8b, 0x4b],
  gl: [0x83, 0xbd, 0x70],
  gt: [0xb2, 0xd3, 0x87],
  fo: [0x48, 0x72, 0x3e],
  fd: [0x37, 0x5d, 0x36],
  fl: [0x65, 0x91, 0x4b],
  d: [0xb7, 0x91, 0x63],
  dd: [0x96, 0x73, 0x4d],
  dl: [0xd0, 0xb0, 0x7b],
  sa: [0xe7, 0xd7, 0xa8],
  sad: [0xcd, 0xb8, 0x86],
  st: [0x9a, 0xa0, 0xa8],
  sd: [0x76, 0x7c, 0x85],
  sl: [0xc6, 0xcb, 0xcf],
  paver: [0xc5, 0xa7, 0x78],
  paverDark: [0x91, 0x73, 0x50],
  paverLight: [0xe0, 0xca, 0x9d],
  w: [0x3f, 0xa7, 0xd6],
  wd: [0x2e, 0x7f, 0xa3],
  wl: [0x7c, 0xd0, 0xec],
  wf: [0xe3, 0xf6, 0xfc],
  o: [0x8a, 0x5a, 0x32],
  ol: [0xb0, 0x7b, 0x4a],
  od: [0x5e, 0x3d, 0x22],
  p: [0xf2, 0xe6, 0xc9],
  pd: [0xdc, 0xc9, 0xa4],
  bk: [0xb5, 0x65, 0x4a],
  bkd: [0x8f, 0x4a, 0x38],
  rt: [0xc6, 0x5d, 0x3b],
  rtd: [0xa0, 0x4a, 0x2e],
  rtl: [0xde, 0x7a, 0x52],
  rs: [0x4e, 0x6e, 0x8e],
  rsd: [0x3c, 0x5a, 0x75],
  rsl: [0x67, 0x89, 0xab],
  re: [0x3e, 0x8e, 0x8a],
  red: [0x2f, 0x6e, 0x6b],
  rel: [0x55, 0xa8, 0xa4],
  rr: [0xa6, 0x3d, 0x2f],
  rrd: [0x7e, 0x2e, 0x21],
  rrl: [0xc0, 0x52, 0x3f],
  rm: [0x5e, 0x8c, 0x4a],
  rmd: [0x47, 0x6b, 0x37],
  rw: [0xd9, 0xa6, 0x48],
  rwd: [0xb3, 0x85, 0x3b],
  cy: [0x5f, 0xe3, 0xd0],
  cyd: [0x3f, 0xb5, 0xa6],
  gg: [0xff, 0xd9, 0x7a],
  go: [0xf0, 0xbd, 0x5e],
  god: [0xc9, 0x9a, 0x3f],
  lv: [0xb7, 0xa6, 0xf0],
  em: [0x4e, 0xd4, 0x9a],
  wy: [0xff, 0xe9, 0xa3],
  err: [0xe4, 0x57, 0x4c],
  pop: [0xe4, 0x57, 0x4c],
  hb: [0xc1, 0x7f, 0x4a],
  hbd: [0x9c, 0x63, 0x36],
  hbl: [0xf2, 0xe0, 0xc0],
  sk: [0xe8, 0xb8, 0x8a],
  skd: [0xc9, 0x90, 0x6b],
  ink: [0x3a, 0x32, 0x47],
  inkd: [0x22, 0x1e, 0x30],
  sh: [0x26, 0x20, 0x33, 0x55],
};

/* ------------------------------------------------------------------ *
 * 4. Building kit — shared parts keep one art direction.
 * ------------------------------------------------------------------ */

/** Contact shadow: hard offset pixels south + east. */
function shadow(img, x0, x1, y) {
  img.hline(x0, x1, y, 'sh').hline(x0 + 2, x1, y + 1, 'sh');
  return img;
}

/** Gable roof: apex at (cx, ry0), eaves at ry1, half-width topHalf→botHalf. */
function gableRoof(img, cx, ry0, ry1, topHalf, botHalf, k, kd, kl) {
  img.trapezoid(cx, ry0, ry1, topHalf, botHalf, k, 'k');
  img.trapezoid(cx, ry0 + 1, ry1 - 1, Math.max(1, topHalf - 1), botHalf - 1, k, null);
  // Short staggered courses give a roof texture at both overview and close zoom.
  // The gaps are deterministic and stay inside the roof silhouette.
  for (let y = ry0 + 4; y < ry1 - 2; y += 4) {
    const t = (y - ry0) / Math.max(1, ry1 - ry0);
    const half = Math.round(topHalf + (botHalf - topHalf) * t) - 3;
    for (let x = cx - half + ((y / 4) % 2) * 3; x < cx + half - 1; x += 7) {
      img.hline(x, Math.min(x + 3, cx + half), y, kd);
      img.set(x + 1, y - 1, kl);
    }
  }
  img.hline(cx - topHalf, cx + topHalf, ry0, kl); // sunlit ridge
  const eaveHalf = botHalf;
  img.hline(cx - eaveHalf, cx + eaveHalf, ry1, kd); // dark eave course
  img.hline(cx - eaveHalf + 1, cx + eaveHalf, ry1 + 1, 'sh'); // eave shadow on wall
  return img;
}

/** Flat parapet roof with a glowing skylight. */
function flatRoof(img, x0, x1, y, k, kd, skylight) {
  img.rect(x0, y, x1, y + 3, k);
  img.hline(x0, x1, y, k.replace('d', 'l'));
  img.hline(x0, x1, y + 3, kd);
  if (skylight) {
    const mx = Math.floor(x2c(x0, x1));
    img.rect(mx - 4, y + 1, mx + 2, y + 2, 'k').rect(mx - 3, y + 1, mx + 1, y + 2, 'cy');
  }
  return img;
}
const x2c = (a, b) => (a + b) / 2;

/** Steep point roof (tower). */
function pointRoof(img, cx, ry0, ry1, botHalf, k, kd) {
  img.trapezoid(cx, ry0, ry1, 1, botHalf, k, kd);
  img.hline(cx - botHalf, cx + botHalf, ry1, kd);
  img.set(cx, ry0 - 2, 'od').set(cx, ry0 - 1, 'go');
  return img;
}

/** Rounded dome roof (archive). */
function domeRoof(img, cx, baseY, r, k, kd, kl) {
  for (let dy = -r; dy <= 0; dy++) {
    const w = Math.round(Math.sqrt(Math.max(0, r * r - dy * dy)));
    img.hline(cx - w, cx + w, baseY + dy, k);
    img.set(cx + w, baseY + dy, kd);
  }
  img.hline(cx - r + 2, cx - r + 6, baseY - r + 3, kl); // sun streak
  img.set(cx, baseY - r - 2, 'od').set(cx, baseY - r - 1, 'go'); // finial
  img.hline(cx - r, cx + r, baseY, kd);
  return img;
}

/** Glowing window with timber frame + sill. */
function win(img, x, y, w = 6, h = 7, arch = false) {
  img.rect(x - 1, y - 1, x + w, y + h, 'k');
  img.rect(x, y, x + w - 1, y + h - 1, 'k');
  img.rect(x + 1, y + 1, x + w - 2, y + h - 2, 'wy');
  img.rect(x + 1, y + h - 3, x + w - 2, y + h - 2, 'go'); // warm sill glow
  const mx = Math.floor(x + w / 2);
  const my = Math.floor(y + h / 2);
  img.vline(mx, y + 1, y + h - 2, 'od').hline(x + 1, x + w - 2, my, 'od');
  img.set(x + 1, y + 1, 'iv'); // sun catch
  if (arch) {
    img.set(x, y, 'k').set(x + w - 1, y, 'k');
    img.set(x + 1, y, 'wy').set(x + w - 2, y, 'wy');
  }
  img.hline(x - 1, x + w, y + h + 1, 'ol'); // sill
  return img;
}

/** Door with outline, panels, knob, stone step. */
function door(img, x, y, w, h, wide = false) {
  img.rect(x - 1, y - 1, x + w, y + h, 'k');
  img.rect(x, y, x + w - 1, y + h - 1, 'od');
  img.rect(x + 1, y + 1, x + w - 2, y + h - 2, 'o');
  if (wide) img.vline(Math.floor(x + w / 2) - 0, y + 1, y + h - 2, 'od');
  img.hline(x + 1, x + w - 2, y + 1, 'ol');
  img.set(x + w - 3, Math.floor(y + h / 2), 'gg');
  img.hline(x - 1, x + w, y + h, 'st').hline(x - 1, x + w, y + h + 1, 'sd'); // step
  return img;
}

/** Wall body: plaster with timber beams, wood planks, brick, stone, or ink. */
function wall(img, x0, y0, x1, y1, material) {
  const [base, dark] =
    material === 'plaster'
      ? ['p', 'pd']
      : material === 'wood'
        ? ['o', 'od']
        : material === 'brick'
          ? ['bk', 'bkd']
          : material === 'ink'
            ? ['ink', 'inkd']
            : ['st', 'sd'];
  img.rect(x0, y0, x1, y1, base);
  img.outlineRect(x0, y0, x1, y1, 'k');
  if (material === 'plaster') {
    for (let x = x0 + 7; x < x1 - 3; x += 8) img.vline(x, y0 + 1, y1 - 1, dark);
    img.hline(x0 + 1, x1 - 1, Math.floor((y0 + y1) / 2), dark);
  } else if (material === 'wood') {
    for (let y = y0 + 3; y < y1; y += 4) img.hline(x0 + 1, x1 - 1, y, dark);
  } else if (material === 'brick') {
    for (let y = y0 + 2; y < y1 - 1; y += 3) {
      img.hline(x0 + 1, x1 - 1, y, dark);
      const off = ((y - y0) / 3) % 2 ? 3 : 6;
      for (let x = x0 + off; x < x1 - 1; x += 7) img.set(x, y - 1, dark);
    }
  } else if (material === 'stone') {
    for (let y = y0 + 3; y < y1 - 1; y += 5) img.hline(x0 + 1, x1 - 1, y, dark);
    img.set(x0 + 4, y0 + 2, 'sl').set(x1 - 5, y0 + 4, 'sl');
  } else if (material === 'ink') {
    img.hline(x0 + 1, x1 - 1, y0 + 1, 'inkd');
  }
  img.hline(x0, x1, y1, 'k');
  img.hline(x0 + 1, x1 - 1, y1 - 2, dark).hline(x0 + 1, x1 - 1, y1 - 1, dark); // base course
  return img;
}

function chimney(img, x, y) {
  img.rect(x, y, x + 3, y + 7, 'k').rect(x + 1, y, x + 2, y + 6, 'bk');
  img.hline(x - 1, x + 4, y, 'sd');
  img
    .set(x + 1, y - 2, 'sl')
    .set(x + 2, y - 3, 'sl')
    .set(x + 1, y - 4, 'sd'); // smoke wisps
  return img;
}

/** Small hanging sign on a post. kind: gear|book|scroll|note|bell */
function sign(img, x, y, kind) {
  img.rect(x + 1, y + 6, x + 2, y + 13, 'k').vline(x + 2, y + 7, y + 13, 'o');
  if (kind === 'gear') {
    img.rect(x - 2, y, x + 5, y + 5, 'k').rect(x - 1, y + 1, x + 4, y + 4, 'go');
    img.set(x + 1, y - 1, 'k').set(x + 2, y - 1, 'go');
    img.set(x + 1, y + 6, 'go');
    img.set(x - 3, y + 2, 'go').set(x + 6, y + 2, 'go');
    img.set(x + 1, y + 2, 'k').set(x + 2, y + 2, 'k');
  } else if (kind === 'book') {
    img.rect(x - 2, y, x + 6, y + 5, 'k').rect(x - 1, y + 1, x + 5, y + 4, 'iv');
    img
      .vline(x + 2, y + 1, y + 4, 'rr')
      .set(x, y + 2, 'pd')
      .set(x + 4, y + 2, 'pd');
  } else if (kind === 'scroll') {
    img.rect(x - 1, y, x + 4, y + 5, 'k').rect(x, y + 1, x + 3, y + 4, 'iv');
    img
      .set(x, y, 'od')
      .set(x + 3, y, 'od')
      .set(x + 1, y + 2, 'rr')
      .set(x + 2, y + 2, 'rr');
  } else if (kind === 'note') {
    img.rect(x - 1, y, x + 4, y + 4, 'k').rect(x, y + 1, x + 3, y + 3, 'iv');
    img.set(x + 1, y + 1, 'ink').set(x + 1, y + 2, 'ink');
  } else if (kind === 'bell') {
    img
      .rect(x, y, x + 3, y + 3, 'k')
      .rect(x + 1, y, x + 2, y + 2, 'go')
      .set(x + 1, y + 3, 'god');
    img
      .set(x + 5, y + 1, 'err')
      .set(x + 5, y, 'err')
      .set(x + 6, y, 'rr');
  }
  return img;
}

/** Pennant banner on a pole (workspace hall). */
function banner(img, x, y) {
  img.vline(x, y, y + 12, 'k').vline(x + 1, y, y + 12, 'od');
  img
    .set(x + 2, y, 'gg')
    .set(x + 3, y, 'gg')
    .set(x + 4, y, 'god');
  img.set(x + 2, y + 1, 'gg').set(x + 3, y + 1, 'god');
  img.set(x + 2, y + 2, 'god');
  return img;
}

/** Clay nest under the eave (Hornero signature, on the hall). */
function nest(img, x, y) {
  img.rect(x, y, x + 4, y + 3, 'hbd').rect(x + 1, y, x + 3, y + 1, 'hb');
  img.set(x + 2, y + 2, 'k');
  return img;
}

/* ------------------------------------------------------------------ *
 * 5. Houses + landmarks. Canvas sizes are multiples of the 16px tile.
 *    Buildings sit on the bottom row: door faces south.
 * ------------------------------------------------------------------ */

function house(spec) {
  const w = 48;
  const h = 48;
  const img = new Img(w, h);
  const x0 = 8;
  const x1 = 39;
  const roofBottom = 23;
  shadow(img, x0 - 3, x1 + 6, h - 4);
  wall(img, x0, roofBottom, x1, h - 5, spec.wall);
  if (spec.roof === 'gable') {
    gableRoof(img, 24, 6, roofBottom, 4, 21, spec.roofKey, spec.roofDark, spec.roofLite);
    img.hline(24 - 21, 24 + 21, roofBottom, 'k');
  } else if (spec.roof === 'flat') {
    flatRoof(img, x0 - 2, x1 + 2, roofBottom - 4, spec.roofKey, spec.roofDark, spec.skylight);
    img.hline(x0 - 2, x1 + 2, roofBottom, spec.roofDark);
  } else if (spec.roof === 'point') {
    gableRoof(img, 24, 20, roofBottom, 12, 21, spec.roofKey, spec.roofDark, spec.roofLite);
    img.hline(24 - 21, 24 + 21, roofBottom, 'k');
    pointRoof(img, 24, 4, 20, 11, spec.roofKey, spec.roofDark);
  }
  if (spec.chimney) chimney(img, spec.chimney === 'left' ? 11 : 33, 6);
  door(img, spec.doorX ?? 20, 33, spec.doorW ?? 8, 9, spec.doorW === 12);
  if (spec.windows !== 0) {
    const wy = 27;
    if (spec.windows === 2) {
      win(img, 12, wy);
      win(img, 30, wy);
    } else if (spec.windows === 'left') win(img, 12, wy, 6, 7);
    else if (spec.windows === 'right') win(img, 30, wy, 6, 7);
    else if (spec.windows === 'band') win(img, 12, wy - 1, 14, 8);
  }
  if (spec.gearSign) sign(img, 40, 30, 'gear');
  if (spec.flowerBox) {
    img.rect(11, 36, 18, 38, 'od').rect(12, 36, 17, 37, 'o');
    img.set(12, 34, 'fo').set(15, 34, 'fo').set(17, 35, 'fo');
    img.set(13, 34, 'pop').set(16, 34, 'gg');
  }
  if (spec.logs) {
    for (let y = 24; y < 42; y += 4) {
      img.set(x0 + 1, y, 'ol').set(x1 - 1, y, 'ol');
    }
  }
  return [{ name: spec.name, img }];
}

const HOUSES = [
  {
    name: 'house-cottage',
    wall: 'plaster',
    roof: 'gable',
    roofKey: 'rt',
    roofDark: 'rtd',
    roofLite: 'rtl',
    windows: 2,
    chimney: 'right',
    flowerBox: true,
  },
  {
    name: 'house-studio',
    wall: 'plaster',
    roof: 'flat',
    roofKey: 'rs',
    roofDark: 'rsd',
    skylight: true,
    windows: 'band',
    doorX: 30,
  },
  {
    name: 'house-workshop',
    wall: 'wood',
    roof: 'gable',
    roofKey: 'rr',
    roofDark: 'rrd',
    roofLite: 'rrl',
    windows: 0,
    doorX: 18,
    doorW: 12,
    gearSign: true,
  },
  {
    name: 'house-tower',
    wall: 'stone',
    roof: 'point',
    roofKey: 're',
    roofDark: 'red',
    roofLite: 'rel',
    windows: 'left',
    doorX: 21,
  },
  {
    name: 'house-cabin',
    wall: 'wood',
    roof: 'gable',
    roofKey: 'rm',
    roofDark: 'rmd',
    roofLite: 'rm',
    windows: 'left',
    chimney: 'left',
    logs: true,
    doorX: 24,
  },
  {
    name: 'house-brick',
    wall: 'brick',
    roof: 'gable',
    roofKey: 'rs',
    roofDark: 'rsd',
    roofLite: 'rsl',
    windows: 2,
    doorX: 20,
  },
];

function landmarkWorkspace() {
  const img = new Img(80, 64);
  shadow(img, 6, 74, 60);
  wall(img, 12, 28, 67, 59, 'plaster');
  gableRoof(img, 40, 8, 29, 8, 32, 'rt', 'rtd', 'rtl');
  chimney(img, 60, 6);
  door(img, 34, 46, 12, 13, true);
  win(img, 17, 34, 7, 8);
  win(img, 31, 34, 7, 8);
  win(img, 45, 34, 7, 8);
  win(img, 59, 34, 7, 8);
  win(img, 36, 36, 8, 8, true); // arched over door
  banner(img, 26, 14);
  nest(img, 54, 24);
  sign(img, 6, 44, 'note'); // notice side-post
  return [{ name: 'landmark-workspace', img }];
}

function landmarkArchive() {
  const img = new Img(64, 64);
  shadow(img, 8, 58, 60);
  wall(img, 12, 26, 51, 59, 'stone');
  domeRoof(img, 32, 26, 17, 're', 'red', 'rel');
  win(img, 27, 38, 10, 14, true); // tall arched glowing window
  door(img, 16, 48, 8, 11);
  sign(img, 50, 42, 'scroll');
  return [{ name: 'landmark-archive', img }];
}

function landmarkLibrary() {
  const img = new Img(64, 64);
  shadow(img, 6, 60, 60);
  wall(img, 10, 24, 53, 59, 'plaster');
  gableRoof(img, 32, 8, 25, 5, 25, 're', 'red', 'rel');
  chimney(img, 48, 6);
  door(img, 28, 47, 9, 12);
  win(img, 15, 32, 8, 12, true);
  win(img, 41, 32, 8, 12, true);
  win(img, 28, 30, 9, 8); // reading room glow
  sign(img, 54, 44, 'book');
  return [{ name: 'landmark-library', img }];
}

function landmarkOperations() {
  const img = new Img(64, 64);
  shadow(img, 6, 60, 60);
  wall(img, 10, 26, 53, 59, 'wood');
  gableRoof(img, 32, 12, 27, 5, 25, 'rr', 'rrd', 'rrl');
  door(img, 26, 44, 12, 15, true);
  // awning over the door
  img.rect(24, 40, 40, 42, 'k').rect(25, 40, 39, 41, 'go').hline(25, 39, 42, 'god');
  win(img, 14, 34, 6, 7);
  win(img, 44, 34, 6, 7);
  sign(img, 52, 32, 'gear');
  chimney(img, 16, 10);
  return [{ name: 'landmark-operations', img }];
}

function landmarkTerminal() {
  const img = new Img(64, 64);
  shadow(img, 6, 60, 60);
  wall(img, 10, 26, 53, 59, 'ink');
  flatRoof(img, 8, 55, 22, 'rsd', 'inkd');
  img.hline(8, 55, 22, 'rs').hline(8, 55, 26, 'inkd');
  // antenna with cyan tip
  img.vline(46, 8, 21, 'k').vline(47, 8, 21, 'sd');
  img.set(46, 6, 'cy').set(47, 6, 'cy').set(46, 7, 'cyd').set(47, 5, 'cy');
  img.set(42, 12, 'sd').set(50, 12, 'sd'); // dish hint
  // big glowing console window
  img.rect(15, 33, 48, 50, 'k').rect(16, 34, 47, 49, 'inkd');
  img.rect(18, 36, 33, 47, 'wd').rect(19, 37, 32, 46, 'wa');
  img.rect(20, 38, 27, 41, 'wl');
  img.hline(20, 24, 44, 'cy').set(30, 44, 'cy');
  door(img, 42, 46, 8, 13);
  return [{ name: 'landmark-terminal', img }];
}

function landmarkFiles() {
  const img = new Img(48, 48);
  shadow(img, 6, 44, 44);
  wall(img, 10, 20, 39, 43, 'wood');
  gableRoof(img, 25, 8, 21, 4, 19, 'rw', 'rwd', 'rw');
  // open front with crates
  img.rect(14, 30, 35, 43, 'k').rect(15, 31, 34, 42, 'inkd');
  img.rect(17, 34, 23, 40, 'o').outlineRect(17, 34, 23, 40, 'od');
  img.hline(17, 23, 37, 'od');
  img.rect(26, 32, 32, 38, 'ol').outlineRect(26, 32, 32, 38, 'od');
  img.rect(26, 40, 30, 42, 'o').outlineRect(26, 40, 30, 42, 'od');
  return [{ name: 'landmark-files', img }];
}

function landmarkSettings() {
  const img = new Img(48, 48);
  shadow(img, 10, 40, 44);
  // small pavilion: two posts + mini slate roof + hanging gear
  img.rect(13, 22, 16, 43, 'k').rect(14, 23, 15, 42, 'st');
  img.rect(33, 22, 36, 43, 'k').rect(34, 23, 35, 42, 'st');
  gableRoof(img, 24, 12, 23, 3, 14, 'rs', 'rsd', 'rsl');
  img.vline(24, 24, 27, 'k');
  img.rect(20, 28, 28, 34, 'k').rect(21, 29, 27, 33, 'go');
  img.set(24, 30, 'k').set(24, 27, 'go').set(20, 31, 'go').set(28, 31, 'go');
  img.set(22, 31, 'god').set(26, 31, 'god'); // gear spokes hint
  img.rect(20, 38, 28, 42, 'od').rect(21, 39, 27, 41, 'o'); // base crate
  return [{ name: 'landmark-settings', img }];
}

function landmarkAttention() {
  const img = new Img(48, 48);
  shadow(img, 10, 40, 44);
  img.rect(13, 20, 16, 43, 'k').rect(14, 21, 15, 42, 'o');
  img.rect(33, 20, 36, 43, 'k').rect(34, 21, 35, 42, 'o');
  img.rect(12, 16, 37, 27, 'k').rect(13, 17, 36, 26, 'iv');
  img.hline(15, 24, 19, 'ink').hline(15, 28, 22, 'ink');
  img.rect(30, 19, 34, 23, 'err'); // red flag note
  img.vline(40, 8, 20, 'k');
  img.rect(41, 9, 46, 13, 'rr').set(42, 10, 'rrl'); // flag
  img.set(41, 14, 'rrd');
  return [{ name: 'landmark-attention', img }];
}

/* ---- semantic objects (2x2 or 1x2 tiles) ---- */

function objCatalog() {
  // memory.index — card catalog cabinet
  const img = new Img(32, 32);
  shadow(img, 4, 28, 29);
  img.rect(4, 8, 27, 28, 'k').rect(5, 9, 26, 27, 'o');
  for (let r = 0; r < 3; r++)
    for (let c = 0; c < 3; c++) {
      img.rect(7 + c * 7, 11 + r * 6, 11 + c * 7, 15 + r * 6, 'od');
      img.rect(8 + c * 7, 12 + r * 6, 10 + c * 7, 14 + r * 6, 'ol');
      img.set(9 + c * 7, 13 + r * 6, 'go');
    }
  img.hline(4, 27, 8, 'ol');
  return [{ name: 'memory-index', img }];
}

function objProjectShelf() {
  // knowledge.project — small book shelf
  const img = new Img(32, 32);
  shadow(img, 5, 27, 29);
  img.rect(5, 6, 26, 28, 'k').rect(6, 7, 25, 27, 'od');
  const cols = ['rt', 're', 'rs', 'rm', 'lv', 'go'];
  for (let sh = 0; sh < 2; sh++) {
    const y = 9 + sh * 9;
    img.hline(7, 24, y + 6, 'ol');
    for (let i = 0; i < 6; i++) img.rect(8 + i * 3, y + (i % 2), 9 + i * 3, y + 5, cols[(i + sh * 2) % 6]);
  }
  return [{ name: 'knowledge-shelf', img }];
}

function objMemoryEntry() {
  // memory.entry — scroll on a low post
  const img = new Img(16, 24);
  img.rect(6, 12, 9, 21, 'k').rect(7, 13, 8, 20, 'o');
  img.rect(3, 3, 12, 11, 'k').rect(4, 4, 11, 10, 'iv');
  img.rect(4, 3, 11, 4, 'pd');
  img.rect(6, 6, 9, 7, 'rr');
  img.hline(5, 6, 22, 'sh').hline(7, 10, 22, 'sh');
  return [{ name: 'memory-entry', img }];
}

function objToolRack() {
  // tool.coding — wall rack with hammer + wrench
  const img = new Img(32, 32);
  shadow(img, 4, 28, 29);
  img.rect(5, 8, 26, 28, 'k').rect(6, 9, 25, 27, 'o');
  img.hline(6, 25, 12, 'ol').hline(6, 25, 22, 'ol');
  // hammer
  img.rect(10, 14, 14, 16, 'k').rect(11, 14, 13, 15, 'sd').vline(12, 16, 24, 'od');
  // wrench
  img.vline(19, 14, 24, 'k').vline(20, 14, 24, 'sd');
  img.rect(18, 13, 21, 15, 'k').set(19, 14, 'sd');
  img.set(15, 26, 'go').set(16, 26, 'god'); // screw bits
  return [{ name: 'tool-rack', img }];
}

function objTerminalDesk() {
  // tool.terminal (grounds object): small CRT on a desk
  const img = new Img(32, 32);
  shadow(img, 4, 28, 29);
  img.rect(5, 20, 26, 25, 'k').rect(6, 21, 25, 24, 'ol');
  img.rect(7, 25, 9, 28, 'od').rect(22, 25, 24, 28, 'od'); // legs
  img.rect(10, 8, 22, 20, 'k').rect(11, 9, 21, 19, 'sd'); // shell
  img.rect(12, 10, 20, 17, 'wd').rect(13, 11, 19, 14, 'cy'); // screen glow
  img.set(14, 15, 'w').set(15, 15, 'wf');
  img.rect(13, 21, 19, 22, 'inkd'); // keyboard slab
  return [{ name: 'tool-terminal-desk', img }];
}

function objAgentPlate() {
  // agent.catalog — desk nameplate post (never a character)
  const img = new Img(16, 16);
  img.rect(6, 6, 9, 13, 'k').rect(7, 7, 8, 12, 'o');
  img.rect(3, 2, 12, 7, 'k').rect(4, 3, 11, 6, 'pd');
  img.hline(5, 7, 4, 'go').hline(5, 9, 5, 'k');
  img.hline(4, 11, 13, 'sh');
  return [{ name: 'agent-plate', img }];
}

function objSwarmTable() {
  // swarm.table — round meeting table with stools
  const img = new Img(32, 32);
  img.ellipse(16, 16, 4, 3, 'sh');
  img.ellipse(16, 15, 9, 7, 'k');
  img.ellipse(16, 15, 8, 6, 'o');
  img.ellipse(16, 14, 6, 4, 'ol');
  img.set(14, 13, 'iv').set(18, 15, 'gg');
  for (const [x, y] of [
    [4, 24],
    [26, 24],
    [4, 7],
    [26, 7],
  ]) {
    img.rect(x, y, x + 3, y + 3, 'k').rect(x + 1, y, x + 2, y + 2, 'o');
  }
  return [{ name: 'swarm-table', img }];
}

function objLoopClock() {
  // loop.clock — clock post
  const img = new Img(16, 24);
  img.rect(6, 10, 9, 21, 'k').rect(7, 11, 8, 20, 'o');
  img.ellipse(7, 5, 5, 4, 'k');
  img.ellipse(7, 5, 4, 3, 'iv');
  img.set(7, 3, 'k').set(7, 5, 'k').set(9, 5, 'rr');
  img.set(5, 2, 'k').set(9, 2, 'k').set(4, 5, 'k').set(10, 5, 'k');
  img.hline(5, 10, 21, 'sh');
  return [{ name: 'loop-clock', img }];
}

function objCrate() {
  // ops.crate — delivery crate stack
  const img = new Img(32, 32);
  shadow(img, 4, 28, 29);
  img.rect(4, 12, 18, 26, 'k').rect(5, 13, 17, 25, 'ol');
  img.hline(5, 17, 19, 'od').set(11, 13, 'od').set(11, 25, 'od');
  img.rect(19, 6, 29, 18, 'k').rect(20, 7, 28, 17, 'o');
  img.hline(20, 28, 12, 'od').set(24, 7, 'ol').set(24, 17, 'ol');
  img.rect(19, 20, 26, 26, 'k').rect(20, 21, 25, 25, 'ol');
  return [{ name: 'ops-crate', img }];
}

function objInbox() {
  // attention.inbox — mailbox with red flag up
  const img = new Img(32, 32);
  shadow(img, 8, 24, 29);
  img.rect(13, 16, 16, 28, 'k').rect(14, 17, 15, 27, 'o');
  img.rect(7, 6, 24, 16, 'k');
  img.rect(8, 7, 23, 15, 'st').rect(9, 8, 22, 12, 'sl');
  img.hline(9, 22, 15, 'sd');
  img.rect(20, 2, 22, 9, 'k').rect(20, 3, 23, 6, 'err').set(21, 2, 'rrl');
  return [{ name: 'attention-inbox', img }];
}

function objLamp() {
  // ops.lamp / decor lamp — post with warm glow head (2 frames: flicker)
  const f0 = new Img(16, 24);
  const draw = (img, glow) => {
    img.rect(6, 8, 9, 21, 'k').rect(7, 9, 8, 20, 'od');
    img.rect(6, 8, 9, 8, 'ol');
    img.rect(4, 2, 11, 8, 'k').rect(5, 3, 10, 7, glow);
    img.rect(6, 1, 9, 2, 'k');
    img.hline(5, 10, 21, 'sh');
    if (glow === 'gg') {
      img.set(5, 3, 'iv').set(10, 6, 'go');
    } else {
      img.set(6, 3, 'iv');
    }
  };
  draw(f0, 'gg');
  const f1 = new Img(16, 24);
  draw(f1, 'go');
  return [{ name: 'lamp', img: f0, frames: [f0, f1] }];
}

/* ------------------------------------------------------------------ *
 * 6. Terrain tiles (16x16). Layout composes; edges feathered in code.
 * ------------------------------------------------------------------ */

function grassTile(seed) {
  const img = new Img(16, 16).rect(0, 0, 15, 15, 'g');
  // Small hand-authored clover and blade clusters make the broad valley feel
  // grassy at normal zoom. Their varied spacing avoids a repeating stripe
  // pattern while preserving enough calm ground around semantic buildings.
  const s = seed * 19 + 7;
  const patches = [
    [[1, 2, 'gl'], [2, 2, 'gl'], [2, 3, 'fl'], [3, 3, 'gd']],
    [[7, 1, 'gd'], [8, 2, 'fl'], [9, 2, 'gl'], [8, 3, 'gl']],
    [[12, 4, 'gl'], [13, 4, 'fl'], [13, 5, 'gd']],
    [[3, 8, 'gd'], [4, 8, 'fl'], [5, 9, 'gl'], [4, 10, 'gl']],
    [[10, 10, 'gd'], [11, 9, 'fl'], [12, 9, 'gl'], [12, 10, 'gl']],
    [[7, 13, 'gl'], [8, 12, 'fl'], [9, 12, 'gd'], [9, 13, 'gl']],
  ];
  const rotation = s % patches.length;
  for (let i = 0; i < patches.length; i++) {
    // Each tile gets three or four clusters in a different order; the fixed
    // motifs keep pixels crisp and readable instead of relying on noise.
    if ((i + seed) % 2 === 0 || (i + rotation) % 3 === 0) {
      for (const [x, y, color] of patches[(i + rotation) % patches.length]) img.set(x, y, color);
    }
  }
  const glintX = ((s * 7) % 13) + 1;
  const glintY = ((s * 11) % 13) + 1;
  img.set(glintX, glintY, 'gt');
  return img;
}

function flowerTile(kind) {
  const img = grassTile(kind * 3 + 1);
  const heads = { poppy: 'pop', daisy: 'iv', lavender: 'lv', gold: 'go' };
  const spots = [
    [3, 11],
    [8, 5],
    [12, 12],
    [6, 8],
  ];
  const kc = heads[['poppy', 'daisy', 'lavender', 'gold'][kind % 4]];
  spots.forEach(([x, y], i) => {
    img.set(x, y + 1, 'fo');
    img.set(x, y, i % 2 ? kc : heads[(kind + 1) % 4]);
  });
  return img;
}

function dirtTiles() {
  const out = [];
  const base = () => {
    const img = new Img(16, 16).rect(0, 0, 15, 15, 'd');
    // Warm, compact grit with irregular pebble pairs and faint foot-worn marks.
    img.set(3, 4, 'dl').set(4, 4, 'dl').set(10, 9, 'dl').set(6, 13, 'dd');
    img.set(13, 3, 'dd').set(1, 9, 'dl').set(12, 13, 'dd').set(8, 2, 'dl');
    img.set(5, 8, 'dd').set(6, 8, 'dd').set(11, 5, 'dl');
    return img;
  };
  out.push({ name: 'dirt', img: base() });
  const pathNames = [
    'dot',
    'end-n',
    'end-s',
    'v',
    'end-w',
    'turn-nw',
    'turn-sw',
    'tee-e',
    'end-e',
    'turn-ne',
    'turn-se',
    'tee-w',
    'h',
    'tee-s',
    'tee-n',
    'cross',
  ];
  pathNames.forEach((name, mask) => {
    const img = new Img(16, 16);
    const body = Array.from({ length: 16 }, () => new Array(16).fill(false));
    const fill = (x0, y0, x1, y1) => {
      for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) body[y][x] = true;
    };
    fill(5, 5, 10, 10);
    if (mask & 1) fill(5, 0, 10, 7);
    if (mask & 2) fill(5, 8, 10, 15);
    if (mask & 4) fill(0, 5, 7, 10);
    if (mask & 8) fill(8, 5, 15, 10);
    const neighborIsPath = (x, y, dx, dy) => {
      const nx = x + dx;
      const ny = y + dy;
      if (nx >= 0 && ny >= 0 && nx < 16 && ny < 16) return body[ny][nx];
      if (nx < 0) return Boolean(mask & 4) && y >= 5 && y <= 10;
      if (nx >= 16) return Boolean(mask & 8) && y >= 5 && y <= 10;
      if (ny < 0) return Boolean(mask & 1) && x >= 5 && x <= 10;
      return Boolean(mask & 2) && x >= 5 && x <= 10;
    };
    for (let y = 0; y < 16; y++) {
      for (let x = 0; x < 16; x++) {
        if (!body[y][x]) continue;
        const edge = [
          [0, -1],
          [0, 1],
          [-1, 0],
          [1, 0],
        ].some(([dx, dy]) => !neighborIsPath(x, y, dx, dy));
        img.set(x, y, edge ? 'dd' : 'd');
      }
    }
    img.set(6, 6, 'dl').set(9, 9, 'dd');
    out.push({ name: `trail-${name}`, img });
  });
  const edge = (dir) => {
    const img = base();
    for (let i = 0; i < 16; i += 2) {
      if (dir === 'n') img.set(i, 0, 'g').set(i + 1, 0, 'gd');
      if (dir === 's') img.set(i, 15, 'g').set(i + 1, 15, 'gd');
      if (dir === 'w') img.set(0, i, 'g').set(0, i + 1, 'gd');
      if (dir === 'e') img.set(15, i, 'g').set(15, i + 1, 'gd');
    }
    return img;
  };
  for (const d of ['n', 's', 'e', 'w']) out.push({ name: `dirt-${d}`, img: edge(d) });
  const corner = (a, b) => {
    const img = base();
    // quarter grass block with a 1px tuft edge
    const gx = b === 'w' ? 0 : 11;
    const gy = a === 'n' ? 0 : 11;
    img.rect(gx, gy, gx + 4, gy + 4, 'g');
    img.set(gx + 4, gy + 4, 'g').set(b === 'w' ? gx + 5 : gx - 1, a === 'n' ? gy + 5 : gy - 1, 'gd');
    img.set(gx + 2, gy + 2, 'gd').set(gx + 1, gy + 3, 'gt');
    return img;
  };
  for (const [a, b] of [
    ['n', 'w'],
    ['n', 'e'],
    ['s', 'w'],
    ['s', 'e'],
  ])
    out.push({ name: `dirt-${a}${b}`, img: corner(a, b) });
  return out;
}

function plazaTiles() {
  const slab = (alt) => {
    const img = new Img(16, 16).rect(0, 0, 15, 15, alt ? 'paverLight' : 'paver');
    img.hline(0, 15, 0, 'paverDark').hline(0, 15, 8, 'paverDark');
    img.vline(0, 0, 15, 'paverDark').vline(15, 0, 15, 'paverDark');
    const offset = alt ? 8 : 0;
    img.vline(7 + (offset % 4), 1, 7, 'paverDark').vline(7 + ((offset + 4) % 8), 9, 15, 'paverDark');
    img.hline(2, 5, 3, 'paverLight').hline(10, 13, 12, 'paver');
    return img;
  };
  return [
    { name: 'plaza', img: slab(false) },
    { name: 'plaza-b', img: slab(true) },
  ];
}

function waterTiles() {
  const mk = (off) => {
    const img = new Img(16, 16).rect(0, 0, 15, 15, 'w');
    const y = ((3 + off) % 11) + 2;
    const x = ((2 + off * 2) % 11) + 2;
    img.hline(x, Math.min(x + 3, 14), y, 'wl').set(x + 1, y - 1, 'wf');
    img.hline(((10 + off) % 12) + 1, ((13 + off) % 13) + 2, ((9 + off) % 12) + 2, 'wd');
    img.set(((6 + off) % 14) + 1, ((12 + off) % 13) + 1, 'wl');
    return img;
  };
  const shore = (dir) => {
    const img = mk(1);
    if (dir === 'n') img.hline(0, 15, 0, 'wf').hline(0, 15, 1, 'wl');
    if (dir === 's') img.hline(0, 15, 15, 'wf').hline(0, 15, 14, 'wl');
    if (dir === 'w') img.vline(0, 0, 15, 'wf').vline(1, 0, 15, 'wl');
    if (dir === 'e') img.vline(15, 0, 15, 'wf').vline(14, 0, 15, 'wl');
    return img;
  };
  return [
    { name: 'water', img: mk(0), frames: [mk(0), mk(3)] },
    { name: 'water-edge-n', img: shore('n') },
    { name: 'water-edge-s', img: shore('s') },
    { name: 'water-edge-e', img: shore('e') },
    { name: 'water-edge-w', img: shore('w') },
  ];
}

function bridge() {
  const img = new Img(48, 48);
  // horizontal deck crossing a vertical creek: planks run north-south
  img.rect(2, 20, 45, 27, 'od'); // base
  for (let x = 3; x < 45; x += 5) img.rect(x, 20, x + 3, 27, 'ol');
  img.hline(2, 45, 20, 'k').hline(2, 45, 27, 'k');
  for (const y of [16, 31]) {
    img.hline(0, 47, y + 3, 'k');
    img
      .rect(0, y, 4, y + 2, 'od')
      .rect(20, y, 24, y + 2, 'od')
      .rect(43, y, 47, y + 2, 'od');
    img.set(1, y, 'ol').set(21, y, 'ol').set(44, y, 'ol');
  }
  img.hline(2, 45, 28, 'sh'); // deck shadow on water
  return [{ name: 'bridge', img }];
}

/* ------------------------------------------------------------------ *
 * 7. Nature decor.
 * ------------------------------------------------------------------ */

function leafyCanopy(img, flowers = false, amber = false) {
  // Layered crown masses make a broad, hand-clustered canopy rather than a
  // single perfect ball. Top-left highlights follow the same light direction.
  for (const [cx, cy, rx, ry] of [
    [16, 15, 14, 12],
    [8, 17, 8, 8],
    [23, 16, 8, 9],
    [13, 8, 8, 7],
  ]) {
    img.ellipse(cx, cy, rx, ry, 'k');
  }
  for (const [cx, cy, rx, ry] of [
    [16, 14, 13, 11],
    [8, 16, 7, 7],
    [23, 15, 7, 8],
    [13, 8, 7, 6],
  ]) {
    img.ellipse(cx, cy, rx, ry, 'fo');
  }
  img.ellipse(9, 12, 5, 5, amber ? 'go' : flowers ? 'fl' : 'fl');
  img.ellipse(16, 7, 6, 4, amber ? 'gt' : 'gl');
  img.ellipse(24, 13, 4, 6, 'fd');
  img.ellipse(14, 19, 6, 4, 'fd');
  img.hline(6, 9, 9, 'gt').hline(15, 19, 5, 'gt').hline(10, 12, 17, 'fo');
  img.set(22, 17, 'gl').set(20, 21, 'fl').set(7, 15, 'gt').set(25, 10, 'fl');
  if (flowers) {
    for (const [x, y] of [
      [8, 14],
      [19, 8],
      [24, 18],
      [13, 20],
      [20, 14],
    ])
      img.set(x, y, 'pop');
    img.set(9, 13, 'iv').set(20, 7, 'iv').set(25, 17, 'iv');
  } else if (amber) {
    img.set(7, 17, 'go').set(17, 10, 'gt').set(23, 20, 'go').set(11, 22, 'god');
  }
}

function treeRound() {
  const img = new Img(32, 40);
  img.ellipse(16, 38, 10, 2, 'sh');
  img.rect(13, 24, 18, 37, 'k').rect(14, 24, 17, 36, 'od');
  img.set(14, 28, 'o').set(17, 31, 'o').set(15, 34, 'o');
  leafyCanopy(img);
  return [{ name: 'tree-round', img }];
}

function treeBlossom() {
  const img = new Img(32, 40);
  img.ellipse(16, 38, 10, 2, 'sh');
  img.rect(13, 24, 18, 37, 'k').rect(14, 24, 17, 36, 'od');
  img.set(14, 28, 'o').set(17, 31, 'o').set(15, 34, 'o');
  leafyCanopy(img, true);
  return [{ name: 'tree-blossom', img }];
}

function treeAmber() {
  const img = new Img(32, 40);
  img.ellipse(16, 38, 10, 2, 'sh');
  img.rect(13, 24, 18, 37, 'k').rect(14, 24, 17, 36, 'od');
  img.set(14, 28, 'o').set(17, 31, 'o').set(15, 34, 'o');
  leafyCanopy(img, false, true);
  return [{ name: 'tree-amber', img }];
}

function treePine() {
  const img = new Img(32, 40);
  img.ellipse(16, 38, 9, 2, 'sh');
  img.rect(13, 26, 18, 37, 'k').rect(14, 26, 17, 36, 'od');
  // Three overlapping bough tiers read as a fir rather than one triangle.
  img.trapezoid(16, 15, 34, 4, 14, 'k');
  img.trapezoid(16, 16, 32, 3, 12, 'fd');
  img.trapezoid(16, 8, 25, 3, 11, 'fo');
  img.trapezoid(16, 1, 17, 1, 8, 'fl');
  img.hline(8, 12, 24, 'fl').hline(10, 13, 31, 'fo');
  img.set(16, 0, 'gt').set(12, 10, 'gt').set(20, 16, 'fl').set(22, 22, 'fd');
  return [{ name: 'tree-pine', img }];
}

function treeWillow() {
  const img = new Img(32, 40);
  img.ellipse(16, 38, 11, 2, 'sh');
  // A low, spreading canopy and visible branch curtains mark the creek bank.
  img.rect(14, 22, 17, 37, 'k').rect(15, 22, 16, 36, 'od');
  img.vline(9, 16, 31, 'od').vline(23, 14, 30, 'od');
  for (const [cx, cy, rx, ry, tone] of [
    [16, 12, 14, 9, 'k'],
    [8, 15, 8, 7, 'k'],
    [24, 15, 8, 8, 'k'],
    [16, 12, 13, 8, 'fo'],
    [8, 15, 7, 6, 'fl'],
    [24, 15, 7, 7, 'fd'],
    [16, 7, 7, 5, 'gl'],
  ])
    img.ellipse(cx, cy, rx, ry, tone);
  for (const [x, end] of [
    [6, 29],
    [10, 33],
    [21, 32],
    [26, 28],
  ]) {
    img.vline(x, 18, end, 'fo');
    img.set(x - 1, end, 'fl').set(x + 1, end - 2, 'gd');
  }
  img.set(9, 10, 'gt').set(12, 8, 'gt').set(17, 6, 'gt').set(23, 10, 'gl');
  img.set(7, 14, 'fl').set(12, 13, 'gl').set(20, 12, 'fl').set(25, 16, 'fo');
  return [{ name: 'tree-willow', img }];
}

function bush() {
  const img = new Img(16, 12);
  img.ellipse(8, 7, 7, 4, 'k');
  img.ellipse(8, 6, 6, 4, 'fo');
  img.set(5, 4, 'fl').set(9, 3, 'fl').set(11, 6, 'fd');
  return [{ name: 'bush', img }];
}

function rock() {
  const img = new Img(16, 12);
  img.ellipse(8, 8, 6, 3, 'k');
  img.rect(3, 4, 12, 8, 'sd');
  img.rect(4, 3, 10, 5, 'st');
  img.set(5, 3, 'sl').set(6, 4, 'sl');
  return [{ name: 'rock', img }];
}

function tallGrass() {
  const img = art([
    '..g..gl..g....',
    '..gl..g..gl.g.',
    '.g..g.gl..g...',
    'gl..gt...g.gl.',
    '.g..g...gl..g.',
    'g...gl..g...g.',
  ]);
  const wide = new Img(16, 8);
  for (let y = 0; y < img.h; y++)
    for (let x = 0; x < img.w; x++) if (img.get(x, y) !== '.') wide.set(x, y + 2, img.get(x, y));
  return [{ name: 'tall-grass', img: wide }];
}

function mushroom() {
  const img = new Img(16, 12);
  img.rect(7, 6, 8, 10, 'k').rect(7, 6, 8, 9, 'iv');
  img.ellipse(8, 5, 5, 3, 'k');
  img.ellipse(8, 4, 4, 3, 'pop');
  img.set(6, 3, 'iv').set(10, 4, 'iv').set(8, 2, 'iv');
  return [{ name: 'mushroom', img }];
}

function reeds() {
  const img = new Img(16, 16);
  img.rect(0, 12, 15, 15, 'wd');
  const xs = [3, 6, 9, 12];
  xs.forEach((x, i) => {
    const h = 7 + ((i * 3) % 4);
    img.vline(x, 15 - h, 13, i % 2 ? 'fo' : 'fl');
    img.set(x + 1, 15 - h, 'od').set(x, 14 - h, 'hb');
  });
  return [{ name: 'reeds', img }];
}

function lily() {
  const img = new Img(16, 16);
  img.ellipse(8, 12, 6, 2, 'sh');
  // Floating pad with a cut notch, bead-like highlights and a small bloom.
  img.ellipse(8, 10, 6, 3, 'fd');
  img.ellipse(8, 9, 5, 2, 'fl');
  img.set(8, 9, 'w').set(8, 8, 'w');
  img.set(4, 8, 'gl').set(6, 7, 'gt').set(11, 9, 'gl');
  img.set(8, 3, 'fo').set(8, 4, 'fo').set(8, 5, 'fo');
  img.set(6, 4, 'iv').set(7, 3, 'iv').set(9, 3, 'iv').set(10, 4, 'iv');
  img.set(7, 5, 'pop').set(8, 4, 'go').set(9, 5, 'pop');
  return [{ name: 'lily', img }];
}

function stump() {
  const img = new Img(16, 12);
  img.rect(4, 4, 11, 9, 'k').rect(5, 5, 10, 8, 'o');
  img.rect(4, 2, 11, 4, 'k').rect(5, 3, 10, 3, 'ol');
  img.set(7, 3, 'o').set(8, 3, 'od');
  return [{ name: 'stump', img }];
}

function fence() {
  const hImg = new Img(16, 12);
  hImg.rect(0, 3, 15, 4, 'od').rect(0, 7, 15, 8, 'od');
  hImg.rect(1, 0, 3, 10, 'k').rect(1, 1, 2, 9, 'o');
  hImg.rect(12, 0, 14, 10, 'k').rect(12, 1, 13, 9, 'o');
  hImg.set(1, 0, 'ol').set(12, 0, 'ol');
  const vImg = new Img(12, 16);
  vImg.rect(3, 0, 4, 15, 'od').rect(7, 0, 8, 15, 'od');
  vImg.rect(0, 1, 10, 3, 'k').rect(1, 1, 9, 2, 'o');
  vImg.rect(0, 12, 10, 14, 'k').rect(1, 12, 9, 13, 'o');
  return [
    { name: 'fence-h', img: hImg },
    { name: 'fence-v', img: vImg },
  ];
}

function signPost() {
  const img = new Img(16, 16);
  img.rect(7, 6, 8, 13, 'k').rect(7, 7, 8, 12, 'o');
  img.rect(3, 1, 13, 7, 'k').rect(4, 2, 12, 6, 'ol');
  img.hline(5, 8, 3, 'od').hline(6, 10, 5, 'od');
  img.hline(5, 10, 14, 'sh');
  return [{ name: 'sign', img }];
}

/* ------------------------------------------------------------------ *
 * 8. Interior room pieces.
 * ------------------------------------------------------------------ */

function floorPlank() {
  const a = new Img(16, 16);
  a.rect(0, 0, 15, 15, 'ol');
  for (let y = 3; y < 16; y += 4) a.hline(0, 15, y, 'o');
  a.set(4, 1, 'o').set(12, 9, 'o').set(8, 13, 'o');
  a.hline(0, 15, 15, 'od');
  const b = new Img(16, 16);
  b.rect(0, 0, 15, 15, 'o');
  for (let y = 3; y < 16; y += 4) b.hline(0, 15, y, 'od');
  b.set(6, 5, 'ol').set(12, 1, 'ol');
  b.hline(0, 15, 15, 'od');
  return [
    { name: 'floor-wood', img: a },
    { name: 'floor-wood-b', img: b },
  ];
}

function wallBand() {
  const img = new Img(16, 16);
  img.rect(0, 0, 15, 3, 'od');
  img.rect(0, 4, 15, 15, 'p');
  img.hline(0, 15, 4, 'ol').hline(0, 15, 12, 'pd');
  img.set(3, 7, 'pd').set(11, 9, 'pd');
  return [{ name: 'wall-top', img }];
}

function doorExit() {
  const img = new Img(16, 24);
  img.rect(2, 0, 13, 21, 'k').rect(3, 1, 12, 20, 'od');
  img.rect(4, 2, 11, 19, 'inkd').rect(5, 3, 10, 18, 'ink');
  img.set(5, 18, 'd').set(6, 18, 'dl'); // light from doorway
  img.rect(3, 22, 12, 23, 'sd'); // threshold
  return [{ name: 'door-exit', img }];
}

function rug() {
  const img = new Img(32, 16);
  img.rect(0, 0, 31, 15, 'k');
  img.rect(1, 1, 30, 14, 'rt');
  img.rect(3, 3, 28, 12, 'p');
  img.rect(5, 5, 26, 10, 're');
  for (let x = 7; x < 26; x += 4) img.set(x, 6, 'go').set(x + 1, 9, 'go');
  for (let x = 2; x < 30; x += 3) {
    img.set(x, 0, 'gg');
    img.set(x + 1, 15, 'gg');
  }
  return [{ name: 'rug', img }];
}

function plantPot() {
  const img = new Img(16, 16);
  img.rect(5, 9, 10, 13, 'k').rect(6, 10, 9, 12, 'rt');
  img.hline(5, 10, 9, 'rtd');
  img.vline(7, 4, 8, 'fo').vline(8, 3, 8, 'fl');
  img.set(6, 3, 'fo').set(9, 4, 'fo').set(8, 2, 'gt');
  return [{ name: 'plant', img }];
}

function deskTerminal() {
  const img = new Img(32, 32);
  shadow(img, 3, 28, 29);
  img.rect(3, 18, 28, 23, 'k').rect(4, 19, 27, 22, 'ol');
  img.rect(5, 23, 7, 28, 'od').rect(24, 23, 26, 28, 'od');
  img.rect(9, 6, 23, 18, 'k').rect(10, 7, 22, 17, 'inkd');
  img.rect(11, 8, 21, 15, 'wd');
  img.rect(12, 9, 17, 11, 'cy').set(18, 10, 'wl');
  img.hline(12, 20, 13, 'cyd').set(19, 14, 'cy');
  img.rect(12, 19, 20, 21, 'k').rect(13, 19, 19, 20, 'st');
  img.set(24, 17, 'gg'); // mug
  return [{ name: 'desk-terminal', img }];
}

function deskFiles() {
  const img = new Img(32, 32);
  shadow(img, 3, 29, 30);
  img.rect(4, 3, 27, 29, 'k').rect(5, 4, 26, 28, 'ol');
  img.rect(7, 6, 24, 12, 'od').rect(8, 7, 23, 11, 'rt');
  img.rect(7, 13, 24, 19, 'od').rect(8, 14, 23, 18, 'ol');
  img.rect(7, 20, 24, 26, 'od').rect(8, 21, 23, 25, 'rt');
  for (const y of [8, 15, 22]) {
    img.rect(13, y, 18, y + 1, 'k').rect(14, y, 17, y, 'gg');
  }
  img.set(6, 5, 'gg').set(25, 27, 'od');
  return [{ name: 'desk-files', img }];
}

function shelfBooks() {
  const img = new Img(32, 32);
  shadow(img, 2, 29, 30);
  img.rect(2, 2, 29, 29, 'k').rect(3, 3, 28, 28, 'od');
  const cols = ['rt', 're', 'rs', 'rm', 'lv', 'go', 'pop', 'cyd'];
  for (let sh = 0; sh < 3; sh++) {
    const y = 5 + sh * 8;
    img.hline(4, 27, y + 6, 'ol');
    for (let i = 0; i < 7; i++) {
      const x = 4 + i * 3;
      if ((i + sh) % 5 === 4) continue; // gap
      img.rect(x, y + (i % 2), x + 2, y + 5, cols[(i + sh * 3) % 8]);
    }
    if (sh === 1) img.rect(23, y + 3, 26, y + 5, 'iv'); // lying book
  }
  img.hline(2, 29, 2, 'ol');
  return [{ name: 'shelf-books', img }];
}

function cabinetMemory() {
  const img = new Img(32, 32);
  shadow(img, 4, 28, 30);
  img.rect(5, 4, 26, 29, 'k').rect(6, 5, 25, 28, 'st');
  for (let r = 0; r < 4; r++) {
    img.rect(7, 7 + r * 6, 24, 11 + r * 6, 'sd').rect(8, 8 + r * 6, 23, 10 + r * 6, 'sl');
    img.rect(13, 8 + r * 6, 18, 9 + r * 6, 'go');
  }
  img.hline(5, 26, 4, 'sl');
  return [{ name: 'cabinet-memory', img }];
}

function benchTools() {
  const img = new Img(32, 32);
  shadow(img, 2, 29, 29);
  img.rect(2, 14, 29, 19, 'k').rect(3, 15, 28, 18, 'ol');
  img.rect(4, 19, 7, 28, 'od').rect(24, 19, 27, 28, 'od');
  img.rect(6, 11, 12, 13, 'k').rect(7, 11, 11, 12, 'sd').vline(9, 13, 15, 'od'); // hammer
  img.rect(17, 10, 19, 14, 'k').vline(18, 11, 15, 'sd'); // wrench
  img.set(21, 12, 'iv').set(22, 12, 'iv').set(23, 13, 'iv'); // saw hint
  img.set(13, 16, 'go').set(20, 16, 'iv');
  img.rect(10, 7, 15, 10, 'k').rect(11, 8, 14, 9, 'cy'); // small glowing part
  return [{ name: 'bench-tools', img }];
}

function boardMap() {
  const img = new Img(32, 32);
  shadow(img, 3, 28, 29);
  img.rect(10, 24, 12, 27, 'od').rect(19, 24, 21, 27, 'od');
  img.rect(3, 3, 28, 24, 'k').rect(4, 4, 27, 23, 'od');
  img.rect(5, 5, 26, 22, 'g');
  img.set(8, 9, 'd').set(9, 10, 'd').set(10, 11, 'd').set(11, 12, 'd').set(12, 13, 'd');
  img.set(20, 8, 'w').set(21, 9, 'w').set(22, 10, 'w');
  img.set(9, 15, 'rt').set(18, 16, 're').set(14, 8, 'rs');
  img.set(23, 17, 'go');
  return [{ name: 'board-map', img }];
}

function projectOverviewBoard() {
  const img = new Img(48, 48);
  shadow(img, 3, 43, 44);
  img.rect(4, 3, 43, 39, 'k').rect(5, 4, 42, 38, 'ol').rect(7, 6, 40, 36, 'od');
  img.rect(8, 8, 39, 34, 'sa');
  img.rect(10, 10, 28, 30, 'g').rect(11, 11, 27, 29, 'gl');
  img.hline(13, 24, 14, 'fo').hline(13, 24, 17, 'fo').vline(18, 14, 17, 'fo');
  img.set(14, 24, 'rt').set(15, 23, 'rt').set(16, 22, 'rt');
  img.set(23, 13, 'w').set(24, 14, 'w').set(25, 15, 'w');
  img.set(13, 20, 'rr').set(24, 25, 'rw').set(15, 27, 're');
  img.rect(30, 10, 36, 30, 'iv');
  img.hline(31, 35, 13, 'rt').hline(31, 34, 16, 'sd');
  img.hline(31, 35, 20, 're').hline(31, 34, 23, 'sd');
  img.hline(31, 35, 27, 'rw').hline(31, 34, 30, 'sd');
  img.set(8, 7, 'gg').set(39, 7, 'gg').set(8, 35, 'gg').set(39, 35, 'gg');
  img.rect(17, 40, 30, 42, 'od').rect(19, 40, 28, 41, 'ol');
  return [{ name: 'project-board', img }];
}

function crate() {
  const img = new Img(16, 16);
  img.rect(2, 3, 13, 14, 'k').rect(3, 4, 12, 13, 'ol');
  img.hline(3, 12, 8, 'od').set(3, 4, 'od').set(12, 4, 'od').set(3, 13, 'od').set(12, 13, 'od');
  img.set(6, 6, 'o').set(9, 10, 'o');
  return [{ name: 'crate', img }];
}

/* ------------------------------------------------------------------ *
 * 9. Characters — apprentice figures for PROVEN runtime rows only.
 *    16x24 source, 2-frame working bob. Palette variant per stable hash.
 * ------------------------------------------------------------------ */

function character(robe, robeDark, accent, hair = 'od', skin = 'sk') {
  const base = (bob) => {
    const img = new Img(16, 24);
    const by = bob ? -1 : 0;
    // Distinct hair, skin and coat make a durable Person recognizable.
    img.rect(6, 2 + by, 9, 3 + by, 'k').rect(5, 4 + by, 10, 6 + by, 'k');
    img
      .rect(6, 2 + by, 9, 4 + by, hair)
      .set(5, 5 + by, hair)
      .set(10, 5 + by, hair);
    img.rect(6, 5 + by, 9, 9 + by, 'k').rect(6, 5 + by, 9, 8 + by, skin);
    img.set(7, 7 + by, 'k').set(9, 7 + by, 'k');
    img.set(6, 9 + by, 'skd').set(9, 9 + by, 'skd');
    img.set(8, 9 + by, 'iv');
    // robe body
    img.rect(4, 11 + by, 11, 19, 'k');
    img.rect(5, 11 + by, 10, 18, robe);
    img.hline(5, 11 + by, 10, robeDark).hline(5, 11, 14, 'od'); // shoulder shade + belt
    img.set(7, 14, 'go'); // buckle
    img.vline(5, 15, 18, robeDark).vline(10, 15, 18, robeDark);
    img.set(8, 13 + by, accent);
    // feet (never bob — contact with the ground stays)
    img.rect(5, 19, 6, 21, 'k').rect(9, 19, 10, 21, 'k');
    img.set(5, 20, 'od').set(9, 20, 'od');
    return img;
  };
  const idle = base(false);
  const work = base(true);
  // idle: tool held low; work: arm raised with a tiny mallet + spark
  idle.rect(11, 12, 13, 15, 'k').rect(12, 12, 12, 14, 'sk');
  idle.rect(13, 14, 14, 17, 'k').vline(13, 14, 17, 'sd');
  work.rect(11, 9, 14, 12, 'k').rect(12, 9, 13, 11, 'sk');
  work.rect(12, 6, 15, 8, 'k').rect(13, 6, 14, 7, 'sd'); // mallet head up
  work.set(15, 5, 'gg').set(3, 4, 'wl'); // sparks
  const frames = [idle, work];
  return { w: 16, h: 24, frames };
}

function bubbleAlert() {
  const img = new Img(16, 16);
  img.ellipse(8, 6, 6, 4, 'k');
  img.ellipse(8, 6, 5, 3, 'iv');
  img.set(5, 10, 'k').set(4, 11, 'k');
  img.vline(8, 3, 6, 'err').set(8, 8, 'err');
  return [{ name: 'bubble-alert', img }];
}

/* ------------------------------------------------------------------ *
 * 10. Ambient life — clearly environmental, never agents.
 * ------------------------------------------------------------------ */

function butterfly() {
  const f0 = new Img(8, 8);
  const f1 = new Img(8, 8);
  const draw = (img, open) => {
    img.vline(3, 3, 5, 'k');
    if (open) {
      img.rect(0, 1, 2, 4, 'k').rect(1, 1, 2, 3, 'lv');
      img.rect(5, 1, 7, 4, 'k').rect(5, 1, 6, 3, 'lv');
      img.set(0, 2, 'lv').set(7, 2, 'lv');
    } else {
      img.rect(2, 1, 3, 3, 'k').rect(2, 2, 3, 3, 'lv');
      img.rect(4, 1, 5, 3, 'k').rect(4, 2, 5, 3, 'lv');
      img.set(2, 5, 'lv').set(5, 5, 'lv');
    }
  };
  draw(f0, true);
  draw(f1, false);
  return [{ name: 'butterfly', img: f0, frames: [f0, f1] }];
}

function firefly() {
  const f0 = new Img(6, 6);
  f0.set(3, 3, 'god');
  const f1 = new Img(6, 6);
  f1.set(2, 2, 'go').set(4, 2, 'go').set(2, 4, 'go').set(4, 4, 'go');
  f1.set(3, 3, 'gg').set(3, 2, 'gg').set(2, 3, 'gg').set(4, 3, 'gg').set(3, 4, 'gg');
  return [{ name: 'firefly', img: f0, frames: [f0, f1] }];
}

function hornero() {
  const f0 = new Img(16, 12);
  const draw = (img, tail) => {
    img.rect(7, 8, 8, 10, 'k').rect(7, 8, 8, 9, 'od'); // legs
    img.ellipse(8, 6, 5, 4, 'k');
    img.ellipse(8, 5, 4, 4, 'hb'); // body
    img.ellipse(8, 7, 3, 2, 'hbl'); // belly
    img.ellipse(4, 2, 2, 2, 'hb'); // head
    img.set(3, 2, 'k').set(2, 3, 'go'); // eye + beak
    img.set(5, 1, 'hbd');
    if (tail) img.rect(11, 2, 13, 4, 'hbd');
    else img.rect(11, 4, 13, 6, 'hbd');
    img.set(7, 3, 'hbd'); // wing
  };
  draw(f0, false);
  const f1 = new Img(16, 12);
  draw(f1, true);
  return [{ name: 'hornero', img: f0, frames: [f0, f1] }];
}

/* ------------------------------------------------------------------ *
 * 11. Registry + output. Frames are packed horizontally in one PNG.
 * ------------------------------------------------------------------ */

function collect() {
  const sprites = new Map();
  const put = (name, img, frames) => {
    sprites.set(name, { img, frames: frames || [img] });
  };
  for (const h of HOUSES) for (const s of house(h)) put(s.name, s.img);
  for (const group of [
    landmarkWorkspace(),
    landmarkArchive(),
    landmarkLibrary(),
    landmarkOperations(),
    landmarkTerminal(),
    landmarkFiles(),
    landmarkSettings(),
    landmarkAttention(),
    objCatalog(),
    objProjectShelf(),
    objMemoryEntry(),
    objToolRack(),
    objTerminalDesk(),
    objAgentPlate(),
    objSwarmTable(),
    objLoopClock(),
    objCrate(),
    objInbox(),
    objLamp(),
    bridge(),
    treeRound(),
    treeBlossom(),
    treeAmber(),
    treePine(),
    treeWillow(),
    bush(),
    rock(),
    tallGrass(),
    mushroom(),
    reeds(),
    lily(),
    stump(),
    fence(),
    signPost(),
    floorPlank(),
    wallBand(),
    doorExit(),
    rug(),
    plantPot(),
    deskTerminal(),
    deskFiles(),
    shelfBooks(),
    cabinetMemory(),
    benchTools(),
    boardMap(),
    projectOverviewBoard(),
    crate(),
    bubbleAlert(),
    butterfly(),
    firefly(),
    hornero(),
  ])
    for (const s of group) put(s.name, s.img, s.frames);
  for (let i = 0; i < 6; i++) put(`grass-${'abcdef'[i]}`, grassTile(i + 1));
  for (let i = 0; i < 4; i++) put(`flowers-${['poppy', 'daisy', 'lavender', 'gold'][i]}`, flowerTile(i));
  for (const t of dirtTiles()) put(t.name, t.img);
  for (const t of plazaTiles()) put(t.name, t.img);
  for (const t of waterTiles()) put(t.name, t.img, t.frames);
  for (const [name, ch] of [
    ['char-teal', character('re', 'red', 'cy')],
    ['char-gold', character('rw', 'rwd', 'gg')],
    ['char-brick', character('bk', 'bkd', 'wy')],
    ['char-scout', character('re', 'red', 'cy', 'od')],
    ['char-maker', character('rw', 'rwd', 'gg', 'rrd', 'skd')],
    ['char-scholar', character('rs', 'rsd', 'lv', 'inkd')],
    ['char-keeper', character('rm', 'rmd', 'wy', 'rw', 'skd')],
  ])
    put(name, ch.frames[0], ch.frames);
  return sprites;
}

function render(sprite) {
  const frames = sprite.frames;
  const w = sprite.img.w * frames.length;
  const h = sprite.img.h;
  const out = Buffer.alloc(w * h * 4);
  frames.forEach((f, fi) => {
    const rgba = f.toRgba(P);
    for (let y = 0; y < h; y++) {
      rgba.copy(out, (y * w + fi * f.w) * 4, y * f.w * 4, (y + 1) * f.w * 4);
    }
  });
  return encodePng(w, h, out);
}

function main() {
  const check = process.argv.includes('--check');
  const sprites = collect();
  const manifest = {};
  const written = [];
  const diffs = [];
  for (const [name, sprite] of sprites) {
    const png = render(sprite);
    manifest[name] = {
      file: `${name}.png`,
      w: sprite.img.w,
      h: sprite.img.h,
      frames: sprite.frames.length,
    };
    const dest = path.join(OUT, `${name}.png`);
    if (check) {
      const prev = fs.existsSync(dest) ? fs.readFileSync(dest) : null;
      if (!prev || !prev.equals(png)) diffs.push(name);
    } else {
      fs.writeFileSync(dest, png);
      written.push(name);
    }
  }
  const manifestJson = JSON.stringify({ generated: 'gen-world-assets.mjs', sprites: manifest }, null, 2) + '\n';
  const manifestDest = path.join(OUT, 'manifest.json');
  if (check) {
    const prev = fs.existsSync(manifestDest) ? fs.readFileSync(manifestDest, 'utf8') : null;
    if (prev !== manifestJson) diffs.push('manifest.json');
  } else {
    fs.writeFileSync(manifestDest, manifestJson);
  }
  if (check) {
    if (diffs.length) {
      console.error(`world assets out of date: ${diffs.join(', ')}`);
      console.error('run: node scripts/gen-world-assets.mjs');
      process.exit(1);
    }
    console.log(`world assets up to date (${sprites.size} sprites)`);
  } else {
    console.log(`generated ${written.length} sprites -> ${path.relative(process.cwd(), OUT)}`);
  }
}

main();
