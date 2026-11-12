import { randomBytes } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import type { FocusEvent, FocusEventBody, FocusThread } from '../../src/types/focus';

/**
 * Durable Focus history (ADR-044): one directory per thread under
 * `<workspace>/.agent-toolkit/focus/threads/<id>/` holding `thread.json`
 * (metadata, rewritten atomically) and `events.jsonl` (append-only).
 *
 * The journal is the only source of truth for what happened in a session.
 * Streaming deltas are never written; a crash can therefore lose at most the
 * text of the block being streamed, never a completed item.
 */

const THREAD_ID = /^th_[a-z0-9]{10,40}$/;
const PROVIDERS = ['claude', 'codex', 'opencode'];
const MODES = ['ask', 'accept-edits', 'plan', 'bypass'];
const STATUSES = ['idle', 'running', 'awaiting-approval', 'interrupted', 'error'];

export function isThreadId(value: unknown): value is string {
  return typeof value === 'string' && THREAD_ID.test(value);
}

export function newThreadId(now = Date.now()): string {
  // Time-prefixed so directory listings sort by creation.
  return `th_${now.toString(36)}${randomBytes(6).toString('hex')}`;
}

export function focusRoot(workspace: string): string {
  return path.join(workspace, '.agent-toolkit', 'focus', 'threads');
}

function writeAtomic(file: string, content: string): void {
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, content, { mode: 0o600 });
  fs.renameSync(tmp, file);
}

function text(value: unknown, fallback: string | null = null): string | null {
  return typeof value === 'string' ? value : fallback;
}

function count(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? value : 0;
}

/**
 * `thread.json` lives in a folder other tools and people can write to, so it
 * is read as untrusted data: unknown enum values or a missing path make the
 * thread unreadable rather than half-trusted.
 */
export function parseThread(raw: unknown, id: string, workspace: string): FocusThread | null {
  if (typeof raw !== 'object' || raw === null) return null;
  const data = raw as Record<string, unknown>;
  const cwd = text(data['cwd']);
  const provider = text(data['provider']);
  const permissionMode = text(data['permissionMode']);
  const status = text(data['status']);
  if (data['id'] !== id || !cwd || !path.isAbsolute(cwd)) return null;
  if (!provider || !PROVIDERS.includes(provider)) return null;
  if (!permissionMode || !MODES.includes(permissionMode)) return null;
  if (!status || !STATUSES.includes(status)) return null;
  const usage = (typeof data['usage'] === 'object' && data['usage'] !== null ? data['usage'] : {}) as Record<
    string,
    unknown
  >;
  const now = new Date(0).toISOString();
  return {
    id,
    title: (text(data['title']) ?? '').slice(0, 120),
    workspace,
    projectName: text(data['projectName']),
    cwd,
    provider: provider as FocusThread['provider'],
    model: text(data['model']),
    resolvedModel: text(data['resolvedModel']),
    permissionMode: permissionMode as FocusThread['permissionMode'],
    providerSessionId: text(data['providerSessionId']),
    status: status as FocusThread['status'],
    createdAt: text(data['createdAt']) ?? now,
    updatedAt: text(data['updatedAt']) ?? text(data['createdAt']) ?? now,
    turns: count(data['turns']),
    lastError: text(data['lastError']),
    usage: {
      inputTokens: count(usage['inputTokens']),
      cachedInputTokens: count(usage['cachedInputTokens']),
      outputTokens: count(usage['outputTokens']),
      costUsd: typeof usage['costUsd'] === 'number' ? usage['costUsd'] : null,
    },
  };
}

export class ThreadJournal {
  /** Last sequence number written; null until the event log has been read once. */
  private seq: number | null = null;
  private readonly dir: string;

  constructor(
    workspace: string,
    private meta: FocusThread,
  ) {
    this.dir = path.join(focusRoot(workspace), meta.id);
  }

  static create(workspace: string, meta: FocusThread): ThreadJournal {
    const journal = new ThreadJournal(workspace, meta);
    fs.mkdirSync(journal.dir, { recursive: true, mode: 0o700 });
    journal.seq = 0;
    journal.saveMeta();
    return journal;
  }

  /** Load one thread's metadata; null when it is missing, unreadable or malformed. */
  static open(workspace: string, id: string): ThreadJournal | null {
    if (!isThreadId(id)) return null;
    const file = path.join(focusRoot(workspace), id, 'thread.json');
    let raw: unknown;
    try {
      raw = JSON.parse(fs.readFileSync(file, 'utf8'));
    } catch {
      return null;
    }
    const meta = parseThread(raw, id, workspace);
    return meta ? new ThreadJournal(workspace, meta) : null;
  }

  static list(workspace: string): ThreadJournal[] {
    let names: string[];
    try {
      names = fs.readdirSync(focusRoot(workspace));
    } catch {
      return [];
    }
    const journals: ThreadJournal[] = [];
    for (const name of names) {
      const journal = ThreadJournal.open(workspace, name);
      if (journal) journals.push(journal);
    }
    return journals;
  }

  get thread(): FocusThread {
    return this.meta;
  }

  update(patch: Partial<FocusThread>): FocusThread {
    this.meta = { ...this.meta, ...patch, id: this.meta.id, updatedAt: new Date().toISOString() };
    this.saveMeta();
    return this.meta;
  }

  append(turn: number, body: FocusEventBody): FocusEvent {
    const file = this.eventsFile();
    if (this.seq === null) {
      this.seq = this.readEvents().reduce((max, event) => Math.max(max, event.seq), 0);
      // A crash can leave a line without its newline. Terminate it so the next
      // event starts on its own line instead of being glued to the fragment.
      if (endsWithoutNewline(file)) fs.appendFileSync(file, '\n');
    }
    this.seq += 1;
    const event = { seq: this.seq, at: new Date().toISOString(), turn, ...body } as FocusEvent;
    fs.appendFileSync(file, `${JSON.stringify(event)}\n`, { mode: 0o600 });
    return event;
  }

  /** Tolerates torn or corrupt lines: they are skipped, the rest stays readable. */
  readEvents(): FocusEvent[] {
    let raw: string;
    try {
      raw = fs.readFileSync(this.eventsFile(), 'utf8');
    } catch {
      return [];
    }
    const events: FocusEvent[] = [];
    for (const line of raw.split('\n')) {
      if (!line) continue;
      try {
        const event = JSON.parse(line) as FocusEvent;
        if (typeof event.seq === 'number' && typeof event.type === 'string') events.push(event);
      } catch {
        // Torn or corrupt line.
      }
    }
    return events;
  }

  remove(): void {
    fs.rmSync(this.dir, { recursive: true, force: true });
  }

  private eventsFile(): string {
    return path.join(this.dir, 'events.jsonl');
  }

  private saveMeta(): void {
    writeAtomic(path.join(this.dir, 'thread.json'), `${JSON.stringify(this.meta, null, 2)}\n`);
  }
}

function endsWithoutNewline(file: string): boolean {
  let fd: number;
  try {
    fd = fs.openSync(file, 'r');
  } catch {
    return false;
  }
  try {
    const { size } = fs.fstatSync(fd);
    if (size === 0) return false;
    const last = Buffer.alloc(1);
    fs.readSync(fd, last, 0, 1, size - 1);
    return last[0] !== 0x0a;
  } finally {
    fs.closeSync(fd);
  }
}
