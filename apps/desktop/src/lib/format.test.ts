import { describe, expect, it } from 'vitest';
import type { Job } from './api';
import { formatDuration, jobCommandLine, jobDuration } from './format';

const base: Job = {
  id: 'job_1',
  cmd: 'doctor',
  args: ['doctor', '--json'],
  status: 'completed',
  started_at: '2026-09-29T10:00:00Z',
  ended_at: '2026-09-29T10:00:05Z',
  exit_code: 0,
  workspace: '',
  retry_of: '',
};

describe('jobCommandLine', () => {
  it('drops the subcommand the registry repeats as args[0]', () => {
    expect(jobCommandLine(base)).toBe('agent-toolkit doctor --json');
  });

  it('keeps args that do not repeat the subcommand', () => {
    expect(jobCommandLine({ ...base, args: ['--json'] })).toBe('agent-toolkit doctor --json');
  });
});

describe('durations', () => {
  it('measures finished jobs from start to end', () => {
    expect(jobDuration(base)).toBe(5_000);
  });

  it('measures running jobs up to now and refuses unknown starts', () => {
    expect(jobDuration({ ...base, ended_at: '' }, Date.parse('2026-09-29T10:01:00Z'))).toBe(60_000);
    expect(jobDuration({ ...base, started_at: '' })).toBeNull();
  });

  it('formats at a readable granularity', () => {
    expect(formatDuration(450)).toBe('450 ms');
    expect(formatDuration(5_000)).toBe('5 s');
    expect(formatDuration(125_000)).toBe('2 min 5 s');
    expect(formatDuration(3_720_000)).toBe('1 h 2 min');
  });
});
