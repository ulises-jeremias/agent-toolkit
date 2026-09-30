import { spawn, type ChildProcess } from 'node:child_process';
import fs from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import { harnessSpawnContext, resolveHarnessFromProcess, type HarnessResolution } from './harness';

export type { HarnessResolution, HarnessSource } from './harness';

export type BackendStatus =
  | 'starting'
  | 'ready'
  | 'version-mismatch'
  | 'crashed'
  | 'stopped'
  | 'failed';

export interface BackendState {
  status: BackendStatus;
  url: string | null;
  version: string | null;
  detail: string | null;
  restarts: number;
  /** Harness the current (or last) backend was spawned in; null before first start. */
  harness: HarnessResolution | null;
}

export interface BackendSupervisorOptions {
  /** Re-evaluated on every start so restarts pick up a changed harness. */
  resolveHarness?: () => HarnessResolution;
}

export interface HealthPayload {
  ok: boolean;
  version: string;
  commit?: string;
  uptime_s?: number;
}

const START_TIMEOUT_MS = 30_000;
const POLL_INTERVAL_MS = 250;
const STOP_GRACE_MS = 5_000;
const MAX_STDERR_TAIL = 8_192;

/**
 * Major version the running backend must match. `stage-backend` writes the
 * staged binary's version to `resources/backend-version.json`, so a stale
 * bundled backend is caught at startup instead of failing mysteriously.
 * Returns null when no pin is available (dev without staging): the caller
 * must say so honestly instead of comparing the version against itself.
 */
export function resolveExpectedBackendMajor(): string | null {
  const override = process.env.ATK_EXPECTED_BACKEND_MAJOR?.trim();
  if (override) return override.replace(/^v/, '').split('.')[0] ?? null;
  for (const dir of candidateResourceDirs()) {
    try {
      const raw = fs.readFileSync(path.join(dir, 'backend-version.json'), 'utf8');
      const parsed = JSON.parse(raw) as { version?: unknown };
      if (typeof parsed.version === 'string' && parsed.version.trim()) {
        return parsed.version.trim().replace(/^v/, '').split('.')[0] ?? null;
      }
    } catch {
      // Missing or unreadable pin in this dir; try the next.
    }
  }
  return null;
}

function candidateResourceDirs(): string[] {
  const dirs: string[] = [];
  const resourcesPath =
    typeof (process as NodeJS.Process & { resourcesPath?: unknown }).resourcesPath === 'string'
      ? (process as NodeJS.Process & { resourcesPath: string }).resourcesPath
      : '';
  if (resourcesPath) dirs.push(resourcesPath);
  // Dev layout: compiled main lives in apps/desktop/dist-electron.
  dirs.push(path.resolve(__dirname, '..', 'resources'));
  return dirs;
}

/** Locate the bundled V backend binary, else PATH, else a dev checkout. */
export function resolveBackendBinary(): { bin: string; argsPrefix: string[]; source: string } {
  const exe = process.platform === 'win32' ? 'agent-toolkit.exe' : 'agent-toolkit';
  // process.resourcesPath exists only inside Electron; plain Node (tests, dev
  // tooling) falls through to PATH.
  const resourcesPath =
    typeof (process as NodeJS.Process & { resourcesPath?: unknown }).resourcesPath === 'string'
      ? (process as NodeJS.Process & { resourcesPath: string }).resourcesPath
      : '';
  if (resourcesPath) {
    const bundled = path.join(resourcesPath, 'bin', exe);
    if (fs.existsSync(bundled)) {
      return { bin: bundled, argsPrefix: [], source: 'bundled' };
    }
  }
  const fromPath = findOnPath(exe);
  if (fromPath) {
    return { bin: fromPath, argsPrefix: [], source: 'path' };
  }
  return { bin: exe, argsPrefix: [], source: 'path-fallback' };
}

function findOnPath(exe: string): string | null {
  const pathEnv = process.env.PATH ?? '';
  const sep = process.platform === 'win32' ? ';' : ':';
  for (const dir of pathEnv.split(sep)) {
    if (!dir) continue;
    // Absolute: serve is spawned with the harness as cwd, so a relative PATH
    // entry must not be re-resolved against it.
    const candidate = path.resolve(dir, exe);
    try {
      fs.accessSync(candidate, fs.constants.X_OK);
      return candidate;
    } catch {
      // keep searching
    }
  }
  return null;
}

function pickFreePort(): Promise<number> {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      const port = typeof address === 'object' && address ? address.port : 0;
      server.close(() => resolve(port));
    });
  });
}

async function fetchHealth(url: string): Promise<HealthPayload | null> {
  try {
    const res = await fetch(`${url}/api/v1/health`);
    if (!res.ok) return null;
    return (await res.json()) as HealthPayload;
  } catch {
    return null;
  }
}

function majorOf(version: string): string {
  return version.replace(/^v/, '').split('.')[0] ?? '';
}

/**
 * Owns the `agent-toolkit serve` child process: dynamic localhost port,
 * health-gated readiness, version compatibility, crash reporting, clean stop.
 * Desktop infrastructure only — no Agent Toolkit domain logic lives here.
 */
export class BackendSupervisor {
  private proc: ChildProcess | null = null;
  private state: BackendState = {
    status: 'stopped',
    url: null,
    version: null,
    detail: null,
    restarts: 0,
    harness: null,
  };
  private listeners = new Set<(state: BackendState) => void>();
  private stopping = false;
  private readonly resolveHarness: () => HarnessResolution;

