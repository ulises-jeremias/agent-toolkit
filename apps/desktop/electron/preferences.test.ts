import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import { DesktopPreferenceStore, validatePreferences } from './preferences';

const roots: string[] = [];
function userData(): string {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-desktop-preferences-'));
  roots.push(root);
  return root;
}

afterEach(() => {
  for (const root of roots.splice(0)) fs.rmSync(root, { recursive: true, force: true });
});

describe('DesktopPreferenceStore', () => {
  it('persists only validated preferences across store instances', () => {
    const dir = userData();
    const store = new DesktopPreferenceStore(dir);
    store.set({
      onboardingComplete: true,
      theme: 'dusk',
      motion: 'reduced',
      routes: {
        '/home/user/workspace': { pathname: '/focus', search: '?project=web&thread=thread_1&pty=secret' },
      },
    });

    const restored = new DesktopPreferenceStore(dir).read();
    expect(restored).toMatchObject({ onboardingComplete: true, theme: 'dusk', motion: 'reduced' });
    expect(restored.routes['/home/user/workspace']).toEqual({
      pathname: '/focus',
      search: '?workspace=%2Fhome%2Fuser%2Fworkspace&project=web&thread=thread_1',
    });
    expect(fs.statSync(path.join(dir, 'desktop-preferences.json')).mode & 0o777).toBe(0o600);
  });

  it('rejects unknown destinations, non-absolute workspaces and invalid scope values', () => {
    const safe = validatePreferences({
      version: 1,
      routes: {
        relative: { pathname: '/focus', search: '' },
        '/workspace/one': { pathname: 'https://example.com', search: '?thread=abc' },
        '/workspace/two': { pathname: '/focus', search: '?thread=../../etc/passwd&project=valid' },
      },
    });
    expect(safe.routes).toEqual({
      '/workspace/two': { pathname: '/focus', search: '?workspace=%2Fworkspace%2Ftwo&project=valid' },
    });
  });

  it('recovers from malformed files and writes atomically on the next change', () => {
    const dir = userData();
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, 'desktop-preferences.json'), '{broken');
    const store = new DesktopPreferenceStore(dir);
    expect(store.read().onboardingComplete).toBe(false);
    store.set({ onboardingComplete: true });
    expect(new DesktopPreferenceStore(dir).read().onboardingComplete).toBe(true);
    expect(fs.readdirSync(dir)).toEqual(['desktop-preferences.json']);
  });
});
