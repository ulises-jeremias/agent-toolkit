import type { BrowserWindow } from 'electron';
import { randomUUID } from 'node:crypto';
import * as pty from 'node-pty';

/**
 * Terminal transport adapter (Electron main only).
 *
 * node-pty is strictly a PTY runtime adapter: it spawns interactive processes
 * (agent CLIs, shells) and shuttles bytes. It owns no Agent Toolkit domain
 * state — catalog, jobs, memory, approvals all stay behind `agent-toolkit
 * serve`. Chosen over the V `modules/pty` backend because node-pty gives us
 * ConPTY on Windows; the V PTY module is POSIX-only by design.
 */

export interface TerminalSessionInfo {
  id: string;
  agent: string;
  cmd: string;
  /** argv used at spawn (cmd excluded); exposed so restart reproduces the session. */
  args: string[];
  cwd: string;
  cols: number;
  rows: number;
  exitCode: number | null;
  createdAt: string;
}

interface Session extends TerminalSessionInfo {
  proc: pty.IPty;
  tail: string;
}

const MAX_TAIL_CHARS = 8 * 1024;

type DataListener = (id: string, chunk: string) => void;
type ExitListener = (id: string, exitCode: number) => void;

export class TerminalService {
  private sessions = new Map<string, Session>();
  private dataListeners = new Set<DataListener>();
  private exitListeners = new Set<ExitListener>();
  private windowOf: (() => BrowserWindow | null) | null = null;

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

  create(options: { agent: string; cmd: string; args?: string[]; cwd?: string; cols?: number; rows?: number }): TerminalSessionInfo {
    const id = randomUUID();
    const cols = options.cols ?? 120;
    const rows = options.rows ?? 30;
    const cwd = options.cwd ?? process.cwd();
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
      cmd: options.cmd,
      args: options.args ?? [],
      cwd,
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
      for (const listener of this.exitListeners) listener(id, exitCode);
      this.windowOf?.()?.webContents.send('atk:pty-exit', { id, exitCode });
    });
    this.sessions.set(id, session);
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
    try {
      session.proc.kill();
    } catch {
      // already gone
    }
    this.sessions.delete(id);
    return true;
  }

  dispose(): void {
    for (const id of [...this.sessions.keys()]) this.close(id);
  }

  private infoOf(session: Session): TerminalSessionInfo {
    const { proc: _proc, tail: _tail, ...info } = session;
    return info;
  }
}
