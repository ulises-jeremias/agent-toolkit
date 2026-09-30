/** Narrow typed Electron bridge (mirrors electron/preload.ts). */

export type BackendStatus = 'starting' | 'ready' | 'version-mismatch' | 'crashed' | 'stopped' | 'failed';

export interface BackendState {
  status: BackendStatus;
  url: string | null;
  version: string | null;
  detail: string | null;
  restarts: number;
}

export interface PtyCreateOptions {
  agent: string;
  /** Job or run the session belongs to, if any. Display metadata only. */
  run?: string;
  cmd: string;
  args?: string[];
  cwd?: string;
  cols?: number;
  rows?: number;
}

export interface PtySessionInfo {
  id: string;
  agent: string;
  run: string | null;
  cmd: string;
  args: string[];
  cwd: string;
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
}

export type Unsubscribe = () => void;

export interface AtkBridge {
  backendStatus: () => Promise<BackendState | null>;
  backendRestart: () => Promise<boolean>;
  onBackendState: (listener: (state: BackendState) => void) => Unsubscribe;
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
