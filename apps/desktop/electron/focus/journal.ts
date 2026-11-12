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

export class ThreadJournal {
  private seq = 0;
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
    journal.saveMeta();
    return journal;
  }

  /** Load one thread; returns null when the directory is missing or unreadable. */
  static open(workspace: string, id: string): ThreadJournal | null {
    if (!isThreadId(id)) return null;
    const file = path.join(focusRoot(workspace), id, 'thread.json');
    let meta: FocusThread;
    try {
      meta = JSON.parse(fs.readFileSync(file, 'utf8')) as FocusThread;
    } catch {
      return null;
    }
    if (!meta || meta.id !== id) return null;
    const journal = new ThreadJournal(workspace, meta);
    journal.seq = journal.readEvents().reduce((max, event) => Math.max(max, event.seq), 0);
    return journal;
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
    this.seq += 1;
    const event = { seq: this.seq, at: new Date().toISOString(), turn, ...body } as FocusEvent;
    fs.appendFileSync(path.join(this.dir, 'events.jsonl'), `${JSON.stringify(event)}\n`, { mode: 0o600 });
    return event;
  }

  /** Tolerates a torn final line (crash mid-append): it is skipped, not fatal. */
  readEvents(): FocusEvent[] {
    let raw: string;
    try {
      raw = fs.readFileSync(path.join(this.dir, 'events.jsonl'), 'utf8');
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
        // Torn or corrupt line: keep the rest of the history readable.
      }
    }
    return events;
  }

  remove(): void {
    fs.rmSync(this.dir, { recursive: true, force: true });
  }

  private saveMeta(): void {
    writeAtomic(path.join(this.dir, 'thread.json'), `${JSON.stringify(this.meta, null, 2)}\n`);
  }
}
