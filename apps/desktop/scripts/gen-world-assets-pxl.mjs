#!/usr/bin/env node
/**
 * gen-world-assets-pxl.mjs — PXL Renaissance asset pipeline (mission #1741).
 *
 * Renders the original Renaissance sprite set from PXL sources in
 * ./world-art-pxl/*.px.js with the governed vendored renderer
 * (skills/design/pxl-pixel-art, crsolver/claude-pxl @ 21fee41) and writes:
 *   - public/world/<name>.png            (one file per sprite)
 *   - scripts/world-art-pxl/pxl-manifest.json  (name -> {file,w,h,frames,source,sha256})
 *   - scripts/world-art-pxl/preview/<name>.png (upscaled review previews)
 *
 * gen-world-assets.mjs merges pxl-manifest entries into the world manifest
 * and skips PXL-owned sprites; it remains the single writer of
 * src/features/world/manifest.json + public/world/manifest.json until the
 * legacy painters are retired (PR E), when this script takes over.
 *
 * Deterministic: PXL uses seeded rng only; --check rebuilds and byte-compares.
 * Security: .px.js files are trusted executable code. Only the reviewed
 * in-repo sources below are ever built; never pass external art files.
 *
 * Usage: node scripts/gen-world-assets-pxl.mjs [--check]
 */
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const desktopRoot = path.resolve(here, '..');
const repoRoot = path.resolve(desktopRoot, '..', '..');
const PXL = path.join(repoRoot, 'skills', 'design', 'pxl-pixel-art', 'bin', 'pxl.js');
const SRC_DIR = path.join(here, 'world-art-pxl');
const OUT = path.join(desktopRoot, 'public', 'world');
const PXL_MANIFEST = path.join(SRC_DIR, 'pxl-manifest.json');
const PREVIEW_DIR = path.join(SRC_DIR, 'preview');

/** Sprites authored as horizontal frame strips: name pattern -> frame width. */
const FRAME_WIDTHS = [
  [/^water$/, 16],
  [/^char-/, 16],
  [/^lamp$/, 16],
  [/^hornero$/, 16],
  [/^butterfly$/, 8],
  [/^firefly$/, 12],
  [/^mote$/, 10],
  [/^water-sparkle$/, 10],
];

function frameWidth(name, pngWidth) {
  for (const [pattern, width] of FRAME_WIDTHS) {
    if (pattern.test(name)) {
      if (pngWidth % width !== 0) throw new Error(`${name}: width ${pngWidth} is not a multiple of frame width ${width}`);
      return width;
    }
  }
  return pngWidth;
}

function pngSize(png, name) {
  const signature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  if (png.length < 24 || !png.subarray(0, 8).equals(signature) || png.toString('ascii', 12, 16) !== 'IHDR') {
    throw new Error(`invalid PNG produced for ${name}`);
  }
  return { w: png.readUInt32BE(16), h: png.readUInt32BE(20) };
}

