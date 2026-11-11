#!/usr/bin/env node
/**
 * gen-world-art-pxl.mjs — Hornero Valley web world-art pipeline (#1759).
 *
 * Renders original PXL sources in ./world-art-pxl/*.px.js with the governed
 * vendored renderer (skills/design/pxl-pixel-art/bin/pxl.js, crsolver/claude-pxl)
 * and writes:
 *   - public/world-art/<name>.png        (sprites + hero-valley scene; WebP-ready
 *                                         lossless PNG, convert with any WebP encoder)
 *   - public/world-art/manifest.json     (name -> {file,w,h,kind,source,sha256,bytes})
 *   - scripts/world-art-pxl/preview/*.png + preview/index.html (review gallery)
 *
 * Deterministic: PXL uses seeded rng only. `--check` rebuilds to a temp dir and
 * byte-compares every output + manifest; exits 1 on drift, writes nothing.
 * Security: .px.js is trusted executable code — `--trust-art` is passed ONLY for
 * the reviewed in-repo sources listed by readdir of this directory; never add
 * external art files.
 *
 * Usage: node scripts/gen-world-art-pxl.mjs [--check]
 */
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const webRoot = path.resolve(here, "..");
const repoRoot = path.resolve(webRoot, "..", "..");
const PXL = path.join(
  repoRoot,
  "skills",
  "design",
  "pxl-pixel-art",
  "bin",
  "pxl.js",
);
const SRC_DIR = path.join(here, "world-art-pxl");
const OUT = path.join(webRoot, "public", "world-art");
const PREVIEW_DIR = path.join(SRC_DIR, "preview");

function pngSize(png, name) {
  if (png.length < 24 || png.toString("ascii", 12, 16) !== "IHDR")
    throw new Error(`invalid PNG for ${name}`);
  return { w: png.readUInt32BE(16), h: png.readUInt32BE(20) };
}

function main() {
  const check = process.argv.includes("--check");
  if (!fs.existsSync(PXL))
    throw new Error(`vendored PXL renderer not found: ${PXL}`);
  const sources = fs
    .readdirSync(SRC_DIR)
    .filter((f) => f.endsWith(".px.js") && f !== "palette.px.js")
    .sort();
  if (!sources.length) throw new Error(`no PXL sources in ${SRC_DIR}`);
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "atk-web-pxl-"));
  const manifest = {};
  const diffs = [];
  const previews = new Map();
  try {
    for (const source of sources) {
      const outDir = path.join(tmp, source.replace(/\.px\.js$/, ""));
      execFileSync(
        process.execPath,
        [
          PXL,
          "build",
          "--trust-art",
          path.join(SRC_DIR, source),
          "--out",
          outDir,
        ],
        {
          stdio: ["ignore", "pipe", "inherit"],
          timeout: 120_000,
          maxBuffer: 16 * 1024 * 1024,
        },
      );
      for (const [subdir, kind] of [
        ["sprites", "sprite"],
        ["scenes", "scene"],
      ]) {
        const dir = path.join(outDir, subdir);
        if (!fs.existsSync(dir)) continue;
        for (const file of fs.readdirSync(dir).sort()) {
          if (!file.endsWith(".png")) continue;
          const name = file.replace(/\.png$/, "");
          if (name.startsWith("_")) continue;
          if (manifest[name])
            throw new Error(`duplicate asset '${name}' from ${source}`);
          const png = fs.readFileSync(path.join(dir, file));
          const { w, h } = pngSize(png, name);
          manifest[name] = {
            file: `${name}.png`,
            w,
            h,
            kind,
            source: `scripts/world-art-pxl/${source}`,
            sha256: createHash("sha256").update(png).digest("hex"),
            bytes: png.length,
          };
          const dest = path.join(OUT, file);
          const prevSrc = path.join(outDir, "_preview", file);
          if (prevSrc && fs.existsSync(prevSrc))
            previews.set(file, fs.readFileSync(prevSrc));
          if (check) {
            if (!fs.existsSync(dest) || !fs.readFileSync(dest).equals(png))
              diffs.push(name);
            const pd = path.join(PREVIEW_DIR, file);
            if (
              previews.has(file) &&
              (!fs.existsSync(pd) ||
                !fs.readFileSync(pd).equals(previews.get(file)))
            )
              diffs.push(`preview/${name}`);
          } else {
            fs.mkdirSync(OUT, { recursive: true });
            fs.writeFileSync(dest, png);
            if (previews.has(file)) {
              fs.mkdirSync(PREVIEW_DIR, { recursive: true });
              fs.writeFileSync(
                path.join(PREVIEW_DIR, file),
                previews.get(file),
              );
            }
          }
        }
      }
    }
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }

  const sorted = Object.fromEntries(
    Object.entries(manifest).sort(([a], [b]) => a.localeCompare(b)),
  );
  const manifestJson =
    JSON.stringify(
      { generated: "gen-world-art-pxl.mjs", assets: sorted },
      null,
      2,
    ) + "\n";
  const gallery =
    `<!doctype html><meta charset="utf-8"><title>Hornero Valley web world-art preview</title>\n<body style="background:#2b2135;color:#fff6e0;font-family:system-ui"><h1>Hornero Valley — web world-art</h1>\n` +
    Object.keys(sorted)
      .map(
        (n) =>
          `<figure style="display:inline-block;margin:8px"><img src="./${n}.png" alt="${n}" style="image-rendering:pixelated;max-width:480px;background:#888"><figcaption>${n} (${sorted[n].w}x${sorted[n].h})</figcaption></figure>`,
      )
      .join("\n") +
    "\n</body>\n";
  const manifestDest = path.join(OUT, "manifest.json");
  const galleryDest = path.join(PREVIEW_DIR, "index.html");
  if (check) {
    if (
      !fs.existsSync(manifestDest) ||
      fs.readFileSync(manifestDest, "utf8") !== manifestJson
    )
      diffs.push("manifest.json");
    if (
      !fs.existsSync(galleryDest) ||
      fs.readFileSync(galleryDest, "utf8") !== gallery
    )
      diffs.push("preview/index.html");
    if (diffs.length) {
      console.error(`web world-art out of date: ${diffs.join(", ")}`);
      console.error("run: node scripts/gen-world-art-pxl.mjs");
      process.exit(1);
    }
    console.log(
      `web world-art up to date (${Object.keys(sorted).length} assets)`,
    );
  } else {
    fs.mkdirSync(OUT, { recursive: true });
    fs.mkdirSync(PREVIEW_DIR, { recursive: true });
    fs.writeFileSync(manifestDest, manifestJson);
    fs.writeFileSync(galleryDest, gallery);
    const total = Object.values(sorted).reduce((s, a) => s + a.bytes, 0);
    console.log(
      `generated ${Object.keys(sorted).length} web world-art assets (${total} bytes) -> public/world-art (+preview gallery, manifest)`,
    );
  }
}
main();
