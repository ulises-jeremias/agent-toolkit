import { execFile } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import type { FocusModelOption, FocusProviderId, FocusProviderStatus } from '../../src/types/focus';
import { needsShell } from './adapter';

/**
 * Provider discovery for Focus. "Ready" is only ever claimed from the
 * provider CLI's own account status command; presence on PATH alone is
 * reported as installed-but-unknown. Account identifiers (email, org) are
 * deliberately dropped before anything reaches the renderer.
 */

export type CommandRunner = (
  binary: string,
  args: string[],
  timeoutMs: number,
) => Promise<{ code: number | null; stdout: string; stderr: string }>;

// Generous: a cold binary on a memory-pressured machine can take >20 s to page in.
const PROBE_TIMEOUT_MS = 45_000;

export const runCommand: CommandRunner = (binary, args, timeoutMs) =>
  new Promise((resolve) => {
    try {
      execFile(
        binary,
        args,
        {
          timeout: timeoutMs,
          killSignal: 'SIGKILL',
          maxBuffer: 1024 * 1024,
          windowsHide: true,
          shell: needsShell(binary),
        },
        (error, stdout, stderr) => {
          const code = error ? (typeof error.code === 'number' ? error.code : null) : 0;
          resolve({ code, stdout: String(stdout), stderr: String(stderr) });
        },
      );
    } catch (error) {
      // A spawn that throws (for example an unrunnable shim) is a failed probe, not a crash.
      resolve({ code: null, stdout: '', stderr: error instanceof Error ? error.message : String(error) });
    }
  });

function isExecutable(file: string): boolean {
  try {
    fs.accessSync(file, fs.constants.X_OK);
    return fs.statSync(file).isFile();
  } catch {
    return false;
  }
}

/** PATH plus the places CLIs install themselves when the app is started from a launcher with a bare PATH. */
export function searchDirs(env: NodeJS.ProcessEnv, home = os.homedir()): string[] {
  const dirs = (env['PATH'] ?? '').split(path.delimiter).filter(Boolean);
  const extra = [
    path.join(home, '.local', 'bin'),
    path.join(home, '.claude', 'local'),
    path.join(home, '.bun', 'bin'),
    path.join(home, '.npm-global', 'bin'),
    path.join(home, '.opencode', 'bin'),
    '/usr/local/bin',
    '/opt/homebrew/bin',
    '/usr/bin',
  ];
  for (const dir of extra) if (!dirs.includes(dir)) dirs.push(dir);
  return dirs;
}

export function findBinary(name: string, env: NodeJS.ProcessEnv = process.env): string | null {
  const names = process.platform === 'win32' ? [`${name}.exe`, `${name}.cmd`, name] : [name];
  for (const dir of searchDirs(env)) {
    for (const candidate of names) {
      const file = path.join(dir, candidate);
      if (isExecutable(file)) return file;
    }
  }
  return null;
}

const CLAUDE_MODELS: FocusModelOption[] = [
  { id: 'default', label: 'Default', description: 'The model your Claude Code account defaults to' },
  { id: 'opus', label: 'Opus' },
  { id: 'sonnet', label: 'Sonnet' },
  { id: 'haiku', label: 'Haiku' },
];

interface ProviderSpec {
  id: FocusProviderId;
  label: string;
  binary: string;
  signIn: string;
  sessions: boolean;
  models: FocusModelOption[];
  auth: (binary: string, run: CommandRunner) => Promise<Pick<FocusProviderStatus, 'auth' | 'authDetail'>>;
}

function versionOf(output: string): string | null {
  return /\d+\.\d+\.\d+[\w.-]*/.exec(output)?.[0] ?? null;
}

async function claudeAuth(
  binary: string,
  run: CommandRunner,
): Promise<Pick<FocusProviderStatus, 'auth' | 'authDetail'>> {
  const result = await run(binary, ['auth', 'status', '--json'], PROBE_TIMEOUT_MS);
  try {
    const status = JSON.parse(result.stdout) as {
      loggedIn?: unknown;
      authMethod?: unknown;
      subscriptionType?: unknown;
    };
    if (status.loggedIn === true) {
      const plan = typeof status.subscriptionType === 'string' ? ` (${status.subscriptionType})` : '';
      const method = status.authMethod === 'claude.ai' ? `Claude subscription${plan}` : 'an API account';
      return { auth: 'ready', authDetail: `Signed in with ${method}` };
    }
    if (status.loggedIn === false) return { auth: 'signed-out', authDetail: 'Not signed in' };
  } catch {
    // Older CLIs print text; fall through.
  }
  return { auth: 'unknown', authDetail: 'Could not read the account status from this Claude Code version' };
}

