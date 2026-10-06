import type { BrowserWindow } from 'electron';
import { randomUUID } from 'node:crypto';
import os from 'node:os';
import path from 'node:path';
import * as pty from 'node-pty';
import { expandHome, isDirectory } from './harness';

/**
 * Terminal transport adapter (Electron main only).
 *
 * node-pty is strictly a PTY runtime adapter: it spawns interactive processes
 * (agent CLIs, shells) and shuttles bytes. It owns no Agent Toolkit domain
 * state — catalog, jobs, memory, approvals all stay behind `agent-toolkit
 * serve`. node-pty supports native PTY processes on Linux, macOS, and Windows.
 */

export interface TerminalSessionInfo {
  id: string;
  agent: string;
  /** Person identity when this PTY was started from the People roster. */
  personId?: string;
  /** Canonical V-owned session record, when present. */
  agentSessionId?: string;
  sessionWorkspace?: string;
  projectId?: string;
  provider?: string;
  model?: string;
  cmd: string;
  /** argv used at spawn (cmd excluded); exposed so restart reproduces the session. */
  args: string[];
  cwd: string;
  maxSeconds?: number;
  exitReason?: 'time-budget' | 'user-stop' | 'app-shutdown';
  cols: number;
  rows: number;
  exitCode: number | null;
  createdAt: string;
}

interface Session extends TerminalSessionInfo {
  proc: pty.IPty;
  tail: string;
  budgetTimer?: NodeJS.Timeout;
  forceKillTimer?: NodeJS.Timeout;
}

const MAX_TAIL_CHARS = 8 * 1024;
const MAX_TIMER_DELAY_MS = 2_147_000_000;

type DataListener = (id: string, chunk: string) => void;
type ExitListener = (id: string, exitCode: number, exitReason?: 'time-budget' | 'user-stop' | 'app-shutdown') => void;

export interface TerminalServiceOptions {
  /** cwd for sessions created without one: the resolved harness in the app. */
  defaultCwd?: () => string;
}

export class TerminalCwdError extends Error {}

export class TerminalService {
  private sessions = new Map<string, Session>();
  private dataListeners = new Set<DataListener>();
  private exitListeners = new Set<ExitListener>();
  private windowOf: (() => BrowserWindow | null) | null = null;
  private readonly defaultCwd: () => string;

  constructor(options: TerminalServiceOptions = {}) {
    this.defaultCwd = options.defaultCwd ?? (() => process.cwd());
  }

