import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import * as pty from 'node-pty';
import {
  encodeFrame,
  ensureRuntimeDir,
  NdjsonDecoder,
  PTY_HOST_PROTOCOL,
  type PtyCreateRequest,
  type PtyHostEvent,
  type PtyHostRequest,
} from './pty-protocol.js';
import type { TerminalSessionInfo } from './terminal.js';

/**
 * The detached PTY host server (ADR-037). Owns every interactive PTY so
 * sessions survive Electron main: app quit, crash or renderer reload only
 * detaches clients; the processes keep running here and a later client
 * reattaches with `list` + `tail` (journal replay).
 *
 * One host per user (socket singleton). The host exits on its own after
 * the last session ends and no client has been connected for a grace
 * period, so it never becomes a permanent daemon.
 */

const MAX_TAIL_CHARS = 256 * 1024;
const MAX_TIMER_DELAY_MS = 2_147_000_000;
const IDLE_EXIT_MS = 60_000;

interface HostSession extends TerminalSessionInfo {
  proc: pty.IPty;
  tail: string;
  budgetTimer?: NodeJS.Timeout;
  forceKillTimer?: NodeJS.Timeout;
}

export interface PtyHostCoreOptions {
  runtimeDir: string;
  token: string;
  /** Called when the host should exit (idle timeout or shutdown op). */
  onIdleExit?: () => void;
}

export class PtyHostCore {
  private sessions = new Map<string, HostSession>();
  private clients = new Set<net.Socket>();
  private server: net.Server | null = null;
  private idleTimer: NodeJS.Timeout | null = null;
  private readonly runtimeDir: string;
  private readonly token: string;
  private readonly onIdleExit?: () => void;

  constructor(options: PtyHostCoreOptions) {
    this.runtimeDir = options.runtimeDir;
    this.token = options.token;
    this.onIdleExit = options.onIdleExit;
  }

  get socketPath(): string {
    return process.platform === 'win32'
      ? String.raw`\\.\pipe\agent-toolkit-pty-host`
      : path.join(this.runtimeDir, 'pty-host.sock');
  }

  async listen(): Promise<void> {
    ensureRuntimeDir(this.runtimeDir);
    if (process.platform !== 'win32') {
      try {
        fs.unlinkSync(this.socketPath);
      } catch {
        // No stale socket.
      }
    }
    this.server = net.createServer((socket) => this.handleClient(socket));
    await new Promise<void>((resolve, reject) => {
      this.server!.once('error', reject);
      this.server!.listen(this.socketPath, () => resolve());
    });
    if (process.platform !== 'win32') {
      try {
        fs.chmodSync(this.socketPath, 0o600);
      } catch {
        // Best effort.
      }
    }
    this.writeRegistry();
    this.armIdleExit();
  }

  async close(): Promise<void> {
    if (this.idleTimer) clearTimeout(this.idleTimer);
    for (const client of this.clients) client.destroy();
    await new Promise<void>((resolve) => {
      if (!this.server) return resolve();
      this.server.close(() => resolve());
    });
  }

  /** Session infos (no process handles), for tests and the client mirror. */
  list(): TerminalSessionInfo[] {
    return [...this.sessions.values()].map((session) => this.infoOf(session));
  }

  tail(id: string): string {
    const session = this.sessions.get(id);
    if (session) return session.tail;
    // Journal replay for sessions whose ring was trimmed by a host restart
    // is intentionally not offered: a restarted host owns no live PTYs.
    return '';
  }

  private handleClient(socket: net.Socket): void {
    this.clients.add(socket);
    if (this.idleTimer) {
      clearTimeout(this.idleTimer);
      this.idleTimer = null;
    }
    const decoder = new NdjsonDecoder();
    let authed = false;
    socket.setEncoding('utf8');
    socket.on('data', (chunk: string) => {
      for (const frame of decoder.push(chunk)) {
        const request = frame as PtyHostRequest;
        if (!authed) {
          if (request.op === 'hello' && request.token === this.token && request.protocol === PTY_HOST_PROTOCOL) {
            authed = true;
            socket.write(encodeFrame({ id: request.id, ok: true, result: { protocol: PTY_HOST_PROTOCOL } }));
          } else {
            socket.destroy();
            return;
          }
          continue;
        }
        void this.dispatch(socket, request);
      }
    });
    const drop = () => {
      this.clients.delete(socket);
      this.armIdleExit();
    };
    socket.on('close', drop);
    socket.on('error', drop);
  }

  private async dispatch(socket: net.Socket, request: PtyHostRequest): Promise<void> {
    try {
      switch (request.op) {
        case 'ping':
          return this.reply(socket, request.id, true, 'pong');
        case 'list':
          return this.reply(socket, request.id, true, this.list());
        case 'create':
          return this.reply(socket, request.id, true, this.create(request.session));
        case 'tail':
          return this.reply(socket, request.id, true, this.tail(request.sessionId));
        case 'write':
          return this.reply(socket, request.id, true, this.write(request.sessionId, request.data));
        case 'resize':
          return this.reply(socket, request.id, true, this.resize(request.sessionId, request.cols, request.rows));
        case 'signal':
          return this.reply(socket, request.id, true, this.signal(request.sessionId, request.signal));
        case 'close':
          return this.reply(socket, request.id, true, this.closeSession(request.sessionId));
        case 'shutdown':
          this.reply(socket, request.id, true, null);
          this.onIdleExit?.();
          return;
        default:
          return this.reply(socket, request.id, false, undefined, `unknown op`);
      }
    } catch (error) {
      return this.reply(socket, request.id, false, undefined, error instanceof Error ? error.message : String(error));
    }
  }

