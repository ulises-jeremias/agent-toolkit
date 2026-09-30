import { describe, expect, it } from 'vitest';
import type { BackendState } from '../types/electron';
import { backendBannerCopy, backendCanRestart } from './backend-copy';

const base: BackendState = {
  status: 'failed',
  url: null,
  version: null,
  detail: null,
  restarts: 0,
  harness: null,
  binary: null,
  rejected: [],
  problem: null,
};

describe('backendBannerCopy', () => {
  it('uses supervisor detail for failed and crashed so a stale binary is not "crashed"', () => {
    expect(
      backendBannerCopy({
        ...base,
        status: 'failed',
        problem: 'binary-rejected',
        detail: '/usr/bin/agent-toolkit (path, 1.16.0): too old: has no `serve` command',
      }),
    ).toBe('/usr/bin/agent-toolkit (path, 1.16.0): too old: has no `serve` command');
    expect(
      backendBannerCopy({
        ...base,
        status: 'crashed',
        problem: 'exited',
        detail: 'backend /opt/atk (path, 1.35.0) exited code=null signal=SIGKILL',
      }),
    ).toContain('SIGKILL');
  });

  it('names a version pin or missing Desktop gate from detail', () => {
    expect(
      backendBannerCopy({
        ...base,
        status: 'version-mismatch',
        problem: 'major-mismatch',
        version: '1.16.0',
        detail: 'backend /b reports 1.16.0; this Desktop build needs major 2',
      }),
    ).toContain('needs major 2');
    expect(
      backendBannerCopy({
        ...base,
        status: 'version-mismatch',
        problem: 'desktop-gate-missing',
        version: '1.35.0',
        detail: 'backend predates the X-Atk-Desktop first-party gate',
      }),
    ).toContain('X-Atk-Desktop');
  });

  it('keeps a starting prefix and a stopped fallback', () => {
    expect(backendBannerCopy({ ...base, status: 'starting', detail: 'selecting backend binary' })).toBe(
      'Starting the Agent Toolkit backend… selecting backend binary',
    );
    expect(backendBannerCopy({ ...base, status: 'stopped' })).toBe('Backend is stopped.');
  });
});

describe('backendCanRestart', () => {
  it('offers restart only after a terminal failure', () => {
    expect(backendCanRestart({ ...base, status: 'failed' })).toBe(true);
    expect(backendCanRestart({ ...base, status: 'crashed' })).toBe(true);
    expect(backendCanRestart({ ...base, status: 'stopped' })).toBe(true);
    expect(backendCanRestart({ ...base, status: 'starting' })).toBe(false);
    expect(backendCanRestart({ ...base, status: 'version-mismatch' })).toBe(false);
    expect(backendCanRestart({ ...base, status: 'ready' })).toBe(false);
  });
});
