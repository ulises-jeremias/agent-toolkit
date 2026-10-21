import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import {
  encodeFrame,
  ensureRuntimeDir,
  NdjsonDecoder,
  PTY_HOST_PROTOCOL,
  ptyRuntimeDir,
  ptySocketPath,
  readOrCreateToken,
  type PtyCreateRequest,
  type PtyHostEvent,
} from './pty-protocol.js';
import type { TerminalSessionInfo } from './terminal.js';

/**
 * Client for the detached PTY host (ADR-037). Electron main keeps one
 * connection; the first call spawns the host detached when no socket
 * answers. When the connection drops (app is about to quit, host died),
 * in-flight requests fail honestly and the next call reconnects — sessions
 * that outlived us are rediscovered with `list` + `tail`.
 */

export interface PtyHostClientOptions {
  runtimeDir?: string;
  /** Host entry override (tests); defaults to the sibling pty-host build. */
  hostEntry?: string;
  /** Spawn override (tests); defaults to detached child_process.spawn. */
  spawnHost?: (entry: string, runtimeDir: string) => void;
}

type Pending = { resolve: (value: unknown) => void; reject: (error: Error) => void };

export class PtyHostClient {
  private socket: net.Socket | null = null;
  private connecting: Promise<void> | null = null;
  private nextId = 1;
  private pending = new Map<number, Pending>();
  private eventListeners = new Set<(event: PtyHostEvent) => void>();
  private disconnectListeners = new Set<() => void>();
  private readonly runtimeDir: string;
  private readonly hostEntry?: string;
  private readonly spawnHostOverride?: (entry: string, runtimeDir: string) => void;

  constructor(options: PtyHostClientOptions = {}) {
    this.runtimeDir = options.runtimeDir ?? ptyRuntimeDir();
    this.hostEntry = options.hostEntry;
    this.spawnHostOverride = options.spawnHost;
  }

  onEvent(listener: (event: PtyHostEvent) => void): () => void {
    this.eventListeners.add(listener);
    return () => {
      this.eventListeners.delete(listener);
    };
  }

  onDisconnect(listener: () => void): () => void {
    this.disconnectListeners.add(listener);
    return () => {
      this.disconnectListeners.delete(listener);
    };
  }

  async list(): Promise<TerminalSessionInfo[]> {
    return (await this.request({ op: 'list' })) as TerminalSessionInfo[];
  }

  async create(session: PtyCreateRequest): Promise<TerminalSessionInfo> {
    return (await this.request({ op: 'create', session })) as TerminalSessionInfo;
  }

  async tail(sessionId: string): Promise<string> {
    return (await this.request({ op: 'tail', sessionId })) as string;
  }

  async write(sessionId: string, data: string): Promise<boolean> {
    return (await this.request({ op: 'write', sessionId, data })) as boolean;
  }

  async resize(sessionId: string, cols: number, rows: number): Promise<boolean> {
    return (await this.request({ op: 'resize', sessionId, cols, rows })) as boolean;
  }

  async signal(sessionId: string, signal: 'int' | 'term' | 'kill'): Promise<boolean> {
    return (await this.request({ op: 'signal', sessionId, signal })) as boolean;
  }

  async close(sessionId: string): Promise<boolean> {
    return (await this.request({ op: 'close', sessionId })) as boolean;
  }

  /** Close the connection only. Host sessions keep running (detach). */
  disconnect(): void {
    this.socket?.destroy();
    this.socket = null;
  }

  private async request(payload: Record<string, unknown>): Promise<unknown> {
    await this.ensureConnected();
    const id = this.nextId++;
    const socket = this.socket;
    if (!socket) throw new Error('pty host connection lost');
    return new Promise<unknown>((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      socket.write(encodeFrame({ id, ...payload }));
    });
  }

  private async ensureConnected(): Promise<void> {
    if (this.socket && !this.socket.destroyed) return;
    if (this.connecting) return this.connecting;
    this.connecting = this.connectWithSpawn().finally(() => {
      this.connecting = null;
    });
    return this.connecting;
  }

  private async connectWithSpawn(): Promise<void> {
    try {
      await this.connectOnce();
      return;
    } catch {
      // No host listening: spawn it detached, then retry until it answers.
    }
    this.spawnHost();
    const deadline = Date.now() + 10_000;
    let lastError: unknown = null;
    while (Date.now() < deadline) {
      await new Promise((resolve) => setTimeout(resolve, 100));
      try {
        await this.connectOnce();
        return;
      } catch (error) {
        lastError = error;
      }
    }
    throw new Error(`pty host did not start: ${lastError instanceof Error ? lastError.message : String(lastError)}`);
  }

  private connectOnce(): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      ensureRuntimeDir(this.runtimeDir);
      const token = readOrCreateToken(this.runtimeDir, () => randomUUID());
      const socket = net.createConnection(ptySocketPath(this.runtimeDir));
      const decoder = new NdjsonDecoder();
      let settled = false;
      const fail = (error: Error) => {
        if (settled) return;
        settled = true;
        socket.destroy();
        reject(error);
      };
      socket.setEncoding('utf8');
      socket.once('error', fail);
      socket.once('connect', () => {
        socket.write(encodeFrame({ id: 0, op: 'hello', token, protocol: PTY_HOST_PROTOCOL }));
      });
      socket.on('data', (chunk: string) => {
        for (const frame of decoder.push(chunk)) {
          const message = frame as { id?: number; ok?: boolean; result?: unknown; error?: string; event?: string };
          if (!settled) {
            if (message.id === 0 && message.ok) {
              settled = true;
              this.socket = socket;
              this.wireSocket(socket, decoder);
              resolve();
            } else {
              fail(new Error('pty host rejected hello'));
            }
            continue;
          }
          this.handleFrame(message);
        }
      });
    });
  }

  private wireSocket(socket: net.Socket, _decoder: NdjsonDecoder): void {
    socket.on('close', () => {
      if (this.socket === socket) this.socket = null;
      const error = new Error('pty host connection closed');
      for (const pending of this.pending.values()) pending.reject(error);
      this.pending.clear();
      for (const listener of this.disconnectListeners) listener();
    });
    socket.on('error', () => {
      // 'close' follows and performs cleanup.
    });
  }

  private handleFrame(message: { id?: number; ok?: boolean; result?: unknown; error?: string; event?: string }): void {
    if (typeof message.event === 'string') {
      for (const listener of this.eventListeners) listener(message as PtyHostEvent);
      return;
    }
    if (typeof message.id === 'number') {
      const pending = this.pending.get(message.id);
      if (!pending) return;
      this.pending.delete(message.id);
      if (message.ok) pending.resolve(message.result);
      else pending.reject(new Error(message.error ?? 'pty host error'));
    }
  }

  private spawnHost(): void {
    if (this.spawnHostOverride) {
      this.spawnHostOverride(this.resolveHostEntry(), this.runtimeDir);
      return;
    }
    const entry = this.resolveHostEntry();
    const isElectron = typeof process.versions.electron === 'string';
    const child = spawn(process.execPath, [entry, '--runtime-dir', this.runtimeDir], {
      detached: true,
      stdio: 'ignore',
      env: isElectron ? { ...process.env, ELECTRON_RUN_AS_NODE: '1' } : process.env,
    });
    child.unref();
  }

  private resolveHostEntry(): string {
    if (this.hostEntry) return this.hostEntry;
    const built = path.join(__dirname, 'pty-host.js');
    if (fs.existsSync(built)) return built;
    return path.join(__dirname, 'pty-host.ts');
  }
}
