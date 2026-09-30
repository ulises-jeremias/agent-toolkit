import { execFile } from 'node:child_process';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';

/**
 * Where a backend candidate came from, in selection order:
 * - `env`: ATK_BACKEND_BIN (explicit; authoritative, no fall-through)
 * - `bundled`: `<resourcesPath>/bin` of a packaged app (authoritative)
 * - `staged`: `apps/desktop/resources/bin` written by `pnpm stage:backend` (dev)
 * - `path`: every `agent-toolkit` on PATH, in PATH order
 */
export type BackendBinarySource = 'env' | 'bundled' | 'staged' | 'path';

export interface BackendCandidate {
  path: string;
  source: BackendBinarySource;
  /** A rejected authoritative candidate stops selection instead of falling through. */
  authoritative: boolean;
}

export interface BackendBinaryInfo {
  path: string;
  source: BackendBinarySource;
  /** From `--version`; null only when the probe could not read one. */
  version: string | null;
}

export interface RejectedBackendBinary extends BackendBinaryInfo {
  reason: string;
}

export type BinarySelection =
  | { ok: true; binary: BackendBinaryInfo; rejected: RejectedBackendBinary[] }
  | { ok: false; problem: 'no-backend' | 'binary-rejected'; message: string; rejected: RejectedBackendBinary[] };

/** Version pin the running backend must match (see `resolveBackendPin`). */
export interface BackendPin {
  major: string;
  version: string;
  source: 'ATK_EXPECTED_BACKEND_MAJOR' | 'backend-version.json';
}

export interface RunResult {
  code: number | null;
  stdout: string;
  stderr: string;
  error: string | null;
}

export type RunBinary = (bin: string, args: string[], cwd: string | undefined) => Promise<RunResult>;

const PROBE_TIMEOUT_MS = 5_000;

export function backendExeName(platform: NodeJS.Platform = process.platform): string {
  return platform === 'win32' ? 'agent-toolkit.exe' : 'agent-toolkit';
}

export function electronResourcesPath(): string {
  const value = (process as NodeJS.Process & { resourcesPath?: unknown }).resourcesPath;
  return typeof value === 'string' ? value : '';
}

/** Dirs that may hold `backend-version.json`: packaged resources, then the dev app dir. */
export function candidateResourceDirs(resourcesPath: string = electronResourcesPath()): string[] {
  const dirs: string[] = [];
  if (resourcesPath) dirs.push(resourcesPath);
  // Dev layout: compiled main lives in apps/desktop/dist-electron.
  dirs.push(path.resolve(__dirname, '..', 'resources'));
  return dirs;
}

export function majorOf(version: string): string {
  return version.replace(/^v/, '').split('.')[0] ?? '';
}

/**
 * The pin written by `stage-backend` (`resources/backend-version.json`), or
 * the ATK_EXPECTED_BACKEND_MAJOR override. Null when neither exists (dev
 * without staging): callers must say so instead of comparing against itself.
 */
export function resolveBackendPin(
  env: NodeJS.ProcessEnv = process.env,
  dirs: string[] = candidateResourceDirs(),
): BackendPin | null {
  const override = env.ATK_EXPECTED_BACKEND_MAJOR?.trim();
  if (override) {
    const version = override.replace(/^v/, '');
    return { major: majorOf(version), version, source: 'ATK_EXPECTED_BACKEND_MAJOR' };
  }
  for (const dir of dirs) {
    try {
      const parsed = JSON.parse(fs.readFileSync(path.join(dir, 'backend-version.json'), 'utf8')) as {
        version?: unknown;
      };
      if (typeof parsed.version === 'string' && parsed.version.trim()) {
        const version = parsed.version.trim().replace(/^v/, '');
        return { major: majorOf(version), version, source: 'backend-version.json' };
      }
    } catch {
      // Missing or unreadable pin in this dir; try the next.
    }
  }
  return null;
}

export interface CandidateInputs {
  env: NodeJS.ProcessEnv;
  resourcesPath: string;
  /** Dev staging dir (`apps/desktop/resources/bin`). */
  stagedDir: string;
  platform: NodeJS.Platform;
  exists: (file: string) => boolean;
  realpath: (file: string) => string;
}

export function defaultCandidateInputs(): CandidateInputs {
  return {
    env: process.env,
    resourcesPath: electronResourcesPath(),
    stagedDir: path.resolve(__dirname, '..', 'resources', 'bin'),
    platform: process.platform,
    exists: (file) => fs.existsSync(file),
    realpath: (file) => {
      try {
        return fs.realpathSync(file);
      } catch {
        return file;
      }
    },
  };
}