  constructor(options: BackendSupervisorOptions = {}) {
    this.resolveHarness = options.resolveHarness ?? resolveHarnessFromProcess;
  }

  snapshot(): BackendState {
    return { ...this.state, harness: this.state.harness ? { ...this.state.harness } : null };
  }

  onState(listener: (state: BackendState) => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  private emit(patch: Partial<BackendState>): void {
    this.state = { ...this.state, ...patch };
    const snapshot = this.snapshot();
    for (const listener of this.listeners) listener(snapshot);
  }

  async start(): Promise<boolean> {
    if (this.proc || this.stopping) return this.state.status === 'ready';
    const { bin, argsPrefix, source } = resolveBackendBinary();
    let port = 0;
    try {
      port = await pickFreePort();
    } catch (error) {
      this.emit({ status: 'failed', detail: `no free localhost port: ${String(error)}` });
      return false;
    }
    const url = `http://127.0.0.1:${port}`;
    const harness = this.resolveHarness();
    this.emit({ status: 'starting', url, version: null, detail: `launching ${source} backend`, harness });

    // No --auth-token on argv: it would expose the secret in ps output.
    // The child inherits AGENT_TOOLKIT_TOKEN through env, which serve reads.
    // serve roots its jobs dir and containment at cwd, so cwd is the harness.
    const args = [...argsPrefix, 'serve', '--host', '127.0.0.1', '--port', String(port), '--no-browser'];
    const spawnContext = harnessSpawnContext(harness, process.env);
    const child = spawn(bin, args, {
      stdio: ['ignore', 'pipe', 'pipe'],
      cwd: spawnContext.cwd,
      env: { ...spawnContext.env, NO_COLOR: '1', TERM: 'dumb' },
      windowsHide: true,
    });
    this.proc = child;
    this.stopping = false;

    // Drain both pipes: an unread pipe blocks the backend once the OS
    // buffer (~64 KiB) fills, freezing serve without exiting. Keep a
    // bounded stderr tail for crash detail.
    let stderrTail = '';
    child.stdout?.resume();
    child.stdout?.on('error', () => undefined);
    child.stderr?.setEncoding('utf8');
    child.stderr?.on('data', (chunk: string) => {
      stderrTail = (stderrTail + chunk).slice(-MAX_STDERR_TAIL);
    });
    child.stderr?.on('error', () => undefined);
    child.stderr?.resume();

    child.on('exit', (code, signal) => {
      const wasStopping = this.stopping;
      this.proc = null;
      if (wasStopping) {
        this.emit({ status: 'stopped', detail: null });
        return;
      }
      const tail = stderrTail.trim().slice(-200);
      this.emit({
        status: 'crashed',
        detail:
          `backend exited code=${code ?? 'null'} signal=${signal ?? 'null'} (source=${source})` +
          (tail ? ` stderr: ${tail}` : ''),
      });
    });
    child.on('error', (error) => {
      this.proc = null;
      this.emit({ status: 'failed', detail: `cannot launch backend ${bin}: ${error.message}` });
    });

    const deadline = Date.now() + START_TIMEOUT_MS;
    let health: HealthPayload | null = null;
    let lastError: string | null = null;
    while (Date.now() < deadline) {
      if (this.proc === null) break; // exited early; exit handler already emitted
      health = await fetchHealth(url);
      if (health?.ok) break;
      lastError = `health check pending (${source} ${bin})`;
      await new Promise((r) => setTimeout(r, POLL_INTERVAL_MS));
    }
    if (!health?.ok) {
      if (this.state.status === 'starting') {
        await this.killChild();
        this.emit({ status: 'failed', detail: lastError ?? 'backend did not become healthy' });
      }
      return false;
    }
    const expectedMajor = resolveExpectedBackendMajor();
    const actualMajor = majorOf(health.version);
    const status: BackendStatus =
      expectedMajor === null || actualMajor === expectedMajor ? 'ready' : 'version-mismatch';
    this.emit({
      status,
      version: health.version,
      detail:
        status === 'version-mismatch'
          ? `backend ${health.version} differs from staged major ${expectedMajor}; reinstall recommended`
          : `backend ${health.version} via ${source}` +
            (expectedMajor === null ? ' (no staged version pin; set ATK_EXPECTED_BACKEND_MAJOR to enforce)' : ''),
    });
    return status === 'ready';
  }

  async restart(): Promise<boolean> {
    this.state.restarts += 1;
    await this.stop();
    return this.start();
  }

  async stop(): Promise<void> {
    this.stopping = true;
    await this.killChild();
    // Clear the flag so a later start()/restart() is not blocked: stopping
    // only guards the exit handler against reporting an intentional shutdown
    // as a crash.
    this.stopping = false;
    this.emit({ status: 'stopped', url: null, version: null, detail: null });
  }

  private async killChild(): Promise<void> {
    const child = this.proc;
    if (!child || child.exitCode !== null) {
      this.proc = null;
      return;
    }
    await new Promise<void>((resolve) => {
      const timer = setTimeout(() => {
        try {
          child.kill('SIGKILL');
        } catch {
          // already gone
        }
      }, STOP_GRACE_MS);
      child.once('exit', () => {
        clearTimeout(timer);
        resolve();
      });
      try {
        const sig: NodeJS.Signals = process.platform === 'win32' ? 'SIGTERM' : 'SIGTERM';
        child.kill(sig);
      } catch {
        clearTimeout(timer);
        resolve();
      }
    });
    this.proc = null;
  }
}
