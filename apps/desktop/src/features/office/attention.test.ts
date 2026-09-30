import { afterEach, describe, expect, it } from 'vitest';
import type { Job, SelfcheckResponse } from '../../lib/api';
import type { BackendState } from '../../types/electron';
import {
  attentionVacancy,
  collectAttention,
  collectNeedsMe,
  completedNeedingReview,
  officeLede,
  resetNeedsMeCursor,
  takeNextNeedsMe,
  type AttentionInput,
} from './attention';

const href: AttentionInput['href'] = (path, extra = {}) => {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(extra)) {
    if (value) params.set(key, value);
  }
  const query = params.toString();
  return query ? `${path}?${query}` : path;
};

const job = (patch: Partial<Job> & Pick<Job, 'id' | 'status'>): Job => ({
  cmd: patch.cmd ?? 'doctor',
  args: patch.args ?? ['doctor'],
  started_at: '2026-09-30T10:00:00Z',
  ended_at: patch.ended_at ?? '',
  exit_code: patch.exit_code ?? 0,
  workspace: patch.workspace ?? '/ws',
  ...patch,
});

const backend = (status: BackendState['status'], detail: string | null = 'died'): BackendState => ({
  status,
  url: 'http://127.0.0.1:1',
  version: '1.35.0',
  detail,
  restarts: 0,
  harness: null,
  binary: null,
  rejected: [],
  problem: null,
});

const selfcheckOk: SelfcheckResponse = {
  ok: true,
  version: '1.35.0',
  commit: 'abc',
  checks: [{ name: 'serve', status: 'ok', detail: 'listening' }],
};

function input(patch: Partial<AttentionInput> = {}): AttentionInput {
  return {
    backend: backend('ready', 'ok'),
    connection: 'online',
    jobs: [],
    jobsStatus: 'success',
    selfcheck: selfcheckOk,
    selfcheckStatus: 'success',
    href,
    ...patch,
  };
}

describe('collectAttention', () => {
  it('never calls a crashed backend clear, even with no jobs yet', () => {
    const crashed = input({ backend: backend('crashed', 'signal=SIGKILL'), jobs: undefined, jobsStatus: 'pending' });
    const items = collectAttention(crashed);
    expect(items.map((item) => item.kind)).toContain('crash');
    expect(attentionVacancy(crashed, items).kind).not.toBe('gathering');
    expect(officeLede(crashed, items)).not.toMatch(/quiet/i);
    expect(officeLede(crashed, items)).toMatch(/crashed/);
  });

  it('lists a failed job as needs-you', () => {
    const failed = job({
      id: 'job_fail',
      status: 'failed',
      cmd: 'no-such-command',
      args: ['no-such-command'],
      exit_code: 1,
    });
    const items = collectAttention(input({ jobs: [failed] }));
    expect(items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          kind: 'failed-job',
          href: '/operations?job=job_fail',
          title: 'no-such-command failed',
        }),
      ]),
    );
  });

  it('surfaces a rejected backend binary as failed attention, not quiet', () => {
    const rejected = input({
      backend: {
        ...backend('failed', '/usr/bin/agent-toolkit (path, 1.16.0): too old: has no `serve` command'),
        problem: 'binary-rejected',
      },
    });
    const items = collectAttention(rejected);
    expect(items[0]?.kind).toBe('crash');
    expect(items[0]?.detail).toMatch(/too old/);
    expect(officeLede(rejected, items)).not.toMatch(/Nothing needs you|quiet/i);
  });

  it('surfaces version-mismatch before claiming the desk is clear', () => {
    const mismatch = input({ backend: backend('version-mismatch', 'backend 1.16.0 differs') });
    const items = collectAttention(mismatch);
    expect(items[0]?.kind).toBe('mismatch');
    expect(officeLede(mismatch, items)).not.toMatch(/Nothing needs you/);
  });

  it('refuses to say nothing needs you when the job list failed', () => {
    const broken = input({ jobs: undefined, jobsStatus: 'error' });
    const items = collectAttention(broken);
    expect(items).toEqual([]);
    expect(attentionVacancy(broken, items)).toEqual({
      kind: 'unknown',
      reason: 'The job list did not load, so failures may be hidden.',
    });
  });

  it('may say nothing needs you only after jobs and self-check succeeded', () => {
    const clear = input();
    const items = collectAttention(clear);
    expect(items).toEqual([]);
    expect(attentionVacancy(clear, items)).toEqual({ kind: 'clear' });
    expect(officeLede(clear, items)).toMatch(/Nothing needs you/);
    expect(officeLede(clear, items)).not.toMatch(/quiet/i);
  });
});

describe('collectNeedsMe / takeNextNeedsMe', () => {
  afterEach(() => resetNeedsMeCursor());

  it('cycles crash → failed job → running job', () => {
    const running = job({ id: 'job_run', status: 'running' });
    const failed = job({ id: 'job_fail', status: 'failed', exit_code: 1 });
    const targets = collectNeedsMe(
      input({
        backend: backend('crashed'),
        jobs: [failed, running, job({ id: 'job_ok', status: 'completed', ended_at: '2026-09-30T10:01:00Z' })],
      }),
    );
    expect(targets.map((target) => target.kind)).toEqual(['crash', 'failed-job', 'running-job']);
    expect(takeNextNeedsMe(targets)?.kind).toBe('crash');
    expect(takeNextNeedsMe(targets)?.kind).toBe('failed-job');
    expect(takeNextNeedsMe(targets)?.href).toBe('/operations?job=job_run');
    expect(takeNextNeedsMe(targets)?.kind).toBe('crash');
  });

  it('does not invent a completed-review queue', () => {
    const done = job({ id: 'job_ok', status: 'completed', ended_at: '2026-09-30T10:01:00Z' });
    expect(completedNeedingReview([done])).toEqual([]);
    expect(collectNeedsMe(input({ jobs: [done] }))).toEqual([]);
  });
});
