import { QueryClient } from '@tanstack/react-query';
import { describe, expect, it } from 'vitest';
import type { Job, JobRegistry } from '../api';
import { qk } from '../query/keys';
import { applyBusEvent, applyLiveEvent, MAX_LIVE_LINES } from './applyEvent';

const job: Job = {
  id: 'job_1',
  cmd: 'doctor',
  args: ['doctor'],
  status: 'running',
  started_at: '2026-09-29T10:00:00Z',
  ended_at: '',
  exit_code: 0,
  workspace: '/ws',
  retry_of: '',
};

function client(): QueryClient {
  const queryClient = new QueryClient();
  queryClient.setQueryData<JobRegistry>(qk.jobs.list(), { [job.id]: job });
  return queryClient;
}

describe('applyLiveEvent', () => {
  it('writes status into the jobs registry without refetching', () => {
    const queryClient = client();
    applyLiveEvent(queryClient, { jobId: job.id, event: { type: 'status', status: 'queued' } });
    expect(queryClient.getQueryData<JobRegistry>(qk.jobs.list())?.[job.id]?.status).toBe('queued');
  });

  it('appends log lines and bounds the buffer', () => {
    const queryClient = client();
    for (let index = 0; index < MAX_LIVE_LINES + 5; index += 1) {
      applyLiveEvent(queryClient, { jobId: job.id, event: { type: 'log', line: `line ${index}` } });
    }
    const lines = queryClient.getQueryData<string[]>(qk.jobs.live(job.id)) ?? [];
    expect(lines).toHaveLength(MAX_LIVE_LINES);
    expect(lines.at(-1)).toBe(`line ${MAX_LIVE_LINES + 4}`);
    expect(lines[0]).toBe('line 5');
  });

  it('clears the buffer on reset because the server replays the log', () => {
    const queryClient = client();
    applyLiveEvent(queryClient, { jobId: job.id, event: { type: 'log', line: 'old' } });
    applyLiveEvent(queryClient, { jobId: job.id, event: { type: 'reset' } });
    expect(queryClient.getQueryData<string[]>(qk.jobs.live(job.id))).toEqual([]);
  });

  it('marks the job terminal and invalidates list and log on done', () => {
    const queryClient = client();
    queryClient.setQueryData(qk.jobs.log(job.id), 'partial');
    applyLiveEvent(queryClient, { jobId: job.id, event: { type: 'done', status: 'failed' } });
    expect(queryClient.getQueryData<JobRegistry>(qk.jobs.list())?.[job.id]?.status).toBe('failed');
    expect(queryClient.getQueryState(qk.jobs.list())?.isInvalidated).toBe(true);
    expect(queryClient.getQueryState(qk.jobs.log(job.id))?.isInvalidated).toBe(true);
  });
});

describe('applyBusEvent', () => {
  it('invalidates jobs on job.created without inventing a record', () => {
    const queryClient = client();
    applyBusEvent(queryClient, {
      seq: 1,
      boot: 'b',
      type: 'job.created',
      at: '',
      subject: 'job_new',
      status: 'queued',
      exit_code: 0,
      ref: '',
      message: '',
    });
    expect(queryClient.getQueryData<JobRegistry>(qk.jobs.list())?.['job_new']).toBeUndefined();
    expect(queryClient.getQueryState(qk.jobs.list())?.isInvalidated).toBe(true);
  });

  it('drops a deleted job from the registry', () => {
    const queryClient = client();
    applyBusEvent(queryClient, {
      seq: 2,
      boot: 'b',
      type: 'job.deleted',
      at: '',
      subject: job.id,
      status: '',
      exit_code: 0,
      ref: '',
      message: '',
    });
    expect(queryClient.getQueryData<JobRegistry>(qk.jobs.list())?.[job.id]).toBeUndefined();
  });

  it('refetches operations domains on backend.resync', () => {
    const queryClient = client();
    queryClient.setQueryData(qk.report('loops'), { ok: true, message: '', data: {} });
    applyBusEvent(queryClient, {
      seq: 3,
      boot: 'b',
      type: 'backend.resync',
      at: '',
      subject: 'serve',
      status: 'ok',
      exit_code: 0,
      ref: '',
      message: 'refetch',
    });
    expect(queryClient.getQueryState(qk.jobs.list())?.isInvalidated).toBe(true);
    expect(queryClient.getQueryState(qk.report('loops'))?.isInvalidated).toBe(true);
  });
});
