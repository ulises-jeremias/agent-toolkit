import os from 'node:os';
import type { BackendState } from './backend';
import {
  activeOverrideVar,
  isDirectory,
  resolveHarness,
  validateHarnessPath,
  type HarnessPathError,
  type HarnessResolution,
} from './harness';
import type { HarnessStore } from './harness-store';

export interface HarnessRecentEntry {
  path: string;
  /** Checked at call time; a missing entry stays listed so the user can see what vanished. */
  exists: boolean;
  /** True for the persisted Desktop choice. */
  current: boolean;
}

export interface HarnessStatus {
  /** What the next backend start resolves to (may differ from the running backend mid-switch). */
  resolution: HarnessResolution;
  recent: HarnessRecentEntry[];
  switching: boolean;
  /** Env var that pins the harness; while non-null, Desktop switching is refused. */
  lockedBy: string | null;
}

export type HarnessSwitchError =
  | HarnessPathError
  | 'cancelled'
  | 'env-override'
  | 'busy'
  | 'persist-failed'
  | 'unavailable';

export type HarnessSwitchResult =
  | { ok: true; restarted: boolean; harness: HarnessResolution; backend: BackendState }
  | { ok: false; error: HarnessSwitchError; message: string };

export interface HarnessSupervisor {
  restart: () => Promise<boolean>;
  snapshot: () => BackendState;
}

export interface HarnessControllerDeps {
  store: HarnessStore;
  getSupervisor: () => HarnessSupervisor | null;
  env?: () => NodeJS.ProcessEnv;
  homeDir?: string;
  cwd?: () => string;
  isDirectory?: (candidate: string) => boolean;
  /** Native folder picker; resolves null on cancel. */
  chooseDirectory?: (defaultPath: string) => Promise<string | null>;
}

/**
 * Runtime harness switching. Serve is cwd-rooted, so one backend serves one
 * harness: a switch persists the choice, then restarts the supervised
 * backend (stop -> spawn in the new cwd -> health gate). Terminals are not
 * touched; each keeps the cwd it reports.
 */
export class HarnessController {
  private switching = false;
  private readonly env: () => NodeJS.ProcessEnv;
  private readonly homeDir: string;
  private readonly cwd: () => string;
  private readonly isDirectory: (candidate: string) => boolean;

  constructor(private readonly deps: HarnessControllerDeps) {
    this.env = deps.env ?? (() => process.env);
    this.homeDir = deps.homeDir ?? os.homedir();
    this.cwd = deps.cwd ?? (() => process.cwd());
    this.isDirectory = deps.isDirectory ?? isDirectory;
  }

  resolve(): HarnessResolution {
    return resolveHarness({
      env: this.env(),
      homeDir: this.homeDir,
      cwd: this.cwd(),
      isDirectory: this.isDirectory,
      userChoice: this.deps.store.current(),
    });
  }

  recent(): HarnessRecentEntry[] {
    const current = this.deps.store.current();
    return this.deps.store
      .recent()
      .map((entry) => ({ path: entry, exists: this.isDirectory(entry), current: entry === current }));
  }

  status(): HarnessStatus {
    return {
      resolution: this.resolve(),
      recent: this.recent(),
      switching: this.switching,
      lockedBy: activeOverrideVar(this.env()),
    };
  }

  async set(raw: unknown): Promise<HarnessSwitchResult> {
    const locked = this.refuseIfLocked();
    if (locked) return locked;
    const checked = validateHarnessPath(raw, this.homeDir);
    if (!checked.ok) return checked;
    return this.apply(checked.path);
  }

  async choose(): Promise<HarnessSwitchResult> {
    const locked = this.refuseIfLocked();
    if (locked) return locked;
    if (!this.deps.chooseDirectory) {
      return { ok: false, error: 'unavailable', message: 'No folder picker is available' };
    }
    const picked = await this.deps.chooseDirectory(this.resolve().path);
    if (!picked) return { ok: false, error: 'cancelled', message: 'No folder was chosen' };
    return this.set(picked);
  }

  /** Forget the Desktop choice and return to `~/.ai-workspace` (or fallback). */
  async reset(): Promise<HarnessSwitchResult> {
    const locked = this.refuseIfLocked();
    if (locked) return locked;
    return this.apply(null);
  }

  private refuseIfLocked(): HarnessSwitchResult | null {
    const locked = activeOverrideVar(this.env());
    if (!locked) return null;
    return {
      ok: false,
      error: 'env-override',
      message: `${locked}=${this.env()[locked]} is set and takes precedence over a Desktop choice. Unset it and relaunch Desktop to switch harness here.`,
    };
  }

  private async apply(choice: string | null): Promise<HarnessSwitchResult> {
    if (this.switching) {
      return { ok: false, error: 'busy', message: 'A harness switch is already in progress' };
    }
    const supervisor = this.deps.getSupervisor();
    if (!supervisor) return { ok: false, error: 'unavailable', message: 'Backend supervisor is not running' };
    this.switching = true;
    try {
      const before = supervisor.snapshot();
      try {
        this.deps.store.setCurrent(choice);
      } catch (error) {
        return {
          ok: false,
          error: 'persist-failed',
          message: `Could not save the harness choice to ${this.deps.store.path}: ${error instanceof Error ? error.message : String(error)}`,
        };
      }
      const harness = this.resolve();
      // Same directory = same serve; only the source label differs, so skip the restart.
      const unchanged = before.status === 'ready' && before.harness?.path === harness.path;
      if (unchanged) return { ok: true, restarted: false, harness, backend: before };
      await supervisor.restart();
      const backend = supervisor.snapshot();
      return { ok: true, restarted: true, harness: backend.harness ?? harness, backend };
    } finally {
      this.switching = false;
    }
  }
}
