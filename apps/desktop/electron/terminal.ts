import type { BrowserWindow } from 'electron';
import os from 'node:os';
import path from 'node:path';
import { expandHome, isDirectory } from './harness.js';
import { PtyHostClient } from './pty-host-client.js';
import type { PtyCreateRequest } from './pty-protocol.js';

/**
 * Interactive PTY sessions for Desktop (Electron main).
 *
 * Since ADR-037 the processes live in the detached PTY host; this service
 * is the main-process client: it keeps a local mirror (refreshed from the
 * host on start/reconnect) so the established synchronous IPC surface
 * (list/tail/write/resize/signal/close) keeps working unchanged, while
 * sessions survive app quit/crash and are rediscovered on next launch.
 */

export interface TerminalCreateOptions {
  agent: string;
  personId?: string;
  agentSessionId?: string;
  sessionWorkspace?: string;
  projectId?: string;
  provider?: string;
  model?: string;
  providerSessionId?: string;
  cmd: string;
  args?: string[];
  cwd?: string;
  cols?: number;
  rows?: number;
  maxSeconds?: number;
}

export interface TerminalSessionInfo {
  id: string;
  agent: string;
  personId?: string;
  agentSessionId?: string;
  sessionWorkspace?: string;
  projectId?: string;
  provider?: string;
  model?: string;
  /** Provider-native conversation id, assigned at launch or captured after spawn. */
  providerSessionId?: string;
  cmd: string;
  args: string[];
  cwd: string;
  exitCode: number | null;
  exitReason?: 'time-budget' | 'user-stop' | 'app-shutdown';
  maxSeconds?: number;
  cols?: number;
  rows?: number;
  createdAt: string;
}

type DataListener = (id: string, chunk: string) => void;
type ExitListener = (id: string, code: number, reason?: TerminalSessionInfo['exitReason']) => void;

const MAX_TAIL_CHARS = 8 * 1024;

export class TerminalCwdError extends Error {}

interface MirrorSession extends TerminalSessionInfo {
  tail: string;
}

export interface TerminalServiceOptions {
  defaultCwd?: () => string;
  runtimeDir?: string;
  client?: PtyHostClient;
}

export class TerminalService {
  private client: PtyHostClient;
  private sessions = new Map<string, MirrorSession>();
  /** Sessions closed locally; refresh must not resurrect them from the host. */
  private closedIds = new Set<string>();
  private dataListeners = new Set<DataListener>();
  private exitListeners = new Set<ExitListener>();
  private startPromise: Promise<void> | null = null;
  private windowOf: (() => BrowserWindow | null) | null = null;
  private readonly defaultCwd: () => string;

  constructor(options: TerminalServiceOptions = {}) {
    this.defaultCwd = options.defaultCwd ?? (() => process.cwd());
    this.client = options.client ?? new PtyHostClient({ runtimeDir: options.runtimeDir });
    this.client.onEvent((event) => {
      if (event.event === 'data') {
        const session = this.sessions.get(event.sessionId);
        if (session) session.tail = (session.tail + event.chunk).slice(-MAX_TAIL_CHARS);
        for (const listener of this.dataListeners) listener(event.sessionId, event.chunk);
        this.windowOf?.()?.webContents.send('atk:pty-data', { id: event.sessionId, chunk: event.chunk });
      } else if (event.event === 'exit') {
        const session = this.sessions.get(event.sessionId);
        if (session) {
          session.exitCode = event.exitCode;
          if (event.exitReason) session.exitReason = event.exitReason;
        }
        for (const listener of this.exitListeners) listener(event.sessionId, event.exitCode, event.exitReason);
        this.windowOf?.()?.webContents.send('atk:pty-exit', {
          id: event.sessionId,
          exitCode: event.exitCode,
          exitReason: event.exitReason,
        });
      } else if (event.event === 'provider-session') {
        const session = this.sessions.get(event.sessionId);
        if (session) session.providerSessionId = event.providerSessionId;
        this.windowOf?.()?.webContents.send('atk:pty-provider-session', {
          id: event.sessionId,
          providerSessionId: event.providerSessionId,
        });
      } else if (event.event === 'created') {
        void this.refresh();
      }
    });
    this.client.onDisconnect(() => {
      // Host sessions keep running; the next operation reconnects and
      // refresh() reconciles the mirror.
      this.startPromise = null;
    });
  }

  attachWindow(getWindow: () => BrowserWindow | null): void {
    this.windowOf = getWindow;
  }

  /** Connect (spawning the host if needed) and adopt surviving sessions. */
  async start(): Promise<void> {
    await this.ensureStarted();
  }

