import { describe, expect, it } from 'vitest';
import type { PtySessionInfo } from '../types/electron';
import { activePersonSessionsForWorkspace } from './personSessionScope';

function session(
  id: string,
  sessionWorkspace: string,
  personId: string | undefined,
  exitCode: number | null = null,
): PtySessionInfo {
  return {
    id,
    agent: 'reviewer',
    ...(personId ? { personId } : {}),
    sessionWorkspace,
    cmd: 'runner',
    args: [],
    cwd: '/repos/alpha',
    cols: 80,
    rows: 24,
    exitCode,
    createdAt: '2026-10-11T00:00:00Z',
  };
}

describe('activePersonSessionsForWorkspace', () => {
  it('requires both a matching owner workspace and live process evidence', () => {
    const sessions = [
      session('current', '/workspaces/one', 'lina'),
      session('same-id-other-workspace', '/workspaces/two', 'lina'),
      session('exited', '/workspaces/one', 'lina', 0),
      session('ordinary-pty', '/workspaces/one', undefined),
    ];

    expect(activePersonSessionsForWorkspace(sessions, '/workspaces/one').map(({ id }) => id)).toEqual(['current']);
    expect(activePersonSessionsForWorkspace(sessions, '').map(({ id }) => id)).toEqual([]);
  });

  it('does not infer workspace ownership for legacy sessions without a workspace binding', () => {
    const legacy: PtySessionInfo = { ...session('legacy', '/workspaces/one', 'lina') };
    delete legacy.sessionWorkspace;

    expect(activePersonSessionsForWorkspace([legacy], '/workspaces/one')).toEqual([]);
  });
});
