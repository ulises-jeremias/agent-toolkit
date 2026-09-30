import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';

const here = path.dirname(fileURLToPath(import.meta.url));
const appDir = path.resolve(here, '..');
const destDir = path.resolve(appDir, 'resources', 'bin');
const exe = process.platform === 'win32' ? 'agent-toolkit.exe' : 'agent-toolkit';

/** Resolve the V backend binary: explicit path, release dist, or PATH. */
function resolveSource() {
  const explicit = process.env.ATK_BACKEND_BIN;
  if (explicit && fs.existsSync(explicit)) return explicit;
  const repoDist = path.resolve(appDir, '..', '..', 'dist', 'agent-toolkit');
  if (fs.existsSync(repoDist)) return repoDist;
  try {
    const found = execFileSync(process.platform === 'win32' ? 'where' : 'which', [exe], {
      encoding: 'utf8',
    })
      .trim()
      .split('\n')[0];
    if (found) return found.trim();
  } catch {
    // fall through
  }
  throw new Error('no agent-toolkit backend found (set ATK_BACKEND_BIN, build dist/, or install on PATH)');
}

const source = resolveSource();
fs.mkdirSync(destDir, { recursive: true });
fs.copyFileSync(source, path.join(destDir, exe));
fs.chmodSync(path.join(destDir, exe), 0o755);
console.log(`staged backend ${source} -> ${path.join(destDir, exe)}`);

// Pin the staged binary's version for the supervisor's startup check:
// a stale bundled backend is caught as version-mismatch instead of
// failing mysteriously at runtime. The previous pin is removed first and
// any probe failure aborts staging, so `dist` can never package a pin that
// describes a different binary.
const resDir = path.resolve(appDir, 'resources');
const pinPath = path.join(resDir, 'backend-version.json');
fs.mkdirSync(resDir, { recursive: true });
fs.rmSync(pinPath, { force: true });
let version = '';
try {
  const out = execFileSync(path.join(destDir, exe), ['--version'], { encoding: 'utf8' }).trim();
  version = out.split(/\s+/).pop() ?? '';
} catch (error) {
  console.error(`could not probe staged backend version: ${error.message}`);
  process.exit(1);
}
if (!version) {
  console.error('staged backend printed no version; refusing to write a pin');
  process.exit(1);
}
fs.writeFileSync(pinPath, JSON.stringify({ version }) + '\n');
console.log(`pinned backend version ${version}`);
