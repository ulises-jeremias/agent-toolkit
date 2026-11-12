#!/usr/bin/env node
/**
 * gen-valley-art.mjs — builds the Hornero Valley pixel art (PXL sources in
 * ./valley-art) into public/valley/ and writes manifest.json.
 *
 * Static sprites come from sprites/<name>.png; animations come from
 * anims/<name>.png (a horizontal strip) plus anims/<name>.json (frame
 * durations). Deterministic: --check rebuilds and byte-compares.
 *
 * The sources are trusted, reviewed, in-repo files, so --trust-art is passed
 * here and nowhere else.
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
const SOURCE = path.join(desktopRoot, 'scripts', 'valley-art', 'scenes.px.js');
const OUT = path.join(desktopRoot, 'public', 'valley');

function pngSize(png, name) {
  const signature = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  if (png.length < 24 || !png.subarray(0, 8).equals(signature)) throw new Error(`invalid PNG for ${name}`);
  return { w: png.readUInt32BE(16), h: png.readUInt32BE(20) };
}

function main() {
  const check = process.argv.includes('--check');
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-valley-'));
  const files = new Map(); // published file name -> bytes
  const manifest = {};
  try {
    execFileSync(process.execPath, [PXL, 'build', '--trust-art', SOURCE, '--out', tmp], {
      stdio: ['ignore', 'ignore', 'inherit'],
      timeout: 300_000,
      maxBuffer: 16 * 1024 * 1024,
    });
    for (const file of fs.readdirSync(path.join(tmp, 'sprites')).sort()) {
      if (!file.endsWith('.png') || file.startsWith('_')) continue;
      const name = file.replace(/\.png$/, '');
      const png = fs.readFileSync(path.join(tmp, 'sprites', file));
      const { w, h } = pngSize(png, name);
      files.set(`${name}.png`, png);
      manifest[name] = { file: `${name}.png`, w, h, frames: 1, frameMs: null, sha256: sha(png) };
    }
    for (const file of fs.readdirSync(path.join(tmp, 'anims')).sort()) {
      if (!file.endsWith('.json')) continue;
      const name = file.replace(/\.json$/, '');
      const meta = JSON.parse(fs.readFileSync(path.join(tmp, 'anims', file), 'utf8'));
      const durations = Object.values(meta.frames).map((frame) => frame.duration);
      const strip = fs.readFileSync(path.join(tmp, 'anims', `${name}.png`));
      const { w, h } = pngSize(strip, name);
      const frameW = Object.values(meta.frames)[0].frame.w;
      files.set(`${name}.png`, strip);
      manifest[name] = {
        file: `${name}.png`,
        w: frameW,
        h,
        frames: w / frameW,
        frameMs: durations,
        sha256: sha(strip),
      };
    }
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }

  const manifestJson = `${JSON.stringify({ generated: 'gen-valley-art.mjs', sprites: manifest }, null, 2)}\n`;
  if (check) {
    const diffs = [];
    for (const [file, bytes] of files) {
      const dest = path.join(OUT, file);
      if (!fs.existsSync(dest) || !fs.readFileSync(dest).equals(bytes)) diffs.push(file);
    }
    const prev = fs.existsSync(path.join(OUT, 'manifest.json')) ? fs.readFileSync(path.join(OUT, 'manifest.json'), 'utf8') : null;
    if (prev !== manifestJson) diffs.push('manifest.json');
    if (diffs.length) {
      console.error(`valley art out of date: ${diffs.join(', ')}`);
      console.error('run: node scripts/gen-valley-art.mjs');
      process.exit(1);
    }
    console.log(`valley art up to date (${Object.keys(manifest).length} assets)`);
    return;
  }
  fs.rmSync(OUT, { recursive: true, force: true });
  fs.mkdirSync(OUT, { recursive: true });
  for (const [file, bytes] of files) fs.writeFileSync(path.join(OUT, file), bytes);
  fs.writeFileSync(path.join(OUT, 'manifest.json'), manifestJson);
  console.log(`generated ${Object.keys(manifest).length} valley assets -> public/valley`);
}

function sha(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

main();
