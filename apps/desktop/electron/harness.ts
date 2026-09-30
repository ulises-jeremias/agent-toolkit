import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

export type HarnessSource = 'default' | 'override' | 'fallback';

/**
 * Where the supervised `agent-toolkit serve` is rooted. `path` is the
 * directory serve runs in; for `default`/`override` it is also exported as
 * AGENT_TOOLKIT_WORKSPACE so core `find_workspace_root` agrees with the
 * cwd-rooted jobs dir and containment checks.
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
}

export function isDirectory(candidate: string): boolean {
  try {
    return fs.statSync(candidate).isDirectory();
  } catch {
    return false;
  }
}

function expandHome(value: string, homeDir: string): string {
  if (value === '~') return homeDir;
  if (value.startsWith('~/') || value.startsWith('~\\')) return path.join(homeDir, value.slice(2));
  return value;
}

/**
 * Resolve the Desktop harness. Never creates directories: Agent Toolkit must
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
  if (inputs.isDirectory(defaultPath)) {
    return { path: defaultPath, source: 'default', defaultPath, overrideVar: null, notice: null };
  }
  return {
    path: inputs.cwd,
    source: 'fallback',
    defaultPath,
    overrideVar: null,
    notice: `Default harness ${defaultPath} not found; serve starts in ${inputs.cwd} and resolves its workspace by walking up from there`,
  };
}

export function resolveHarnessFromProcess(): HarnessResolution {
  return resolveHarness({ env: process.env, homeDir: os.homedir(), cwd: process.cwd(), isDirectory });
}

/** cwd + env for the serve child. Fallback leaves both untouched (prior behavior). */
export function harnessSpawnContext(
  harness: HarnessResolution,
  baseEnv: NodeJS.ProcessEnv,
): { cwd: string | undefined; env: NodeJS.ProcessEnv } {
  if (harness.source === 'fallback') return { cwd: undefined, env: { ...baseEnv } };
  return { cwd: harness.path, env: { ...baseEnv, AGENT_TOOLKIT_WORKSPACE: harness.path } };
}
