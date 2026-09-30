// @vitest-environment node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { HarnessStore, MAX_RECENT_HARNESSES, parseHarnessStore } from './harness-store';

describe('HarnessStore', () => {
  let dir = '';
  let file = '';

  beforeEach(() => {
    dir = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-userdata-'));
    file = path.join(dir, 'harness.json');
  });

  afterEach(() => {
    fs.rmSync(dir, { recursive: true, force: true });
  });

  it('starts empty when no file exists and does not create one on read', () => {
    const store = new HarnessStore(file);
    expect(store.current()).toBeNull();
    expect(store.recent()).toEqual([]);
    expect(fs.existsSync(file)).toBe(false);
  });

  it('persists the choice and survives a reload', () => {
    new HarnessStore(file).setCurrent('/work/a');
    const reloaded = new HarnessStore(file);
    expect(reloaded.current()).toBe('/work/a');
    expect(reloaded.recent()).toEqual(['/work/a']);
    expect(JSON.parse(fs.readFileSync(file, 'utf8'))).toEqual({ version: 1, current: '/work/a', recent: ['/work/a'] });
  });

  it('keeps an MRU list: most recent first, de-duplicated, capped', () => {
    const store = new HarnessStore(file);
    for (let i = 0; i < MAX_RECENT_HARNESSES + 2; i += 1) store.setCurrent(`/work/${i}`);
    store.setCurrent('/work/3');
    const recent = store.recent();
    expect(recent[0]).toBe('/work/3');
    expect(recent).toHaveLength(MAX_RECENT_HARNESSES);
    expect(new Set(recent).size).toBe(recent.length);
    expect(recent).not.toContain('/work/0');
  });

  it('clearing the choice keeps the MRU list', () => {
    const store = new HarnessStore(file);
    store.setCurrent('/work/a');
    store.setCurrent(null);
    expect(new HarnessStore(file).current()).toBeNull();
    expect(new HarnessStore(file).recent()).toEqual(['/work/a']);
  });

  it('writes atomically: no temp files are left behind', () => {
    const store = new HarnessStore(file);
    store.setCurrent('/work/a');
    store.setCurrent('/work/b');
    expect(fs.readdirSync(dir)).toEqual(['harness.json']);
  });

  it('tolerates a corrupt or hostile file', () => {
    fs.writeFileSync(file, '{not json');
    expect(new HarnessStore(file).current()).toBeNull();
    expect(
      parseHarnessStore(
        JSON.stringify({ version: 7, current: 'relative/path', recent: ['/ok', 42, 'rel', '/ok', '/nul\0byte'], extra: true }),
      ),
    ).toEqual({ version: 1, current: null, recent: ['/ok'] });
  });
});
