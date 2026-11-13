import { createHash, randomBytes } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import type { FocusEvent, FocusEventBody, FocusThread } from '../../src/types/focus';

/**
 * Durable Focus history (ADR-044): one directory per thread holding
 * `thread.json` (metadata, rewritten atomically) and `events.jsonl`
 * (append-only). Production journals live in private app storage keyed by the
 * canonical workspace path. Legacy workspace journals are copied once and
 * kept in place as a nondestructive migration backup.
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

export function focusRoot(workspace: string, storageRoot?: string): string {
  // Without an explicit app root this is the legacy path, retained for old
  // history migration and focused tests.
  if (!storageRoot) return path.join(workspace, '.agent-toolkit', 'focus', 'threads');
  const canonicalWorkspace = fs.realpathSync(workspace);
  const workspaceKey = createHash('sha256').update(canonicalWorkspace).digest('hex');
  return path.join(canonicalStorageRoot(storageRoot), workspaceKey, 'threads');
}

function assertSafeJournalPath(workspace: string, target: string, storageRoot?: string): void {
  const root = storageRoot ? canonicalStorageRoot(storageRoot) : path.resolve(workspace);
  // Validate the ownership boundary itself, not only its descendants.
  try {
    if (fs.lstatSync(root).isSymbolicLink()) throw new Error('Symlink in Focus journal path');
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
  }
  const relative = path.relative(root, target);
  if (relative.startsWith('..') || path.isAbsolute(relative)) throw new Error('Journal path escapes workspace');
  let current = root;
  for (const part of relative.split(path.sep).filter(Boolean)) {
    current = path.join(current, part);
    try {
      if (fs.lstatSync(current).isSymbolicLink()) throw new Error('Symlink in Focus journal path');
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
    }
  }
}

function canonicalStorageRoot(storageRoot: string): string {
  const resolved = path.resolve(storageRoot);
  const parent = fs.realpathSync(path.dirname(resolved));
  return path.join(parent, path.basename(resolved));
}

function ensurePrivateDirectory(directory: string): void {
  const resolved = path.resolve(directory);
  const parent = path.dirname(resolved);
  try {
    fs.mkdirSync(resolved, { mode: 0o700 });
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'EEXIST') throw error;
  }
  const parentStat = fs.lstatSync(parent);
  const directoryStat = fs.lstatSync(resolved);
  if (parentStat.isSymbolicLink() || !parentStat.isDirectory()) throw new Error('Unsafe Focus journal storage root');
  if (directoryStat.isSymbolicLink() || !directoryStat.isDirectory()) {
    throw new Error('Unsafe Focus journal storage directory');
  }
  fs.chmodSync(resolved, 0o700);
}

function ensurePrivateJournalRoot(workspace: string, storageRoot: string): string {
  const canonicalBase = canonicalStorageRoot(storageRoot);
  ensurePrivateDirectory(canonicalBase);
  const workspaceRoot = path.dirname(focusRoot(workspace, canonicalBase));
  ensurePrivateDirectory(workspaceRoot);
  const threadsRoot = focusRoot(workspace, canonicalBase);
  ensurePrivateDirectory(threadsRoot);
  return threadsRoot;
}

function openRegularNoFollow(file: string, flags: number, mode?: number): number {
  const noFollow = fs.constants.O_NOFOLLOW ?? 0;
  const fd = fs.openSync(file, flags | noFollow, mode);
  try {
    const stat = fs.fstatSync(fd);
    if (!stat.isFile()) throw new Error('Focus journal path is not a regular file');
    if (stat.nlink > 1) throw new Error('Hard-linked Focus journal files are not allowed');
    return fd;
  } catch (error) {
    fs.closeSync(fd);
    throw error;
  }
}

function writeAtomic(file: string, content: string | Buffer): void {
  const tmp = `${file}.${randomBytes(8).toString('hex')}.tmp`;
  try {
    fs.writeFileSync(tmp, content, { mode: 0o600, flag: 'wx' });
    fs.renameSync(tmp, file);
  } finally {
    try {
      fs.unlinkSync(tmp);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
    }
  }
}

function readNoFollow(file: string): string {
  const fd = openRegularNoFollow(file, fs.constants.O_RDONLY);
  try {
    return fs.readFileSync(fd, 'utf8');
  } finally {
    fs.closeSync(fd);
  }
}

interface FileIdentity {
  dev: bigint;
  ino: bigint;
}

/** Snapshot every legacy path component so an ancestor swap cannot redirect a read. */
function workspacePathIdentity(workspace: string, file: string): FileIdentity[] {
  const root = path.resolve(workspace);
  const relative = path.relative(root, file);
  if (relative.startsWith('..') || path.isAbsolute(relative)) throw new Error('Legacy journal path escapes workspace');
  const parts = relative.split(path.sep).filter(Boolean);
  if (parts.length === 0) throw new Error('Legacy journal path is not a file');

  const identities: FileIdentity[] = [];
  let current = root;
  for (let index = -1; index < parts.length; index += 1) {
    if (index >= 0) current = path.join(current, parts[index]!);
    const stat = fs.lstatSync(current, { bigint: true });
    if (stat.isSymbolicLink()) throw new Error('Symlink in legacy Focus journal path');
    if (index < parts.length - 1 && !stat.isDirectory()) {
      throw new Error('Non-directory in legacy Focus journal path');
    }
    if (index === parts.length - 1 && (!stat.isFile() || stat.nlink > 1n)) {
      throw new Error('Legacy Focus journal path is not a private regular file');
    }
    identities.push({ dev: stat.dev, ino: stat.ino });
  }
  return identities;
}

