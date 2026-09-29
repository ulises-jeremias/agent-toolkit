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