/** Ordered, de-duplicated candidates. Pure over its inputs. */
export function listBackendCandidates(inputs: CandidateInputs): BackendCandidate[] {
  const exe = backendExeName(inputs.platform);
  const explicit = inputs.env.ATK_BACKEND_BIN?.trim();
  if (explicit) return [{ path: path.resolve(explicit), source: 'env', authoritative: true }];
  if (inputs.resourcesPath) {
    const bundled = path.join(inputs.resourcesPath, 'bin', exe);
    if (inputs.exists(bundled)) return [{ path: bundled, source: 'bundled', authoritative: true }];
  }
  const candidates: BackendCandidate[] = [];
  const seen = new Set<string>();
  const push = (file: string, source: BackendBinarySource): void => {
    const key = inputs.realpath(file);
    if (seen.has(key)) return;
    seen.add(key);
    candidates.push({ path: file, source, authoritative: false });
  };
  const staged = path.join(inputs.stagedDir, exe);
  if (inputs.exists(staged)) push(staged, 'staged');
  const sep = inputs.platform === 'win32' ? ';' : ':';
  for (const dir of (inputs.env.PATH ?? '').split(sep)) {
    if (!dir) continue;
    // Absolute: serve is spawned with the harness as cwd, so a relative PATH
    // entry must not be re-resolved against it.
    const file = path.resolve(dir, exe);
    if (inputs.exists(file)) push(file, 'path');
  }
  return candidates;
}

export const runBinary: RunBinary = (bin, args, cwd) =>
  new Promise((resolve) => {
    execFile(
      bin,
      args,
      {
        cwd,
        timeout: PROBE_TIMEOUT_MS,
        maxBuffer: 256 * 1024,
        encoding: 'utf8',
        env: { ...process.env, NO_COLOR: '1', TERM: 'dumb' },
        windowsHide: true,
      },
      (error, stdout, stderr) => {
        const out = { stdout: String(stdout ?? ''), stderr: String(stderr ?? '') };
        if (!error) {
          resolve({ code: 0, ...out, error: null });
          return;
        }
        // Non-zero exit: `code` is the exit status. Spawn failure: `code` is
        // an errno string. Timeout: the child was killed.
        const failure = error as Error & { code?: unknown; killed?: boolean };
        if (typeof failure.code === 'number') {
          resolve({ code: failure.code, ...out, error: null });
          return;
        }
        resolve({
          code: null,
          ...out,
          error: failure.killed ? `timed out after ${PROBE_TIMEOUT_MS} ms` : failure.message,
        });
      },
    );
  });