function readWorkspaceBufferNoFollow(file: string, workspace: string): Buffer {
  const before = workspacePathIdentity(workspace, file);
  const fd = openRegularNoFollow(file, fs.constants.O_RDONLY);
  try {
    const opened = fs.fstatSync(fd, { bigint: true });
    const after = workspacePathIdentity(workspace, file);
    const unchanged =
      before.length === after.length &&
      before.every((identity, index) => {
        const next = after[index]!;
        return identity.dev === next.dev && identity.ino === next.ino;
      });
    const leaf = before[before.length - 1]!;
    if (!unchanged || opened.dev !== leaf.dev || opened.ino !== leaf.ino) {
      throw new Error('Legacy Focus journal path changed while opening');
    }
    return fs.readFileSync(fd);
  } finally {
    fs.closeSync(fd);
  }
}

function readWorkspaceNoFollow(file: string, workspace: string): string {
  return readWorkspaceBufferNoFollow(file, workspace).toString('utf8');
}

function readBufferNoFollow(file: string): Buffer {
  const fd = openRegularNoFollow(file, fs.constants.O_RDONLY);
  try {
    return fs.readFileSync(fd);
  } finally {
    fs.closeSync(fd);
  }
}

function appendNoFollow(file: string, content: string): void {
  const fd = openRegularNoFollow(file, fs.constants.O_WRONLY | fs.constants.O_APPEND | fs.constants.O_CREAT, 0o600);
  try {
    fs.writeFileSync(fd, content);
  } finally {
    fs.closeSync(fd);
  }
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
  private readonly storageRoot?: string;

  constructor(
    workspace: string,
    private meta: FocusThread,
    storageRoot?: string,
  ) {
    this.storageRoot = storageRoot ? canonicalStorageRoot(storageRoot) : undefined;
    this.dir = path.join(focusRoot(workspace, this.storageRoot), meta.id);
  }

  static create(workspace: string, meta: FocusThread, storageRoot?: string): ThreadJournal {
    const journal = new ThreadJournal(workspace, meta, storageRoot);
    if (storageRoot) ensurePrivateJournalRoot(workspace, storageRoot);
    journal.assertSafe(journal.dir);
    fs.mkdirSync(journal.dir, { recursive: !storageRoot, mode: 0o700 });
    journal.assertSafe(journal.dir);
    journal.seq = 0;
    journal.saveMeta();
    return journal;
  }

  /** Load one thread's metadata; null when it is missing, unreadable or malformed. */
  static open(workspace: string, id: string, storageRoot?: string): ThreadJournal | null {
    if (!isThreadId(id)) return null;
    const file = path.join(focusRoot(workspace, storageRoot), id, 'thread.json');
    let raw: unknown;
    try {
      assertSafeJournalPath(workspace, file, storageRoot);
      raw = JSON.parse(storageRoot ? readNoFollow(file) : readWorkspaceNoFollow(file, workspace));
    } catch {
      return null;
    }
    const meta = parseThread(raw, id, workspace);
    return meta ? new ThreadJournal(workspace, meta, storageRoot) : null;
  }

  static list(workspace: string, storageRoot?: string): ThreadJournal[] {
    let names: string[];
    try {
      if (storageRoot) {
        ensurePrivateJournalRoot(workspace, storageRoot);
        migrateLegacyJournals(workspace, storageRoot);
      }
      const root = focusRoot(workspace, storageRoot);
      assertSafeJournalPath(workspace, root, storageRoot);
      names = fs.readdirSync(root);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') return [];
      throw error;
    }
    const journals: ThreadJournal[] = [];
    for (const name of names) {
      const journal = ThreadJournal.open(workspace, name, storageRoot);
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
    this.assertSafe(file);
    if (this.seq === null) {
      this.seq = this.readEvents().reduce((max, event) => Math.max(max, event.seq), 0);
      // A crash can leave a line without its newline. Terminate it so the next
      // event starts on its own line instead of being glued to the fragment.
      if (endsWithoutNewline(file)) appendNoFollow(file, '\n');
    }
    this.seq += 1;
    const event = { seq: this.seq, at: new Date().toISOString(), turn, ...body } as FocusEvent;
    appendNoFollow(file, `${JSON.stringify(event)}\n`);
    return event;
  }

  /** Tolerates torn or corrupt lines: they are skipped, the rest stays readable. */
  readEvents(): FocusEvent[] {
    let raw: string;
    try {
      this.assertSafe(this.eventsFile());
      raw = readNoFollow(this.eventsFile());
    } catch (error) {
      // A missing log is an empty history; a rejected path or I/O failure is not.
      // Silently returning [] here would disguise journal tampering as data loss.
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') return [];
      throw error;
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
    this.assertSafe(this.dir);
    fs.rmSync(this.dir, { recursive: true, force: true });
  }

  private assertSafe(file: string): void {
    assertSafeJournalPath(this.meta.workspace, file, this.storageRoot);
  }

  private eventsFile(): string {
    return path.join(this.dir, 'events.jsonl');
  }

  private saveMeta(): void {
    const file = path.join(this.dir, 'thread.json');
    this.assertSafe(file);
    writeAtomic(file, `${JSON.stringify(this.meta, null, 2)}\n`);
  }
}

function migrateLegacyJournals(workspace: string, storageRoot: string): void {
  const destinationRoot = ensurePrivateJournalRoot(workspace, storageRoot);
  const marker = path.join(path.dirname(destinationRoot), 'migration-v1.json');
  try {
    assertSafeJournalPath(workspace, marker, storageRoot);
    const migration = JSON.parse(readNoFollow(marker)) as { version?: unknown };
    if (migration.version === 1) return;
    throw new Error('Unrecognized Focus journal migration marker');
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
  }

  const legacyRoot = focusRoot(workspace);
  let names: string[];
  try {
    assertSafeJournalPath(workspace, legacyRoot);
    names = fs.readdirSync(legacyRoot);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') names = [];
    else throw error;
  }

  for (const id of names) {
    if (!isThreadId(id)) continue;
    const destination = path.join(destinationRoot, id);
    const legacy = ThreadJournal.open(workspace, id);
    if (!legacy) throw new Error(`Could not safely migrate Focus thread ${id}`);
    const legacyMeta = path.join(legacyRoot, id, 'thread.json');
    // Preserve source bytes exactly, including unknown fields and torn event
    // records. Parsing above validates metadata without lossy serialization.
    const metadata = readWorkspaceBufferNoFollow(legacyMeta, workspace);
    let events: Buffer | null = null;
    const legacyEvents = path.join(legacyRoot, id, 'events.jsonl');
    try {
      assertSafeJournalPath(workspace, legacyEvents);
      events = readWorkspaceBufferNoFollow(legacyEvents, workspace);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
    }

    try {
      const existing = fs.lstatSync(destination);
      if (existing.isSymbolicLink() || !existing.isDirectory() || !ThreadJournal.open(workspace, id, storageRoot)) {
        throw new Error(`Could not safely resume Focus thread migration ${id}`);
      }
      const privateMeta = path.join(destination, 'thread.json');
      assertSafeJournalPath(workspace, privateMeta, storageRoot);
      const privateMetadata = readBufferNoFollow(privateMeta);
      let privateEvents: Buffer | null = null;
      const privateEventsPath = path.join(destination, 'events.jsonl');
      try {
        assertSafeJournalPath(workspace, privateEventsPath, storageRoot);
        privateEvents = readBufferNoFollow(privateEventsPath);
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
      }
      const eventsMatch =
        (privateEvents === null && events === null) ||
        (privateEvents !== null && events !== null && privateEvents.equals(events));
      if (!privateMetadata.equals(metadata) || !eventsMatch) {
        throw new Error(`Could not safely resume Focus thread migration ${id}`);
      }
      continue;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
    }

    const staging = path.join(destinationRoot, `.migrate-${id}-${randomBytes(8).toString('hex')}`);
    fs.mkdirSync(staging, { mode: 0o700 });
    try {
      writeAtomic(path.join(staging, 'thread.json'), metadata);
      if (events) writeAtomic(path.join(staging, 'events.jsonl'), events);
      fs.renameSync(staging, destination);
    } finally {
      try {
        fs.rmSync(staging, { recursive: true, force: true });
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
      }
    }
  }

  writeAtomic(marker, `${JSON.stringify({ version: 1 })}\n`);
}

function endsWithoutNewline(file: string): boolean {
  let fd: number;
  try {
    fd = openRegularNoFollow(file, fs.constants.O_RDONLY);
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