  private async ensureStarted(): Promise<void> {
    if (!this.startPromise) {
      this.startPromise = this.refresh().catch((error: unknown) => {
        this.startPromise = null;
        throw error;
      });
    }
    return this.startPromise;
  }

  /** Reconcile the mirror with the host's authoritative session list. */
  async refresh(): Promise<void> {
    const infos = await this.client.list();
    const alive = new Set<string>();
    for (const info of infos) {
      alive.add(info.id);
      if (this.closedIds.has(info.id)) continue;
      const tail = await this.client.tail(info.id).catch(() => '');
      const existing = this.sessions.get(info.id);
      this.sessions.set(info.id, { ...info, tail: (existing?.tail ?? tail).slice(-MAX_TAIL_CHARS) });
    }
    for (const id of [...this.sessions.keys()]) {
      if (!alive.has(id)) this.sessions.delete(id);
    }
    for (const id of [...this.closedIds]) {
      if (!alive.has(id)) this.closedIds.delete(id);
    }
  }

  resolveCwd(requested?: string): string {
    const base = this.defaultCwd();
    const cwd = requested?.trim() ? path.resolve(base, expandHome(requested.trim(), os.homedir())) : base;
    if (!isDirectory(cwd)) throw new TerminalCwdError(`terminal cwd ${cwd} is not an existing directory`);
    return cwd;
  }

  async create(options: TerminalCreateOptions): Promise<TerminalSessionInfo> {
    const cwd = this.resolveCwd(options.cwd);
    if (
      options.maxSeconds !== undefined &&
      (!Number.isSafeInteger(options.maxSeconds) || options.maxSeconds < 1 || options.maxSeconds > 31_536_000)
    ) {
      throw new RangeError('maxSeconds must be an integer between 1 and 31536000');
    }
    const request: PtyCreateRequest = {
      agent: options.agent,
      personId: options.personId,
      agentSessionId: options.agentSessionId,
      sessionWorkspace: options.sessionWorkspace,
      projectId: options.projectId,
      provider: options.provider,
      model: options.model,
      providerSessionId: options.providerSessionId,
      cmd: options.cmd,
      args: options.args ?? [],
      cwd,
      cols: options.cols,
      rows: options.rows,
      maxSeconds: options.maxSeconds,
    };
    const info = await this.client.create(request);
    this.sessions.set(info.id, { ...info, tail: '' });
    return info;
  }

  list(): TerminalSessionInfo[] {
    void this.ensureStarted().catch(() => undefined);
    return [...this.sessions.values()].map(({ tail: _tail, ...info }) => info);
  }

  tail(id: string): string {
    return this.sessions.get(id)?.tail ?? '';
  }

  write(id: string, data: string): boolean {
    const session = this.sessions.get(id);
    if (!session || session.exitCode !== null) return false;
    void this.client.write(id, data).catch(() => false);
    return true;
  }

  resize(id: string, cols: number, rows: number): boolean {
    const session = this.sessions.get(id);
    if (!session) return false;
    session.cols = cols;
    session.rows = rows;
    void this.client.resize(id, cols, rows).catch(() => false);
    return true;
  }

  signal(id: string, signal: 'int' | 'term' | 'kill'): boolean {
    const session = this.sessions.get(id);
    if (!session || session.exitCode !== null) return false;
    void this.client.signal(id, signal).catch(() => false);
    return true;
  }

  close(id: string): boolean {
    if (!this.sessions.has(id)) return false;
    // Matches the pre-host semantics: close removes the session from the
    // list immediately; the host's exit event still reaches onExit.
    this.closedIds.add(id);
    this.sessions.delete(id);
    void this.client.close(id).catch(() => false);
    return true;
  }

  onData(listener: DataListener): () => void {
    this.dataListeners.add(listener);
    return () => {
      this.dataListeners.delete(listener);
    };
  }

  onExit(listener: ExitListener): () => void {
    this.exitListeners.add(listener);
    return () => {
      this.exitListeners.delete(listener);
    };
  }

  /**
   * Detach from the host. Sessions keep running in the detached host and
   * are rediscovered on the next launch (ADR-037) — quitting the app no
   * longer kills agent terminals.
   */
  dispose(): void {
    this.client.disconnect();
    this.startPromise = null;
  }

  /** Explicit teardown: terminate every session in the host. */
  async terminateAll(): Promise<void> {
    const ids = [...this.sessions.keys()];
    await Promise.all(ids.map((id) => this.client.close(id).catch(() => false)));
  }
}