  attachWindow(getWindow: () => BrowserWindow | null): void {
    this.windowOf = getWindow;
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

  list(): TerminalSessionInfo[] {
    return [...this.sessions.values()].map(({ proc: _proc, tail: _tail, ...info }) => info);
  }

  /** Buffered output tail for a session (catch-up on pane mount / tab switch). */
  tail(id: string): string {
    return this.sessions.get(id)?.tail ?? '';
  }

  /** Absolute, existing cwd for a new session; relative paths resolve against the default cwd. */
  resolveCwd(requested?: string): string {
    const base = this.defaultCwd();
    const cwd = requested?.trim() ? path.resolve(base, expandHome(requested.trim(), os.homedir())) : base;
    if (!isDirectory(cwd)) throw new TerminalCwdError(`terminal cwd ${cwd} is not an existing directory`);
    return cwd;
  }

  /** Throws TerminalCwdError when the cwd does not exist; never creates it. */
  create(options: {
    agent: string;
    personId?: string;
    agentSessionId?: string;
    sessionWorkspace?: string;
    projectId?: string;
    provider?: string;
    model?: string;
    cmd: string;
    args?: string[];
    cwd?: string;
    maxSeconds?: number;
    cols?: number;
    rows?: number;
  }): TerminalSessionInfo {
    const id = randomUUID();
    const cols = options.cols ?? 120;
    const rows = options.rows ?? 30;
    if (
      options.maxSeconds !== undefined &&
      (!Number.isSafeInteger(options.maxSeconds) || options.maxSeconds < 1 || options.maxSeconds > 31_536_000)
    ) {
      throw new RangeError('maxSeconds must be an integer between 1 and 31536000');
    }
    const cwd = this.resolveCwd(options.cwd);
    const proc = pty.spawn(options.cmd, options.args ?? [], {
      name: 'xterm-256color',
      cols,
      rows,
      cwd,
      env: { ...process.env, TERM: 'xterm-256color' },
    });
    const session: Session = {
      id,
      agent: options.agent,
      personId: options.personId,
      agentSessionId: options.agentSessionId,
      sessionWorkspace: options.sessionWorkspace,
      projectId: options.projectId,
      provider: options.provider,
      model: options.model,
      cmd: options.cmd,
      args: options.args ?? [],
      cwd,
      maxSeconds: options.maxSeconds,
      cols,
      rows,
      exitCode: null,
      createdAt: new Date().toISOString(),
      proc,
      tail: '',
    };
    proc.onData((chunk: string) => {
      session.tail = (session.tail + chunk).slice(-MAX_TAIL_CHARS);
      for (const listener of this.dataListeners) listener(id, chunk);
      this.windowOf?.()?.webContents.send('atk:pty-data', { id, chunk });
    });
    proc.onExit(({ exitCode }: { exitCode: number }) => {
      session.exitCode = exitCode;
      this.clearTimers(session);
      for (const listener of this.exitListeners) listener(id, exitCode, session.exitReason);
      this.windowOf?.()?.webContents.send('atk:pty-exit', { id, exitCode, exitReason: session.exitReason });
    });
    this.sessions.set(id, session);
    if (options.maxSeconds !== undefined) this.scheduleBudgetExpiry(session, Date.now() + options.maxSeconds * 1000);
    return this.infoOf(session);
  }

  write(id: string, data: string): boolean {
    const session = this.sessions.get(id);
    if (!session || session.exitCode !== null) return false;
    session.proc.write(data);
    return true;
  }

  resize(id: string, cols: number, rows: number): boolean {
    const session = this.sessions.get(id);
    if (!session) return false;
    session.cols = cols;
    session.rows = rows;
    try {
      session.proc.resize(cols, rows);
    } catch {
      return false;
    }
    return true;
  }

  /** Interrupt (SIGINT) or terminate (SIGTERM) the session process. */
  signal(id: string, signal: 'int' | 'term' | 'kill'): boolean {
    const session = this.sessions.get(id);
    if (!session || session.exitCode !== null) return false;
    if ((signal === 'term' || signal === 'kill') && session.exitReason !== 'time-budget') {
      session.exitReason = 'user-stop';
    }
    if (signal !== 'int' && session.exitReason !== 'time-budget') this.clearTimers(session);
    try {
      if (signal === 'int') session.proc.write('\x03');
      else if (signal === 'term') process.kill(session.proc.pid, 'SIGTERM');
      else process.kill(session.proc.pid, 'SIGKILL');
    } catch {
      return false;
    }
    return true;
  }

  close(id: string): boolean {
    const session = this.sessions.get(id);
    if (!session) return false;
    session.exitReason = 'user-stop';
    try {
      session.proc.kill();
    } catch {
      // already gone
    }
    this.clearTimers(session);
    this.sessions.delete(id);
    return true;
  }

  dispose(): void {
    for (const session of this.sessions.values()) {
      session.exitReason = 'app-shutdown';
      try {
        session.proc.kill();
      } catch {
        // already gone
      }
      this.clearTimers(session);
    }
    this.sessions.clear();
  }

  private infoOf(session: Session): TerminalSessionInfo {
    const { proc: _proc, tail: _tail, budgetTimer: _budgetTimer, forceKillTimer: _forceKillTimer, ...info } = session;
    return info;
  }

  private scheduleBudgetExpiry(session: Session, expiresAt: number): void {
    const remaining = Math.max(0, expiresAt - Date.now());
    session.budgetTimer = setTimeout(
      () => {
        if (Date.now() < expiresAt) {
          this.scheduleBudgetExpiry(session, expiresAt);
          return;
        }
        if (session.exitCode !== null) return;
        session.exitReason = 'time-budget';
        this.signal(session.id, 'term');
        session.forceKillTimer = setTimeout(() => {
          if (session.exitCode === null) this.signal(session.id, 'kill');
        }, 5_000);
        session.forceKillTimer.unref();
      },
      Math.min(remaining, MAX_TIMER_DELAY_MS),
    );
    session.budgetTimer.unref();
  }

  private clearTimers(session: Session): void {
    if (session.budgetTimer) clearTimeout(session.budgetTimer);
    if (session.forceKillTimer) clearTimeout(session.forceKillTimer);
    session.budgetTimer = undefined;
    session.forceKillTimer = undefined;
  }
}