function main() {
  const check = process.argv.includes('--check');
  if (!fs.existsSync(PXL)) throw new Error(`vendored PXL renderer not found: ${PXL}`);
  const sources = fs
    .readdirSync(SRC_DIR)
    .filter((file) => file.endsWith('.px.js') && file !== 'palette.px.js')
    .sort();
  if (sources.length === 0) throw new Error(`no PXL sources in ${SRC_DIR}`);

  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-pxl-'));
  const manifest = {};
  const diffs = [];
  try {
    for (const source of sources) {
      const outDir = path.join(tmp, source.replace(/\.px\.js$/, ''));
      // --trust-art: these are the reviewed in-repo sources; the CLI refuses
      // to execute art without this explicit acknowledgement.
      execFileSync(process.execPath, [PXL, 'build', '--trust-art', path.join(SRC_DIR, source), '--out', outDir], {
        stdio: ['ignore', 'pipe', 'inherit'],
        timeout: 120_000,
        maxBuffer: 16 * 1024 * 1024,
      });
      const spritesDir = path.join(outDir, 'sprites');
      for (const file of fs.readdirSync(spritesDir).sort()) {
        if (!file.endsWith('.png')) continue;
        const name = file.replace(/\.png$/, '');
        if (name.startsWith('_')) continue; // reusable parts are not assets
        const png = fs.readFileSync(path.join(spritesDir, file));
        const { w: totalW, h } = pngSize(png, name);
        const fw = frameWidth(name, totalW);
        if (manifest[name]) {
          throw new Error(
            `duplicate sprite id '${name}': ${manifest[name].source} and scripts/world-art-pxl/${source} both produce it; rename one`,
          );
        }
        manifest[name] = {
          file: `${name}.png`,
          w: fw,
          h,
          frames: totalW / fw,
          source: `scripts/world-art-pxl/${source}`,
          sha256: createHash('sha256').update(png).digest('hex'),
        };
        const dest = path.join(OUT, `${name}.png`);
        const previewSrc = path.join(outDir, '_preview', file);
        const previewDest = path.join(PREVIEW_DIR, file);
        if (check) {
          if (!fs.existsSync(dest) || !fs.readFileSync(dest).equals(png)) diffs.push(name);
          if (fs.existsSync(previewSrc) && (!fs.existsSync(previewDest) || !fs.readFileSync(previewDest).equals(fs.readFileSync(previewSrc)))) {
            diffs.push(`preview/${name}`);
          }
        } else {
          fs.mkdirSync(OUT, { recursive: true });
          fs.writeFileSync(dest, png);
          if (fs.existsSync(previewSrc)) {
            fs.mkdirSync(PREVIEW_DIR, { recursive: true });
            fs.copyFileSync(previewSrc, previewDest);
          }
        }
      }
    }
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }

  // Obsolete outputs: sprites the previous pxl-manifest owned that no
  // source produces anymore (the preview gallery is fully PXL-owned, so
  // any unlisted preview is stale too). Sprites owned by other generators
  // are never touched. --check reports; a normal run removes.
  const prevNames = new Set(
    fs.existsSync(PXL_MANIFEST) ? Object.keys(JSON.parse(fs.readFileSync(PXL_MANIFEST, 'utf8')).sprites ?? {}) : [],
  );
  const staleSprites = [...prevNames].filter((name) => !manifest[name]).map((name) => `${name}.png`);
  const stalePreviews = fs.existsSync(PREVIEW_DIR)
    ? fs.readdirSync(PREVIEW_DIR).filter((f) => f.endsWith('.png') && !manifest[f.replace(/\.png$/, '')])
    : [];
  for (const file of staleSprites) {
    if (check) diffs.push(`stale:${file}`);
    else if (fs.existsSync(path.join(OUT, file))) fs.rmSync(path.join(OUT, file));
  }
  for (const file of stalePreviews) {
    if (check) diffs.push(`stale:preview/${file}`);
    else fs.rmSync(path.join(PREVIEW_DIR, file));
  }

  const manifestJson = JSON.stringify({ generated: 'gen-world-assets-pxl.mjs', sprites: manifest }, null, 2) + '\n';
  if (check) {
    const prev = fs.existsSync(PXL_MANIFEST) ? fs.readFileSync(PXL_MANIFEST, 'utf8') : null;
    if (prev !== manifestJson) diffs.push('pxl-manifest.json');
    if (diffs.length) {
      console.error(`pxl world assets out of date: ${diffs.join(', ')}`);
      console.error('run: node scripts/gen-world-assets-pxl.mjs && node scripts/gen-world-assets.mjs');
      process.exit(1);
    }
    console.log(`pxl world assets up to date (${Object.keys(manifest).length} sprites)`);
  } else {
    fs.writeFileSync(PXL_MANIFEST, manifestJson);
    console.log(`generated ${Object.keys(manifest).length} pxl sprites -> public/world (+preview)`);
  }
}

main();
