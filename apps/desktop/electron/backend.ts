import { spawn, type ChildProcess } from 'node:child_process';
import net from 'node:net';
import {
  defaultCandidateInputs,
  describeRejected,
  isExecutableFile,
  listBackendCandidates,
  majorOf,
  probeDesktopGate,
  resolveBackendPin,
  runBinary,
  selectBackendBinary,
  type BackendBinaryInfo,
  type BackendPin,
  type BinarySelection,
  type DesktopGateProbe,
  type RejectedBackendBinary,
} from './backend-binary';
import { harnessSpawnContext, resolveHarnessFromProcess, type HarnessResolution } from './harness';

export type { HarnessResolution, HarnessSource } from './harness';
export type { BackendBinaryInfo, BackendBinarySource, RejectedBackendBinary } from './backend-binary';

export type BackendStatus = 'starting' | 'ready' | 'version-mismatch' | 'crashed' | 'stopped' | 'failed';

/**
 * Machine-readable cause behind a non-ready status, so UI can offer the right
 * next action instead of a generic "crashed":
 * - `no-backend`: no candidate binary exists anywhere
 * - `binary-rejected`: candidates exist but none passed the pre-spawn probe
 * - `spawn-error`: the OS refused to launch the selected binary
 * - `exited-during-start`: serve exited before its health check passed
 * - `health-timeout`: serve ran but never answered /api/v1/health
 * - `major-mismatch`: healthy serve reports a major other than the pin
 * - `desktop-gate-missing`: healthy serve rejects Desktop mutations (403)
 * - `exited`: serve exited after it was ready (a real crash)
 * - `port`: no free localhost port
 */
export type BackendProblem =
  | 'no-backend'
  | 'binary-rejected'
  | 'spawn-error'
  | 'exited-during-start'
  | 'health-timeout'
  | 'major-mismatch'
  | 'desktop-gate-missing'
  | 'exited'
  | 'port';

export interface BackendState {
  status: BackendStatus;
  url: string | null;
  version: string | null;
  detail: string | null;
  restarts: number;
  /** Harness the current (or last) backend was spawned in; null before first start. */
  harness: HarnessResolution | null;
  /** Binary selected for the current (or last) start; null when none was usable. */
  binary: BackendBinaryInfo | null;
  /** Candidates skipped by the last selection, with the reason for each. */
  rejected: RejectedBackendBinary[];
  problem: BackendProblem | null;
}

