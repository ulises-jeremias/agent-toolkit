/**
 * Gate 0/1 read-only provider executable preflight.
 * Does not authenticate, create sessions, inspect credentials or certify usability.
 * Run: node apps/desktop/scripts/spikes/provider-binary-preflight.mjs
 */
import { spawn } from 'node:child_process';
import { pathToFileURL } from 'node:url';

export const PROVIDERS = Object.freeze(['claude', 'codex', 'opencode']);

export async function probeBinary(command, { timeoutMs = 2500, spawnFn = spawn } = {}) {
  if (!PROVIDERS.includes(command)) throw new Error('unsupported provider');
  return await new Promise(resolve => {
    let settled = false;
    let stdout = '';
    let stderr = '';
    let timer;
    const finish = result => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve({ provider: command, ...result, authenticated: 'unverified', session: 'unverified' });
    };
    let child;
    try {
      child = spawnFn(command, ['--version'], {
        shell: false,
        stdio: ['ignore', 'pipe', 'pipe'],
        windowsHide: true,
      });
    } catch (error) {
      finish({ status: 'spawn_error', reason: error.code || 'unknown' });
      return;
    }
    child.stdout?.on('data', chunk => { stdout = (stdout + chunk.toString()).slice(0, 4096); });
    child.stderr?.on('data', chunk => { stderr = (stderr + chunk.toString()).slice(0, 4096); });
    child.on('error', error => finish({ status: 'unavailable', reason: error.code || 'unknown' }));
    child.on('close', (code, signal) => {
      finish(code === 0
        ? { status: 'binary_present', versionOutput: stdout.trim().slice(0, 512) }
        : { status: 'version_failed', exitCode: code, signal: signal || null,
            diagnostic: stderr.trim().slice(0, 512) });
    });
    timer = setTimeout(() => {
      child.kill();
      finish({ status: 'timeout', timeoutMs });
    }, timeoutMs);
  });
}

export async function probeAll(options) {
  return Promise.all(PROVIDERS.map(provider => probeBinary(provider, options)));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const result = await probeAll();
  process.stdout.write(JSON.stringify({
    evidence_level: 'U',
    note: 'Binary version probes only; no authentication, provider session or installed Desktop evidence',
    results: result,
  }, null, 2) + '\n');
}
