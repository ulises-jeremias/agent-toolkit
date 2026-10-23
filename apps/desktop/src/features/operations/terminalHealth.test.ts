import { describe, expect, it } from 'vitest';
import type { ProviderInfo } from '../../lib/api';
import type { PtySessionInfo } from '../../types/electron';
import { summarizeTerminalHealth } from './terminalHealth';

const session = (exitCode: number | null): PtySessionInfo => ({
  id: `s-${exitCode ?? 'run'}`,
  agent: 'Probe',
  cmd: '/usr/bin/opencode',
  args: [],
  cwd: '/work',
  cols: 80,
  rows: 24,
  exitCode,
  createdAt: '2026-10-23T00:00:00.000Z',
});

const runner = (id: string, available = true): ProviderInfo => ({
  id,
  bin: `/usr/bin/${id}`,
  available,
  capability: 'interactive',
  version: '1.0',
});

describe('summarizeTerminalHealth', () => {
  it('reports an unavailable PTY host as an error, never as health', () => {
    const health = summarizeTerminalHealth(false, [], [runner('opencode')]);
    expect(health.tone).toBe('err');
    expect(health.headline).toContain('unavailable');
  });

  it('warns when the terminal works but no runner is detected', () => {
    const health = summarizeTerminalHealth(true, [], [runner('opencode', false), runner('skeleton')]);
    expect(health.tone).toBe('warn');
    expect(health.detail).toContain('No runner detected');
    expect(health.detail).toContain('No terminal sessions open');
  });

  it('counts running and exited sessions from real exit codes', () => {
    const health = summarizeTerminalHealth(true, [session(null), session(null), session(0)], [runner('opencode')]);
    expect(health.tone).toBe('ok');
    expect(health.detail).toContain('2 running · 1 exited of 3 open');
    expect(health.detail).toContain('Runners detected: opencode');
  });
});