export interface BackendSupervisorOptions {
  /** Re-evaluated on every start so restarts pick up a changed harness. */
  resolveHarness?: () => HarnessResolution;
  /** Candidate discovery + probe; injectable for tests. */
  selectBinary?: (cwd: string | undefined) => Promise<BinarySelection>;
  resolvePin?: () => BackendPin | null;
  probeGate?: (url: string) => Promise<DesktopGateProbe>;
  spawnProcess?: typeof spawn;
  /** Decrypted MCP credentials are passed only to the supervised backend child. */
  resolveEnvironmentSecrets?: () => Record<string, string>;
  startTimeoutMs?: number;
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

function redactSecrets(text: string, secrets: string[]): string {
  let redacted = text;
  for (const secret of secrets.filter(Boolean).sort((left, right) => right.length - left.length)) {
    if (redacted.includes(secret)) {
      redacted = redacted.split(secret).join('[credential redacted]');
      continue;
    }
    // stderr is capped to its tail. If that truncation cuts through a long
    // credential, redact the matching edge fragment before exposing a slice.
    const leftOverlap = edgeOverlap(redacted, secret, 'left');
    if (leftOverlap > 0) redacted = `[credential redacted]${redacted.slice(leftOverlap)}`;
    const rightOverlap = edgeOverlap(redacted, secret, 'right');
    if (rightOverlap > 0) redacted = `${redacted.slice(0, -rightOverlap)}[credential redacted]`;
  }
  return redacted;
}

function edgeOverlap(text: string, secret: string, edge: 'left' | 'right'): number {
  const max = Math.min(text.length, secret.length - 1);
  for (let length = max; length >= 1; length -= 1) {
    const fragment = edge === 'left' ? secret.slice(-length) : secret.slice(0, length);
    if (edge === 'left' ? text.startsWith(fragment) : text.endsWith(fragment)) return length;
  }
  return 0;
}

/** Major from the staged pin or ATK_EXPECTED_BACKEND_MAJOR; null when unpinned. */
export function resolveExpectedBackendMajor(): string | null {
  return resolveBackendPin()?.major ?? null;
}

export function defaultSelectBinary(cwd: string | undefined): Promise<BinarySelection> {
  return selectBackendBinary(listBackendCandidates(defaultCandidateInputs()), {
    pin: resolveBackendPin(),
    run: runBinary,
    cwd,
    isExecutable: isExecutableFile,
  });
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

function describeBinary(binary: BackendBinaryInfo): string {
  return `${binary.path} (${binary.source}${binary.version ? `, ${binary.version}` : ''})`;
}

/**
 * Owns the `agent-toolkit serve` child process: deterministic binary
 * selection with a compatibility probe, dynamic localhost port, health-gated
 * readiness, version + Desktop-gate checks, crash reporting, clean stop.
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
    binary: null,
    rejected: [],
    problem: null,
  };
  private listeners = new Set<(state: BackendState) => void>();
  private starting: Promise<boolean> | null = null;
  /** Bumped by stop(); an in-flight start() whose generation changed abandons itself. */
  private generation = 0;
  private readonly resolveHarness: () => HarnessResolution;
  private readonly selectBinary: (cwd: string | undefined) => Promise<BinarySelection>;
  private readonly resolvePin: () => BackendPin | null;
  private readonly probeGate: (url: string) => Promise<DesktopGateProbe>;
  private readonly spawnProcess: typeof spawn;
  private readonly resolveEnvironmentSecrets: () => Record<string, string>;
  private readonly startTimeoutMs: number;

  constructor(options: BackendSupervisorOptions = {}) {
    this.resolveHarness = options.resolveHarness ?? (() => resolveHarnessFromProcess());
    this.selectBinary = options.selectBinary ?? defaultSelectBinary;
    this.resolvePin = options.resolvePin ?? resolveBackendPin;
    this.probeGate = options.probeGate ?? ((url) => probeDesktopGate(url));
    this.spawnProcess = options.spawnProcess ?? spawn;
    this.resolveEnvironmentSecrets = options.resolveEnvironmentSecrets ?? (() => ({}));
    this.startTimeoutMs = options.startTimeoutMs ?? START_TIMEOUT_MS;
  }

  snapshot(): BackendState {
    return {
      ...this.state,
      harness: this.state.harness ? { ...this.state.harness } : null,
      binary: this.state.binary ? { ...this.state.binary } : null,
      rejected: this.state.rejected.map((entry) => ({ ...entry })),
    };
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

  /** Singleflight: concurrent callers share one start attempt. */
  start(): Promise<boolean> {
    if (this.proc) return Promise.resolve(this.state.status === 'ready');
    if (!this.starting) {
      const attempt = this.doStart(this.generation).finally(() => {
        if (this.starting === attempt) this.starting = null;
      });
      this.starting = attempt;
    }
    return this.starting;
  }

  private async doStart(generation: number): Promise<boolean> {
    const stale = (): boolean => generation !== this.generation;
    const harness = this.resolveHarness();
    const spawnContext = harnessSpawnContext(harness, process.env);
    this.emit({
      status: 'starting',
      url: null,
      version: null,
      detail: 'selecting backend binary',
      harness,
      binary: null,
      rejected: [],
      problem: null,
    });

    const selection = await this.selectBinary(spawnContext.cwd);
    if (stale()) return false;
    if (!selection.ok) {
      this.emit({
        status: 'failed',
        detail: selection.message,
        rejected: selection.rejected,
        problem: selection.problem,
      });
      return false;
    }
    const { binary, rejected } = selection;
    const skipped = rejected.length ? `; skipped ${describeRejected(rejected)}` : '';

    let port = 0;
    try {
      port = await pickFreePort();
    } catch (error) {
      this.emit({
        status: 'failed',
        detail: `no free localhost port: ${String(error)}`,
        binary,
        rejected,
        problem: 'port',
      });
      return false;
    }
    if (stale()) return false;
    const url = `http://127.0.0.1:${port}`;
    this.emit({ url, detail: `launching ${describeBinary(binary)}${skipped}`, binary, rejected });

    // No --auth-token on argv: it would expose the secret in ps output.
    // The child inherits AGENT_TOOLKIT_TOKEN through env, which serve reads.
    // serve roots its jobs dir and containment at cwd, so cwd is the harness.
    const args = ['serve', '--host', '127.0.0.1', '--port', String(port), '--no-browser'];
    const environmentSecrets = this.resolveEnvironmentSecrets();
    const secretValues = Object.values(environmentSecrets);
    const child = this.spawnProcess(binary.path, args, {
      stdio: ['ignore', 'pipe', 'pipe'],
      cwd: spawnContext.cwd,
      env: { ...spawnContext.env, ...environmentSecrets, NO_COLOR: '1', TERM: 'dumb' },
      windowsHide: true,
    });
    this.proc = child;
    let ready = false;
    let exitedEarly = false;

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
      if (this.proc !== child) return;
      this.proc = null;
      if (stale()) return;
      exitedEarly = !ready;
      const tail = redactSecrets(stderrTail, secretValues).trim().slice(-200);
      const how = `code=${code ?? 'null'} signal=${signal ?? 'null'}`;
      this.emit(
        ready
          ? {
              status: 'crashed',
              problem: 'exited',
              detail: `backend ${describeBinary(binary)} exited ${how}` + (tail ? ` stderr: ${tail}` : ''),
            }
          : {
              status: 'failed',
              problem: 'exited-during-start',
              detail:
                `backend ${describeBinary(binary)} exited during startup ${how}` + (tail ? ` stderr: ${tail}` : ''),
            },
      );
    });
    child.on('error', (error) => {
      if (this.proc !== child) return;
      this.proc = null;
      if (stale()) return;
      exitedEarly = true;
      this.emit({
        status: 'failed',
        problem: 'spawn-error',
        detail:
          `cannot launch backend ${binary.path}` +
          (spawnContext.cwd ? ` in harness ${spawnContext.cwd}` : '') +
          `: ${error.message}`,
      });
    });

    const deadline = Date.now() + this.startTimeoutMs;
    let health: HealthPayload | null = null;
    while (Date.now() < deadline) {
      if (this.proc !== child || stale()) break;
      health = await fetchHealth(url);
      if (health?.ok) break;
      await new Promise((r) => setTimeout(r, POLL_INTERVAL_MS));
    }
    if (stale() || exitedEarly || this.proc !== child) return false;
    if (!health?.ok) {
      await this.killChild();
      if (!stale()) {
        this.emit({
          status: 'failed',
          problem: 'health-timeout',
          detail: `backend ${describeBinary(binary)} did not answer /api/v1/health within ${Math.round(this.startTimeoutMs / 1000)} s`,
        });
      }
      return false;
    }

    const pin = this.resolvePin();
    if (pin && majorOf(health.version) !== pin.major) {
      ready = true;
      this.emit({
        status: 'version-mismatch',
        problem: 'major-mismatch',
        version: health.version,
        detail: `backend ${binary.path} reports ${health.version}; this Desktop build needs major ${pin.major} (${pin.source} = ${pin.version}). Reinstall or set ATK_BACKEND_BIN.`,
      });
      return false;
    }
    const gate = await this.probeGate(url);
    if (stale() || this.proc !== child) return false;
    ready = true;
    if (gate === 'missing') {
      this.emit({
        status: 'version-mismatch',
        problem: 'desktop-gate-missing',
        version: health.version,
        detail: `backend ${describeBinary(binary)} predates the X-Atk-Desktop first-party gate: reads work, but jobs, installs and other Desktop actions are rejected with 403. Set ATK_BACKEND_BIN to a newer build, or put one first on PATH.`,
      });
      return false;
    }
    this.emit({
      status: 'ready',
      version: health.version,
      problem: null,
      detail:
        `backend ${health.version} via ${binary.source} ${binary.path}` +
        (pin === null ? ' (no staged version pin; set ATK_EXPECTED_BACKEND_MAJOR to enforce)' : '') +
        (gate === 'unknown' ? ' (Desktop gate probe inconclusive)' : '') +
        skipped,
    });
    return true;
  }

  async restart(): Promise<boolean> {
    this.state.restarts += 1;
    await this.stop();
    return this.start();
  }

  async stop(): Promise<void> {
    this.generation += 1;
    this.starting = null;
    await this.killChild();
    this.emit({ status: 'stopped', url: null, version: null, detail: null, problem: null });
  }

  private async killChild(): Promise<void> {
    const child = this.proc;
    this.proc = null;
    if (!child || child.exitCode !== null || child.signalCode !== null) return;
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
        child.kill('SIGTERM');
      } catch {
        clearTimeout(timer);
        resolve();
      }
    });
  }
}
