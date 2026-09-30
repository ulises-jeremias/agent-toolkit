import fs from 'node:fs';
import path from 'node:path';

export const HARNESS_STORE_FILE = 'harness.json';
export const MAX_RECENT_HARNESSES = 8;

/** On-disk shape of `<userData>/harness.json`. */
export interface HarnessStoreData {
  version: 1;
  /** Harness chosen in Desktop; null = no choice (use the default). */
  current: string | null;
  /** Most recently used first; always contains `current` when set. */
  recent: string[];
}

const EMPTY: HarnessStoreData = { version: 1, current: null, recent: [] };

function isAbsoluteString(value: unknown): value is string {
  return typeof value === 'string' && value.length > 0 && path.isAbsolute(value) && !value.includes('\0');
}

/** Tolerant parse: unknown fields are dropped, invalid entries skipped, never throws. */
export function parseHarnessStore(raw: string): HarnessStoreData {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return { ...EMPTY, recent: [] };
  }
  if (typeof parsed !== 'object' || parsed === null) return { ...EMPTY, recent: [] };
  const record = parsed as Record<string, unknown>;
  const current = isAbsoluteString(record.current) ? record.current : null;
  const recent: string[] = [];
  if (Array.isArray(record.recent)) {
    for (const entry of record.recent) {
      if (isAbsoluteString(entry) && !recent.includes(entry)) recent.push(entry);
      if (recent.length >= MAX_RECENT_HARNESSES) break;
    }
  }
  return { version: 1, current, recent };
}

/**
 * Write-then-rename in the same directory so a crash or power loss leaves
 * either the old or the new file, never a truncated one.
 */
export function writeFileAtomic(file: string, contents: string): void {
  const dir = path.dirname(file);
  fs.mkdirSync(dir, { recursive: true });
  const tmp = path.join(dir, `.${path.basename(file)}.${process.pid}.${Date.now()}.tmp`);
  const fd = fs.openSync(tmp, 'w', 0o600);
  try {
    fs.writeSync(fd, contents);
    fs.fsyncSync(fd);
  } finally {
    fs.closeSync(fd);
  }
  try {
    fs.renameSync(tmp, file);
  } catch (error) {
    fs.rmSync(tmp, { force: true });
    throw error;
  }
}

/** Desktop-owned harness preference (chosen harness + MRU), stored in app userData. */
export class HarnessStore {
  private data: HarnessStoreData;

  constructor(private readonly file: string) {
    this.data = HarnessStore.load(file);
  }

  static load(file: string): HarnessStoreData {
    try {
      return parseHarnessStore(fs.readFileSync(file, 'utf8'));
    } catch {
      return { ...EMPTY, recent: [] };
    }
  }

  get path(): string {
    return this.file;
  }

  current(): string | null {
    return this.data.current;
  }

  recent(): string[] {
    return [...this.data.recent];
  }

  /** Persist a choice (null clears it) and bump it to the front of the MRU list. */
  setCurrent(harness: string | null): void {
    const recent = harness
      ? [harness, ...this.data.recent.filter((entry) => entry !== harness)].slice(0, MAX_RECENT_HARNESSES)
      : this.data.recent;
    const next: HarnessStoreData = { version: 1, current: harness, recent };
    writeFileAtomic(this.file, `${JSON.stringify(next, null, 2)}\n`);
    this.data = next;
  }
}
