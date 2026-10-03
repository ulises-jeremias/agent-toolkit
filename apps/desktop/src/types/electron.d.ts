/** Narrow typed Electron bridge (mirrors electron/preload.ts). */

export type BackendStatus = 'starting' | 'ready' | 'version-mismatch' | 'crashed' | 'stopped' | 'failed';

/** Precedence: override (env) > user (saved Desktop choice) > default (~/.ai-workspace) > fallback. */
export type HarnessSource = 'override' | 'user' | 'default' | 'fallback';

export interface HarnessResolution {
  path: string;
  source: HarnessSource;
  defaultPath: string;
  overrideVar: string | null;
  notice: string | null;
}

export type BackendBinarySource = 'env' | 'bundled' | 'staged' | 'path';

export interface BackendBinaryInfo {
  path: string;
  source: BackendBinarySource;
  version: string | null;
}

export interface RejectedBackendBinary extends BackendBinaryInfo {
  reason: string;
}

/** Cause behind a non-ready status (see electron/backend.ts for each meaning). */
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
  harness: HarnessResolution | null;
  binary: BackendBinaryInfo | null;
  rejected: RejectedBackendBinary[];
  problem: BackendProblem | null;
}

export interface HarnessRecentEntry {
  path: string;
  exists: boolean;
  current: boolean;
}

export interface HarnessStatus {
  resolution: HarnessResolution;
  recent: HarnessRecentEntry[];
  switching: boolean;
  lockedBy: string | null;
}

export type HarnessSwitchError =
  | 'invalid-path'
  | 'not-found'
  | 'not-a-directory'
  | 'not-accessible'
  | 'cancelled'
  | 'env-override'
  | 'busy'
  | 'persist-failed'
  | 'unavailable';

export type HarnessSwitchResult =
  | { ok: true; restarted: boolean; harness: HarnessResolution; backend: BackendState }
  | { ok: false; error: HarnessSwitchError; message: string };

export interface PtyCreateOptions {
  agent: string;
  personId?: string;
  projectId?: string;
  provider?: string;
  model?: string;
  cmd: string;
  args?: string[];
  /** Defaults to the resolved harness; relative paths resolve against it; must exist. */
  cwd?: string;
  /** Person runtime budget in seconds. The PTY supervisor terminates the process when reached. */
  maxSeconds?: number;
  cols?: number;
  rows?: number;
}

export interface PtySessionInfo {
  id: string;
  agent: string;
  personId?: string;
  projectId?: string;
  provider?: string;
  model?: string;
  cmd: string;
  args: string[];
  cwd: string;
  maxSeconds?: number;
  exitReason?: 'time-budget';
  cols: number;
  rows: number;
  exitCode: number | null;
  createdAt: string;
}

export interface PtyDataEvent {
  id: string;
  chunk: string;
}

export interface PtyExitEvent {
  id: string;
  exitCode: number;
  exitReason?: 'time-budget';
}

export type Unsubscribe = () => void;

export interface AtkBridge {
  backendStatus: () => Promise<BackendState | null>;
  backendRestart: () => Promise<boolean>;
  onBackendState: (listener: (state: BackendState) => void) => Unsubscribe;
  harnessStatus: () => Promise<HarnessStatus | null>;
  harnessRecent: () => Promise<HarnessRecentEntry[]>;
  /**
   * Validate, persist, and restart the backend in `path`. Never mkdirs unless
   * `create: true`, which is allowed only for the default ~/.ai-workspace path
   * after the renderer confirmed.
   */
  harnessSet: (path: string, options?: { create?: boolean }) => Promise<HarnessSwitchResult>;
  /** Native folder picker, then the same flow as harnessSet. */
  harnessChoose: () => Promise<HarnessSwitchResult>;
  /** Forget the Desktop choice; back to ~/.ai-workspace (or fallback). */
  harnessReset: () => Promise<HarnessSwitchResult>;
  /** Native project folder picker; selection is reviewed before the renderer links it. */
  projectChooseDirectory: (defaultPath: string) => Promise<string | null>;
  ptyList: () => Promise<PtySessionInfo[]>;
  ptyTail: (id: string) => Promise<string>;
  ptyCreate: (options: PtyCreateOptions) => Promise<PtySessionInfo | null>;
  ptyWrite: (id: string, data: string) => Promise<boolean>;
  ptyResize: (id: string, cols: number, rows: number) => Promise<boolean>;
  ptySignal: (id: string, signal: 'int' | 'term' | 'kill') => Promise<boolean>;
  ptyClose: (id: string) => Promise<boolean>;
  onPtyData: (listener: (event: PtyDataEvent) => void) => Unsubscribe;
  onPtyExit: (listener: (event: PtyExitEvent) => void) => Unsubscribe;
}

declare global {
  interface Window {
    atk?: AtkBridge;
  }
}

export {};
