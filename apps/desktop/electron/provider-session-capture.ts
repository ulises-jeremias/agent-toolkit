import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

/**
 * Provider session-id capture for runners that do not accept an assigned
 * session id at launch (Slice 4). Codex is the only capture strategy:
 * it writes `sessions/YYYY/MM/DD/rollout-<ts>-<id>.jsonl` under
 * `$CODEX_HOME` (default `~/.codex`) whose first line is a `session_meta`
 * record carrying the conversation `id` and the `cwd` it belongs to.
 *
 * Capture is best-effort and strictly scoped: only files modified at or
 * after the spawn window and whose recorded cwd matches the PTY cwd are
 * accepted. No match simply means the session is not resumable — it is
 * never guessed from "the newest session overall", which could belong to
 * a different project or user action.
 */

export function codexHomeDir(env: NodeJS.ProcessEnv = process.env): string {
  const custom = env.CODEX_HOME;
  if (custom && path.isAbsolute(custom)) return custom;
  return path.join(os.homedir(), '.codex');
}

export interface CodexCaptureOptions {
  cwd: string;
  /** Spawn time (epoch ms); files older than this minus a skew allowance are ignored. */
  sinceMs: number;
  codexHome?: string;
  timeoutMs?: number;
  intervalMs?: number;
  /** Abort early (e.g. the PTY already exited). */
  shouldContinue?: () => boolean;
}

const SKEW_MS = 10_000;

function readMeta(file: string): { id: string; cwd: string } | null {
  try {
    const fd = fs.openSync(file, 'r');
    try {
      const buffer = Buffer.alloc(64 * 1024);
      const read = fs.readSync(fd, buffer, 0, buffer.length, 0);
      const firstLine = buffer.toString('utf8', 0, read).split('\n', 1)[0];
      if (!firstLine) return null;
      const parsed = JSON.parse(firstLine) as { type?: string; payload?: { id?: string; cwd?: string } };
      if (parsed.type !== 'session_meta') return null;
      const id = parsed.payload?.id;
      const cwd = parsed.payload?.cwd;
      if (typeof id !== 'string' || typeof cwd !== 'string') return null;
      return { id, cwd };
    } finally {
      fs.closeSync(fd);
    }
  } catch {
    return null;
  }
}

function* rolloutFiles(root: string): Generator<string> {
  const sessionsDir = path.join(root, 'sessions');
  let years: string[];
  try {
    years = fs.readdirSync(sessionsDir);
  } catch {
    return;
  }
  for (const year of years) {
    const yearDir = path.join(sessionsDir, year);
    let months: string[];
    try {
      months = fs.readdirSync(yearDir);
    } catch {
      continue;
    }
    for (const month of months) {
      const monthDir = path.join(yearDir, month);
      let days: string[];
      try {
        days = fs.readdirSync(monthDir);
      } catch {
        continue;
      }
      for (const day of days) {
        const dayDir = path.join(monthDir, day);
        let files: string[];
        try {
          files = fs.readdirSync(dayDir);
        } catch {
          continue;
        }
        for (const file of files) {
          if (file.startsWith('rollout-') && file.endsWith('.jsonl')) yield path.join(dayDir, file);
        }
      }
    }
  }
}

export async function captureCodexSessionId(options: CodexCaptureOptions): Promise<string | null> {
  const root = options.codexHome ?? codexHomeDir();
  const timeoutMs = options.timeoutMs ?? 60_000;
  const intervalMs = options.intervalMs ?? 500;
  const deadline = Date.now() + timeoutMs;
  const wantedCwd = path.resolve(options.cwd);
  for (;;) {
    if (options.shouldContinue && !options.shouldContinue()) return null;
    for (const file of rolloutFiles(root)) {
      let mtimeMs = 0;
      try {
        mtimeMs = fs.statSync(file).mtimeMs;
      } catch {
        continue;
      }
      if (mtimeMs < options.sinceMs - SKEW_MS) continue;
      const meta = readMeta(file);
      if (meta && path.resolve(meta.cwd) === wantedCwd) return meta.id;
    }
    if (Date.now() >= deadline) return null;
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
}
