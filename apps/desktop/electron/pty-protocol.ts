import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

/**
 * Detached PTY host protocol (ADR-037).
 *
 * The host is a small per-user daemon that owns every interactive PTY the
 * Desktop spawns. Electron main is only a client: when the app quits or
 * crashes, sessions keep running in the host and a later launch reattaches
 * (list + journal replay) instead of finding orphans.
 *
 * Transport: newline-delimited JSON over a Unix domain socket (named pipe
 * path on Windows). The first frame on a connection must be `hello` with
 * the shared token from the 0600 token file; anything else is dropped.
 */

export const PTY_HOST_PROTOCOL = 1;

export interface PtyCreateRequest {
  agent: string;
  personId?: string;
  agentSessionId?: string;
  sessionWorkspace?: string;
  projectId?: string;
  provider?: string;
  model?: string;
  /** Provider-native conversation id assigned at launch, when the runner accepts one. */
  providerSessionId?: string;
  cmd: string;
  args?: string[];
  cwd: string;
  maxSeconds?: number;
  cols?: number;
  rows?: number;
}

export type PtyHostRequest =
  | { id: number; op: 'hello'; token: string; protocol: number }
  | { id: number; op: 'ping' }
  | { id: number; op: 'list' }
  | { id: number; op: 'create'; session: PtyCreateRequest }
  | { id: number; op: 'tail'; sessionId: string }
  | { id: number; op: 'write'; sessionId: string; data: string }
  | { id: number; op: 'resize'; sessionId: string; cols: number; rows: number }
  | { id: number; op: 'signal'; sessionId: string; signal: 'int' | 'term' | 'kill' }
  | { id: number; op: 'close'; sessionId: string }
  | { id: number; op: 'shutdown' };

export type PtyHostResponse = { id: number; ok: true; result?: unknown } | { id: number; ok: false; error: string };

export type PtyHostEvent =
  | { event: 'data'; sessionId: string; chunk: string }
  | { event: 'exit'; sessionId: string; exitCode: number; exitReason?: 'time-budget' | 'user-stop' | 'app-shutdown' }
  | { event: 'created'; sessionId: string }
  | { event: 'provider-session'; sessionId: string; providerSessionId: string };

export type PtyHostFrame = PtyHostResponse | PtyHostEvent;

export function encodeFrame(frame: unknown): string {
  return `${JSON.stringify(frame)}\n`;
}

/** Incremental NDJSON decoder; tolerates frames split across chunks. */
export class NdjsonDecoder {
  private buffer = '';

  push(chunk: string): unknown[] {
    this.buffer += chunk;
    const frames: unknown[] = [];
    let index = this.buffer.indexOf('\n');
    while (index >= 0) {
      const line = this.buffer.slice(0, index).trim();
      this.buffer = this.buffer.slice(index + 1);
      if (line) {
        try {
          frames.push(JSON.parse(line));
        } catch {
          // Malformed frame: drop it, never crash the transport.
        }
      }
      index = this.buffer.indexOf('\n');
    }
    return frames;
  }
}

/** Runtime directory holding the socket, token, registry and journals. */
export function ptyRuntimeDir(env: NodeJS.ProcessEnv = process.env): string {
  // Explicit override wins: tests and sandboxed launches must be able to
  // isolate their host instead of sharing the per-user default (which would
  // leak live sessions across otherwise-isolated app instances).
  const override = env.AGENT_TOOLKIT_PTY_RUNTIME_DIR;
  if (override && path.isAbsolute(override)) return override;
  const xdg = env.XDG_RUNTIME_DIR;
  if (xdg && path.isAbsolute(xdg)) return path.join(xdg, 'agent-toolkit');
  return path.join(os.tmpdir(), `agent-toolkit-${os.userInfo().uid ?? 'user'}`);
}

export function ptySocketPath(runtimeDir: string): string {
  if (process.platform === 'win32') return String.raw`\\.\pipe\agent-toolkit-pty-host`;
  return path.join(runtimeDir, 'pty-host.sock');
}

export function ptyTokenPath(runtimeDir: string): string {
  return path.join(runtimeDir, 'pty-host.token');
}

export function ensureRuntimeDir(runtimeDir: string): void {
  fs.mkdirSync(runtimeDir, { recursive: true, mode: 0o700 });
  try {
    fs.chmodSync(runtimeDir, 0o700);
  } catch {
    // Best effort on filesystems without POSIX modes.
  }
}

/** Read the shared token, creating it (0600) when missing. */
export function readOrCreateToken(runtimeDir: string, create: () => string): string {
  try {
    const existing = fs.readFileSync(ptyTokenPath(runtimeDir), 'utf8').trim();
    if (existing) return existing;
  } catch {
    // No token yet.
  }
  const token = create();
  ensureRuntimeDir(runtimeDir);
  fs.writeFileSync(ptyTokenPath(runtimeDir), token, { mode: 0o600 });
  return token;
}
