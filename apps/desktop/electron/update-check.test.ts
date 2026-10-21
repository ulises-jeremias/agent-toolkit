// @vitest-environment node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { isNewerVersion, parseLatestRelease, parseVersion, UpdateChecker } from './update-check';

describe('parseVersion / isNewerVersion', () => {
  it('parses plain, v-prefixed and prerelease versions', () => {
    expect(parseVersion('1.47.5')).toEqual({ core: [1, 47, 5], prerelease: '' });
    expect(parseVersion('v1.47.5')).toEqual({ core: [1, 47, 5], prerelease: '' });
    expect(parseVersion('1.48.0-beta.1')?.prerelease).toBe('beta.1');
    expect(parseVersion('not-a-version')).toBeNull();
    expect(parseVersion('')).toBeNull();
  });

  it('compares cores numerically, not lexically', () => {
    expect(isNewerVersion('1.47.10', '1.47.9')).toBe(true);
    expect(isNewerVersion('1.47.9', '1.47.10')).toBe(false);
    expect(isNewerVersion('v2.0.0', '1.99.99')).toBe(true);
    expect(isNewerVersion('1.47.5', '1.47.5')).toBe(false);
  });

  it('treats a full release as newer than its own prerelease', () => {
    expect(isNewerVersion('1.48.0', '1.48.0-beta.1')).toBe(true);
    expect(isNewerVersion('1.48.0-beta.1', '1.48.0')).toBe(false);
    expect(isNewerVersion('garbage', '1.0.0')).toBe(false);
  });
});

describe('parseLatestRelease', () => {
  it('reads tag + URL and rejects drafts or junk', () => {
    expect(parseLatestRelease('{"tag_name":"v1.48.0","html_url":"https://example.invalid/r"}')).toEqual({
      version: '1.48.0',
      url: 'https://example.invalid/r',
    });
    expect(parseLatestRelease('{"tag_name":"v1.48.0","draft":true}')).toBeNull();
    expect(parseLatestRelease('{"tag_name":"weekly"}')).toBeNull();
    expect(parseLatestRelease('not json')).toBeNull();
  });
});

describe('UpdateChecker', () => {
  const okFetch =
    (version: string) =>
    async () => ({
      ok: true,
      status: 200,
      text: async () => JSON.stringify({ tag_name: `v${version}`, html_url: 'https://example.invalid/r' }),
    });

  it('reports an available update from a live check and caches it', async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-update-'));
    const cachePath = path.join(dir, 'update-check.json');
    let calls = 0;
    const base = okFetch('1.48.0');
    const checker = new UpdateChecker({
      currentVersion: '1.47.5',
      cachePath,
      now: () => 1_000_000,
      fetchFn: async () => {
        calls++;
        return base();
      },
    });
    const first = await checker.status();
    expect(first).toMatchObject({ latest: '1.48.0', updateAvailable: true, source: 'live' });
    const second = await checker.status();
    expect(second.source).toBe('cache');
    expect(calls).toBe(1);
  });

  it('degrades to unavailable when the check fails and no cache exists', async () => {
    const checker = new UpdateChecker({
      currentVersion: '1.47.5',
      cachePath: path.join(os.tmpdir(), 'atk-update-missing', 'update-check.json'),
      fetchFn: async () => {
        throw new Error('offline');
      },
    });
    const status = await checker.status();
    expect(status).toMatchObject({ latest: null, updateAvailable: false, source: 'unavailable' });
    expect(status.detail).toContain('offline');
  });

  it('falls back to a stale cache when the live check fails', async () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-update-'));
    const cachePath = path.join(dir, 'update-check.json');
    fs.writeFileSync(
      cachePath,
      JSON.stringify({ latest: '1.48.0', releaseUrl: 'https://example.invalid/r', checkedAtMs: 0 }),
    );
    const checker = new UpdateChecker({
      currentVersion: '1.47.5',
      cachePath,
      now: () => 10 * 24 * 60 * 60 * 1000,
      fetchFn: async () => {
        throw new Error('offline');
      },
    });
    const status = await checker.status();
    expect(status).toMatchObject({ latest: '1.48.0', updateAvailable: true, source: 'cache' });
  });
});
