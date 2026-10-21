import fs from 'node:fs';
import path from 'node:path';

/**
 * Notify-only Desktop update check (Pack H gap 1, issue #543 policy).
 *
 * Desktop artifacts are not yet code-signed, so the app never downloads
 * or applies an update by itself: it asks the GitHub releases API for
 * the latest published release (5 s timeout, 24 h on-disk cache) and
 * reports whether a newer version exists. The user follows the release
 * link and installs manually, as documented in docs/TRUST.md. Signing
 * + a real updater feed replace this once certificates exist.
 */

export const UPDATE_RELEASES_API = 'https://api.github.com/repos/ulises-jeremias/agent-toolkit/releases/latest';
export const UPDATE_CACHE_TTL_MS = 24 * 60 * 60 * 1000;
export const UPDATE_FETCH_TIMEOUT_MS = 5_000;

export interface UpdateStatus {
  current: string;
  latest: string | null;
  updateAvailable: boolean;
  releaseUrl: string | null;
  /** ISO timestamp of the last successful live check, when known. */
  checkedAt: string | null;
  source: 'live' | 'cache' | 'unavailable';
  detail: string;
}

interface UpdateCache {
  latest: string;
  releaseUrl: string | null;
  checkedAtMs: number;
}

type FetchFn = (url: string, init: { signal: AbortSignal; headers: Record<string, string> }) => Promise<{
  ok: boolean;
  status: number;
  text: () => Promise<string>;
}>;

/** Parse `v1.47.5` / `1.47.5` / `1.47.5-beta.1` into comparable parts. */
export function parseVersion(raw: string): { core: [number, number, number]; prerelease: string } | null {
  const text = raw.trim().replace(/^v/i, '');
  const [corePart, ...rest] = text.split('-');
  const parts = corePart.split('.');
  if (parts.length < 1 || parts.length > 3) return null;
  const core: [number, number, number] = [0, 0, 0];
  for (let i = 0; i < parts.length; i++) {
    if (!/^\d+$/.test(parts[i])) return null;
    core[i] = Number(parts[i]);
  }
  return { core, prerelease: rest.join('-') };
}

/** True when `latest` is a strictly newer release than `current`. */
export function isNewerVersion(latest: string, current: string): boolean {
  const a = parseVersion(latest);
  const b = parseVersion(current);
  if (!a || !b) return false;
  for (let i = 0; i < 3; i++) {
    if (a.core[i] !== b.core[i]) return a.core[i] > b.core[i];
  }
  // Same core: a full release is newer than a prerelease of it.
  if (a.prerelease === b.prerelease) return false;
  if (a.prerelease === '') return true;
  if (b.prerelease === '') return false;
  return a.prerelease > b.prerelease;
}

/** Extract the version + page URL from a GitHub `releases/latest` body. */
export function parseLatestRelease(text: string): { version: string; url: string | null } | null {
  try {
    const data = JSON.parse(text) as { tag_name?: unknown; html_url?: unknown; draft?: unknown };
    if (data.draft === true || typeof data.tag_name !== 'string') return null;
    const version = data.tag_name.trim().replace(/^v/i, '');
    if (!parseVersion(version)) return null;
    return { version, url: typeof data.html_url === 'string' ? data.html_url : null };
  } catch {
    return null;
  }
}

export interface UpdateCheckerOptions {
  currentVersion: string;
  cachePath: string;
  fetchFn?: FetchFn;
  now?: () => number;
}

export class UpdateChecker {
  private readonly current: string;
  private readonly cachePath: string;
  private readonly fetchFn: FetchFn;
  private readonly now: () => number;
  private pending: Promise<UpdateStatus> | null = null;

  constructor(options: UpdateCheckerOptions) {
    this.current = options.currentVersion;
    this.cachePath = options.cachePath;
    this.fetchFn = options.fetchFn ?? ((url, init) => fetch(url, init));
    this.now = options.now ?? (() => Date.now());
  }

  /** Cached when fresh; otherwise one shared live check. Never throws. */
  status(): Promise<UpdateStatus> {
    const cached = this.readCache();
    if (cached && this.now() - cached.checkedAtMs < UPDATE_CACHE_TTL_MS) {
      return Promise.resolve(this.toStatus(cached, 'cache', 'Checked within the last 24 hours.'));
    }
    this.pending ??= this.checkLive(cached).finally(() => {
      this.pending = null;
    });
    return this.pending;
  }

  private async checkLive(stale: UpdateCache | null): Promise<UpdateStatus> {
    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), UPDATE_FETCH_TIMEOUT_MS);
      let response: Awaited<ReturnType<FetchFn>>;
      try {
        response = await this.fetchFn(UPDATE_RELEASES_API, {
          signal: controller.signal,
          headers: { accept: 'application/vnd.github+json', 'user-agent': 'agent-toolkit-desktop' },
        });
      } finally {
        clearTimeout(timer);
      }
      if (!response.ok) throw new Error(`release check returned HTTP ${response.status}`);
      const release = parseLatestRelease(await response.text());
      if (!release) throw new Error('release check returned an unreadable response');
      const entry: UpdateCache = { latest: release.version, releaseUrl: release.url, checkedAtMs: this.now() };
      this.writeCache(entry);
      return this.toStatus(entry, 'live', '');
    } catch (error) {
      if (stale) {
        return this.toStatus(stale, 'cache', 'Update check failed; showing the last known result.');
      }
      return {
        current: this.current,
        latest: null,
        updateAvailable: false,
        releaseUrl: null,
        checkedAt: null,
        source: 'unavailable',
        detail: `Update check unavailable (${error instanceof Error ? error.message : 'network error'}).`,
      };
    }
  }

  private toStatus(entry: UpdateCache, source: UpdateStatus['source'], detail: string): UpdateStatus {
    return {
      current: this.current,
      latest: entry.latest,
      updateAvailable: isNewerVersion(entry.latest, this.current),
      releaseUrl: entry.releaseUrl,
      checkedAt: new Date(entry.checkedAtMs).toISOString(),
      source,
      detail,
    };
  }

  private readCache(): UpdateCache | null {
    try {
      const data = JSON.parse(fs.readFileSync(this.cachePath, 'utf8')) as Partial<UpdateCache>;
      if (typeof data.latest !== 'string' || typeof data.checkedAtMs !== 'number') return null;
      if (!parseVersion(data.latest)) return null;
      return {
        latest: data.latest,
        releaseUrl: typeof data.releaseUrl === 'string' ? data.releaseUrl : null,
        checkedAtMs: data.checkedAtMs,
      };
    } catch {
      return null;
    }
  }

  private writeCache(entry: UpdateCache): void {
    try {
      fs.mkdirSync(path.dirname(this.cachePath), { recursive: true });
      fs.writeFileSync(this.cachePath, JSON.stringify(entry));
    } catch {
      // Cache is an optimization; a read-only profile must not fail the check.
    }
  }
}