async function codexAuth(
  binary: string,
  run: CommandRunner,
): Promise<Pick<FocusProviderStatus, 'auth' | 'authDetail'>> {
  const result = await run(binary, ['login', 'status'], PROBE_TIMEOUT_MS);
  const text = `${result.stdout}\n${result.stderr}`;
  if (/not logged in/i.test(text)) return { auth: 'signed-out', authDetail: 'Not signed in' };
  if (result.code === 0 && /logged in/i.test(text)) {
    const method = /chatgpt/i.test(text) ? 'ChatGPT' : /api key/i.test(text) ? 'an API key' : 'Codex';
    return { auth: 'ready', authDetail: `Signed in with ${method}` };
  }
  return { auth: 'unknown', authDetail: 'Could not read the login status from this Codex version' };
}

async function opencodeAuth(
  binary: string,
  run: CommandRunner,
): Promise<Pick<FocusProviderStatus, 'auth' | 'authDetail'>> {
  const result = await run(binary, ['auth', 'list'], PROBE_TIMEOUT_MS);
  const text = `${result.stdout}\n${result.stderr}`;
  if (/no authenticated integrations|\b0 credentials/i.test(text)) {
    return { auth: 'signed-out', authDetail: 'No model provider connected' };
  }
  if (result.code === 0 && text.trim()) return { auth: 'ready', authDetail: 'A model provider is connected' };
  return { auth: 'unknown', authDetail: 'Could not read the connected providers from this OpenCode version' };
}

const SPECS: ProviderSpec[] = [
  {
    id: 'claude',
    label: 'Claude Code',
    binary: 'claude',
    signIn: 'claude auth login',
    sessions: true,
    models: CLAUDE_MODELS,
    auth: claudeAuth,
  },
  { id: 'codex', label: 'Codex', binary: 'codex', signIn: 'codex login', sessions: false, models: [], auth: codexAuth },
  {
    id: 'opencode',
    label: 'OpenCode',
    binary: 'opencode',
    signIn: 'opencode auth login',
    sessions: false,
    models: [],
    auth: opencodeAuth,
  },
];

export interface ProbeOptions {
  env?: NodeJS.ProcessEnv;
  run?: CommandRunner;
  find?: (name: string) => string | null;
  /** Provider ids with a structured session adapter registered at runtime. */
  supported?: ReadonlySet<FocusProviderId>;
}

async function probeOne(spec: ProviderSpec, options: ProbeOptions): Promise<FocusProviderStatus> {
  const run = options.run ?? runCommand;
  const find = options.find ?? ((name: string) => findBinary(name, options.env));
  const sessions = options.supported ? options.supported.has(spec.id) : spec.sessions;
  const base: FocusProviderStatus = {
    id: spec.id,
    label: spec.label,
    installed: false,
    binary: null,
    version: null,
    auth: 'unknown',
    authDetail: 'Not installed',
    signInHint: null,
    models: spec.models,
    capabilities: {
      sessions,
      approvals: sessions,
      interrupt: sessions,
      resume: sessions,
      modelSwitch: sessions,
      sendWhileRunning: sessions && spec.id === 'claude',
    },
    checkedAt: new Date().toISOString(),
  };
  const binary = find(spec.binary);
  if (!binary) return base;
  const [version, auth] = await Promise.all([
    run(binary, ['--version'], PROBE_TIMEOUT_MS),
    spec.auth(binary, run).catch(() => ({ auth: 'unknown' as const, authDetail: 'Account status check failed' })),
  ]);
  return {
    ...base,
    installed: true,
    binary,
    version: versionOf(`${version.stdout}\n${version.stderr}`),
    ...auth,
    signInHint: auth.auth === 'ready' ? null : spec.signIn,
  };
}

export function probeProviders(options: ProbeOptions = {}): Promise<FocusProviderStatus[]> {
  return Promise.all(
    SPECS.map((spec) =>
      probeOne(spec, options).catch(
        // One provider that cannot be probed never hides the others.
        (): FocusProviderStatus => ({
          id: spec.id,
          label: spec.label,
          installed: false,
          binary: null,
          version: null,
          auth: 'unknown',
          authDetail: 'Could not be checked',
          signInHint: null,
          models: spec.models,
          capabilities: { sessions: false, approvals: false, interrupt: false, resume: false, modelSwitch: false },
          checkedAt: new Date().toISOString(),
        }),
      ),
    ),
  );
}