export function isExecutableFile(file: string): boolean {
  try {
    if (!fs.statSync(file).isFile()) return false;
    fs.accessSync(file, fs.constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function firstLine(text: string): string {
  return text.trim().split('\n')[0]?.trim().slice(0, 160) ?? '';
}

/** `agent-toolkit 1.35.0` -> `1.35.0`. */
export function parseVersionOutput(stdout: string): string | null {
  for (const token of stdout.trim().split(/\s+/).reverse()) {
    if (/^v?\d+\.\d+(\.\d+)?([-+][\w.-]+)?$/.test(token)) return token.replace(/^v/, '');
  }
  return null;
}

export interface ProbeOptions {
  pin: BackendPin | null;
  run: RunBinary;
  cwd: string | undefined;
  isExecutable: (file: string) => boolean;
}

/** Pre-spawn compatibility probe. Returns a reason when the candidate cannot run Desktop's serve. */
export async function probeBackendCandidate(
  candidate: BackendCandidate,
  options: ProbeOptions,
): Promise<{ version: string | null; reason: string | null }> {
  if (!options.isExecutable(candidate.path)) {
    return { version: null, reason: 'not an executable file' };
  }
  const versionRun = await options.run(candidate.path, ['--version'], options.cwd);
  if (versionRun.error || versionRun.code !== 0) {
    return {
      version: null,
      reason: `\`--version\` failed (${versionRun.error ?? `exit ${versionRun.code}`}${
        firstLine(versionRun.stderr || versionRun.stdout) ? `: ${firstLine(versionRun.stderr || versionRun.stdout)}` : ''
      })`,
    };
  }
  const version = parseVersionOutput(versionRun.stdout);
  if (!version) return { version: null, reason: `\`--version\` printed no version (${firstLine(versionRun.stdout)})` };
  if (options.pin && majorOf(version) !== options.pin.major) {
    return {
      version,
      reason: `major ${majorOf(version)} does not match this Desktop build, which needs major ${options.pin.major} (${options.pin.source} = ${options.pin.version})`,
    };
  }
  const serveRun = await options.run(candidate.path, ['serve', '--help'], options.cwd);
  const serveText = `${serveRun.stdout}\n${serveRun.stderr}`;
  if (serveRun.error || serveRun.code !== 0 || !/agent-toolkit serve/.test(serveText)) {
    return {
      version,
      reason: `too old: has no \`serve\` command (\`serve --help\`: ${
        serveRun.error ?? (firstLine(serveRun.stderr || serveRun.stdout) || `exit ${serveRun.code}`)
      })`,
    };
  }
  return { version, reason: null };
}

export function describeRejected(rejected: RejectedBackendBinary[]): string {
  return rejected
    .map((entry) => `${entry.path} (${entry.source}${entry.version ? `, ${entry.version}` : ''}): ${entry.reason}`)
    .join('; ');
}

const FIX_HINT = 'Set ATK_BACKEND_BIN to a current agent-toolkit build, or put one first on PATH.';

/**
 * Pick the backend deterministically: the first candidate that passes the
 * probe. Authoritative candidates (ATK_BACKEND_BIN, bundled) never fall
 * through to PATH, so a packaged app cannot silently run a foreign binary.
 */
export async function selectBackendBinary(
  candidates: BackendCandidate[],
  options: ProbeOptions,
): Promise<BinarySelection> {
  if (!candidates.length) {
    return {
      ok: false,
      problem: 'no-backend',
      message: `No agent-toolkit backend found (no ATK_BACKEND_BIN, no bundled or staged backend, none on PATH). Install agent-toolkit or set ATK_BACKEND_BIN.`,
      rejected: [],
    };
  }
  const rejected: RejectedBackendBinary[] = [];
  for (const candidate of candidates) {
    const probe = await probeBackendCandidate(candidate, options);
    if (!probe.reason) {
      return { ok: true, binary: { path: candidate.path, source: candidate.source, version: probe.version }, rejected };
    }
    rejected.push({ path: candidate.path, source: candidate.source, version: probe.version, reason: probe.reason });
    if (candidate.authoritative) {
      const hint =
        candidate.source === 'env'
          ? 'Fix or unset ATK_BACKEND_BIN.'
          : 'The bundled backend is stale or damaged; reinstall Agent Toolkit Desktop.';
      return {
        ok: false,
        problem: 'binary-rejected',
        message: `Backend ${describeRejected([rejected[rejected.length - 1]!])}. ${hint}`,
        rejected,
      };
    }
  }
  return {
    ok: false,
    problem: 'binary-rejected',
    message: `No compatible agent-toolkit backend. Rejected ${describeRejected(rejected)}. ${FIX_HINT}`,
    rejected,
  };
}

export type DesktopGateProbe = 'present' | 'missing' | 'unknown';

/**
 * Post-spawn capability probe for the X-Atk-Desktop first-party gate.
 * Sends what Chromium sends from `file://` (Sec-Fetch-Site: cross-site) plus
 * the Desktop header to `POST /api/v1/jobs` with an empty body: a gate-aware
 * serve answers 422 (`cmd is required`, nothing created); a pre-gate serve
 * answers 403 `cross-site request forbidden` for every Desktop mutation.
 */
export function probeDesktopGate(url: string, timeoutMs = 3_000): Promise<DesktopGateProbe> {
  return new Promise((resolve) => {
    let target: URL;
    try {
      target = new URL('/api/v1/jobs', url);
    } catch {
      resolve('unknown');
      return;
    }
    const body = '{}';
    const req = http.request(
      target,
      {
        method: 'POST',
        timeout: timeoutMs,
        headers: {
          'content-type': 'application/json',
          'content-length': Buffer.byteLength(body),
          'sec-fetch-site': 'cross-site',
          'x-atk-desktop': '1',
        },
      },
      (res) => {
        let text = '';
        res.setEncoding('utf8');
        res.on('data', (chunk: string) => {
          text = (text + chunk).slice(0, 2048);
        });
        res.on('end', () => {
          if (res.statusCode === 403 && /cross-site/i.test(text)) resolve('missing');
          else if (res.statusCode && res.statusCode !== 403) resolve('present');
          else resolve('unknown');
        });
        res.on('error', () => resolve('unknown'));
      },
    );
    req.on('timeout', () => {
      req.destroy();
      resolve('unknown');
    });
    req.on('error', () => resolve('unknown'));
    req.end(body);
  });
}
