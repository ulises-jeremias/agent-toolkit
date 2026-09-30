import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

export type HarnessSource = 'override' | 'user' | 'default' | 'fallback';

/**
 * Where the supervised `agent-toolkit serve` is rooted. `path` is the
 * directory serve runs in; for every source except `fallback` it is also
 * exported as AGENT_TOOLKIT_WORKSPACE so core `find_workspace_root` agrees
 * with the cwd-rooted jobs dir and containment checks.
 */
export interface HarnessResolution {
  path: string;
  source: HarnessSource;
  /** The designed default, `~/.ai-workspace`, expanded for this OS user. */
  defaultPath: string;
  /** Env var that supplied (or failed to supply) the override. */
  overrideVar: string | null;
  /** Honest explanation whenever the default or an override was not used. */
  notice: string | null;
}

/** Same order core `find_workspace_root` reads (docs/compatibility/env-precedence.md). */
export const HARNESS_OVERRIDE_VARS = ['AGENT_TOOLKIT_WORKSPACE', 'HARNESS_DIR'] as const;

export interface HarnessInputs {
  env: NodeJS.ProcessEnv;
  homeDir: string;
  cwd: string;
  isDirectory: (candidate: string) => boolean;
  /** Harness persisted by a Desktop switch (absolute), if any. */
  userChoice?: string | null;
}

export function isDirectory(candidate: string): boolean {
  try {
    return fs.statSync(candidate).isDirectory();
  } catch {
    return false;
  }
}

export function expandHome(value: string, homeDir: string): string {
  if (value === '~') return homeDir;
  if (value.startsWith('~/') || value.startsWith('~\\')) return path.join(homeDir, value.slice(2));
  return value;
}

/** True when `raw` expands to this user's designed default, `~/.ai-workspace`. */
export function isDefaultHarnessPath(raw: string, homeDir: string = os.homedir()): boolean {
  const trimmed = raw.trim();
  if (!trimmed) return false;
  return path.resolve(expandHome(trimmed, homeDir)) === path.join(homeDir, '.ai-workspace');
}

/**
 * Resolve the Desktop harness: env override > persisted user choice >
 * `~/.ai-workspace` > fallback. Never creates directories: Agent Toolkit must
 * stay usable without My AI Workspace, so a missing default or a broken
 * override falls back to the pre-default behavior (serve inherits the
 * Desktop process cwd and resolves its workspace from there).
 */
export function resolveHarness(inputs: HarnessInputs): HarnessResolution {
  const defaultPath = path.join(inputs.homeDir, '.ai-workspace');
  const rejected: string[] = [];
  for (const name of HARNESS_OVERRIDE_VARS) {
    const raw = inputs.env[name]?.trim();
    if (!raw) continue;
    const candidate = path.resolve(inputs.cwd, expandHome(raw, inputs.homeDir));
    if (inputs.isDirectory(candidate)) {
      return {
        path: candidate,
        source: 'override',
        defaultPath,
        overrideVar: name,
        notice: rejected.length ? `ignored ${rejected.join(', ')}` : null,
      };
    }
    rejected.push(`${name}=${raw} (not a directory)`);
  }
  if (rejected.length) {
    return {
      path: inputs.cwd,
      source: 'fallback',
      defaultPath,
      overrideVar: HARNESS_OVERRIDE_VARS.find((name) => inputs.env[name]?.trim()) ?? null,
      notice: `Harness override ${rejected.join(', ')}; serve starts in ${inputs.cwd} and resolves its workspace by walking up from there`,
    };
  }
  // A saved choice that vanished (unmounted drive, deleted folder) is kept on
  // disk so it wins again once it is back; this start uses the next tier.
  let staleChoice: string | null = null;
  const choice = inputs.userChoice?.trim();
  if (choice) {
    if (inputs.isDirectory(choice)) {
      return { path: choice, source: 'user', defaultPath, overrideVar: null, notice: null };
    }
    staleChoice = `Saved harness ${choice} is not a directory`;
  }
  if (inputs.isDirectory(defaultPath)) {
    return {
      path: defaultPath,
      source: 'default',
      defaultPath,
      overrideVar: null,
      notice: staleChoice ? `${staleChoice}; using the default ${defaultPath}` : null,
    };
  }
  return {
    path: inputs.cwd,
    source: 'fallback',
    defaultPath,
    overrideVar: null,
    notice:
      (staleChoice ? `${staleChoice}. ` : '') +
      `Default harness ${defaultPath} not found; serve starts in ${inputs.cwd} and resolves its workspace by walking up from there`,
  };
}