  private reply(socket: net.Socket, id: number, ok: boolean, result?: unknown, error?: string): void {
    socket.write(encodeFrame(ok ? { id, ok: true, result } : { id, ok: false, error: error ?? 'error' }));
  }

  private broadcast(event: PtyHostEvent): void {
    const frame = encodeFrame(event);
    for (const client of this.clients) client.write(frame);
  }

  create(request: PtyCreateRequest): TerminalSessionInfo {
    if (
      request.maxSeconds !== undefined &&
      (!Number.isSafeInteger(request.maxSeconds) || request.maxSeconds < 1 || request.maxSeconds > 31_536_000)
    ) {
      throw new RangeError('maxSeconds must be an integer between 1 and 31536000');
    }
    const id = randomUUID();
    const cols = request.cols ?? 120;
    const rows = request.rows ?? 30;
    const proc = pty.spawn(request.cmd, request.args ?? [], {
      name: 'xterm-256color',
      cols,
      rows,
      cwd: request.cwd,
      env: { ...process.env, TERM: 'xterm-256color' },
    });
    const session: HostSession = {
      id,
      agent: request.agent,
      personId: request.personId,
      agentSessionId: request.agentSessionId,
      sessionWorkspace: request.sessionWorkspace,
      projectId: request.projectId,
      provider: request.provider,
      model: request.model,
      cmd: request.cmd,
      args: request.args ?? [],
      cwd: request.cwd,
      maxSeconds: request.maxSeconds,
      cols,
      rows,
      exitCode: null,
      createdAt: new Date().toISOString(),
      proc,
      tail: '',
    };
    proc.onData((chunk: string) => {
      session.tail = (session.tail + chunk).slice(-MAX_TAIL_CHARS);
      this.appendJournal(id, chunk);
      this.broadcast({ event: 'data', sessionId: id, chunk });
    });
    proc.onExit(({ exitCode }: { exitCode: number }) => {
      session.exitCode = exitCode;
      this.clearTimers(session);
      this.broadcast({ event: 'exit', sessionId: id, exitCode, exitReason: session.exitReason });
      this.writeRegistry();
      this.armIdleExit();
    });
    this.sessions.set(id, session);
    if (request.maxSeconds !== undefined) this.scheduleBudgetExpiry(session, Date.now() + request.maxSeconds * 1000);
    this.writeRegistry();
    this.broadcast({ event: 'created', sessionId: id });
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

  closeSession(id: string): boolean {
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
    this.writeRegistry();
    this.armIdleExit();
    return true;
  }

  /** Terminate every session (explicit host shutdown only, never on detach). */
  terminateAll(reason: 'app-shutdown' = 'app-shutdown'): void {
    for (const session of this.sessions.values()) {
      session.exitReason = reason;
      try {
        session.proc.kill();
      } catch {
        // already gone
      }
      this.clearTimers(session);
    }
    this.sessions.clear();
    this.writeRegistry();
  }

  private infoOf(session: HostSession): TerminalSessionInfo {
    const { proc: _proc, tail: _tail, budgetTimer: _budgetTimer, forceKillTimer: _forceKillTimer, ...info } = session;
    return info;
  }

  private journalPath(id: string): string {
    return path.join(this.runtimeDir, `pty-${id}.log`);
  }

  private appendJournal(id: string, chunk: string): void {
    try {
      fs.appendFileSync(this.journalPath(id), chunk);
    } catch {
      // Journal is best-effort replay support, never a reason to drop output.
    }
  }

  private writeRegistry(): void {
    try {
      ensureRuntimeDir(this.runtimeDir);
      fs.writeFileSync(
        path.join(this.runtimeDir, 'pty-registry.json'),
        JSON.stringify({ pid: process.pid, sessions: this.list(), updatedAt: new Date().toISOString() }, null, 2),
        { mode: 0o600 },
      );
    } catch {
      // Registry is observability only.
    }
  }

  private armIdleExit(): void {
    if (!this.onIdleExit || this.idleTimer) return;
    const alive = [...this.sessions.values()].some((session) => session.exitCode === null);
    if (alive || this.clients.size > 0) return;
    this.idleTimer = setTimeout(() => this.onIdleExit?.(), IDLE_EXIT_MS);
    this.idleTimer.unref();
  }

  private scheduleBudgetExpiry(session: HostSession, expiresAt: number): void {
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

  private clearTimers(session: HostSession): void {
    if (session.budgetTimer) clearTimeout(session.budgetTimer);
    if (session.forceKillTimer) clearTimeout(session.forceKillTimer);
    session.budgetTimer = undefined;
    session.forceKillTimer = undefined;
  }
}