export function resolveHarnessFromProcess(userChoice: string | null = null): HarnessResolution {
  return resolveHarness({ env: process.env, homeDir: os.homedir(), cwd: process.cwd(), isDirectory, userChoice });
}

/** First override var set to a non-blank value: while set, Desktop cannot switch the harness. */
export function activeOverrideVar(env: NodeJS.ProcessEnv): (typeof HARNESS_OVERRIDE_VARS)[number] | null {
  return HARNESS_OVERRIDE_VARS.find((name) => env[name]?.trim()) ?? null;
}

export type HarnessPathError = 'invalid-path' | 'not-found' | 'not-a-directory' | 'not-accessible';

export type HarnessPathCheck = { ok: true; path: string } | { ok: false; error: HarnessPathError; message: string };

const MAX_PATH_LENGTH = 4096;

/**
 * Validate a harness path coming from the renderer or a native dialog.
 * Requires an absolute (or `~`) path to an existing directory serve can
 * read and write (it writes `<harness>/.agent-toolkit/server`). Never creates
 * anything.
 */
export function validateHarnessPath(raw: unknown, homeDir: string = os.homedir()): HarnessPathCheck {
  if (typeof raw !== 'string' || !raw.trim()) {
    return { ok: false, error: 'invalid-path', message: 'Harness path must be a non-empty string' };
  }
  const value = raw.trim();
  if (value.length > MAX_PATH_LENGTH || value.includes('\0')) {
    return { ok: false, error: 'invalid-path', message: 'Harness path is too long or contains a NUL byte' };
  }
  const expanded = expandHome(value, homeDir);
  if (!path.isAbsolute(expanded)) {
    return { ok: false, error: 'invalid-path', message: `Harness path must be absolute: ${value}` };
  }
  const resolved = path.resolve(expanded);
  let stat: fs.Stats;
  try {
    stat = fs.statSync(resolved);
  } catch {
    return { ok: false, error: 'not-found', message: `${resolved} does not exist` };
  }
  if (!stat.isDirectory()) {
    return { ok: false, error: 'not-a-directory', message: `${resolved} is not a directory` };
  }
  try {
    fs.accessSync(resolved, fs.constants.R_OK | fs.constants.W_OK | fs.constants.X_OK);
  } catch {
    return {
      ok: false,
      error: 'not-accessible',
      message: `${resolved} is not readable and writable by this user (serve writes .agent-toolkit/server there)`,
    };
  }
  return { ok: true, path: resolved };
}

export interface HarnessMutationResult {
  ok: boolean;
  path: string;
  created: boolean;
  error: string | null;
}

/**
 * Create the default harness directory only. Does not scaffold files — that
 * is `workspace init` after serve is re-rooted here. Never called unless
 * the renderer confirmed.
 */
export function createDefaultHarnessDirectory(inputs: {
  homeDir: string;
  isDirectory: (candidate: string) => boolean;
  mkdir: (candidate: string) => void;
}): HarnessMutationResult {
  const defaultPath = path.join(inputs.homeDir, '.ai-workspace');
  if (inputs.isDirectory(defaultPath)) {
    return { ok: true, path: defaultPath, created: false, error: null };
  }
  try {
    inputs.mkdir(defaultPath);
  } catch (error) {
    return {
      ok: false,
      path: defaultPath,
      created: false,
      error: error instanceof Error ? error.message : String(error),
    };
  }
  if (!inputs.isDirectory(defaultPath)) {
    return {
      ok: false,
      path: defaultPath,
      created: false,
      error: `created ${defaultPath} but it is not a directory`,
    };
  }
  return { ok: true, path: defaultPath, created: true, error: null };
}

export function createDefaultHarnessFromProcess(): HarnessMutationResult {
  return createDefaultHarnessDirectory({
    homeDir: os.homedir(),
    isDirectory,
    mkdir: (candidate) => fs.mkdirSync(candidate, { recursive: true }),
  });
}

/** cwd + env for the serve child. Fallback leaves both untouched (prior behavior). */
export function harnessSpawnContext(
  harness: HarnessResolution,
  baseEnv: NodeJS.ProcessEnv,
): { cwd: string | undefined; env: NodeJS.ProcessEnv } {
  if (harness.source === 'fallback') return { cwd: undefined, env: { ...baseEnv } };
  return { cwd: harness.path, env: { ...baseEnv, AGENT_TOOLKIT_WORKSPACE: harness.path } };
}
