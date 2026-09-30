import { QueryClient } from '@tanstack/react-query';
import { describe, expect, it } from 'vitest';
import type { ApiEvent, Job, JobRegistry, MemoryEntry, MemoryListResponse } from '../../../lib/api';
import { applyBusEvent, BUS_TYPE_FILTER } from '../../../lib/live/applyEvent';
import { qk } from '../../../lib/query/keys';
import { buildWorldModel } from './buildWorld';
import type { MemoryEntryRecord, WorldDomainInput } from './types';

function bus(partial: Partial<ApiEvent> & Pick<ApiEvent, 'type'>): ApiEvent {
  return {
    seq: 1,
    boot: 'boot-a',
    at: '2026-09-30T12:00:00Z',
    subject: '',
    status: '',
    exit_code: 0,
    ref: '',
    message: '',
    ...partial,
  };
}

function job(partial: Partial<Job> & Pick<Job, 'id' | 'status' | 'workspace'>): Job {
  return {
    cmd: 'doctor',
    args: ['doctor'],
    started_at: '2026-09-30T12:00:00Z',
    ended_at: '',
    exit_code: 0,
    retry_of: '',
    ...partial,
  };
}

function toRecords(entries: MemoryEntry[]): MemoryEntryRecord[] {
  return entries.map((entry) => ({
    id: entry.id,
    kind: entry.kind,
    title: entry.title,
    snippet: entry.snippet,
    tags: entry.tags,
    provenance: entry.provenance,
  }));
}

function worldFromJobs(jobs: Job[], memoryEntries: MemoryEntryRecord[] = []): WorldDomainInput {
  return {
    workspacePath: '/ws',
    projects: [{ name: 'alpha', target: '/r/alpha', status: 'ok' }],
    projectsKnown: true,
    memory: {
      available: true,
      entries: memoryEntries,
      projectKeys: [...new Set(memoryEntries.map((e) => e.provenance.project).filter(Boolean))],
    },
    tools: [],
    toolsKnown: false,
    jobs,
  };
}

describe('world follows GET /api/v1/events', () => {
  it('subscribes to memory family alongside jobs and backend', () => {
    expect(BUS_TYPE_FILTER).toContain('memory.');
    expect(BUS_TYPE_FILTER).toContain('job.');
    expect(BUS_TYPE_FILTER).toContain('backend.');
  });

  it('job.updated patches status so house activity flips before the next poll', () => {
    const running = job({ id: 'job_run', status: 'running', workspace: '/r/alpha' });
    const queryClient = new QueryClient();
    queryClient.setQueryData<JobRegistry>(qk.jobs.list(), { [running.id]: running });

    const before = buildWorldModel(
      worldFromJobs(Object.values(queryClient.getQueryData<JobRegistry>(qk.jobs.list()) ?? {})),
    );
    expect(before.entities.find((e) => e.id === 'place:project:alpha')?.activity).toBe('working');
    expect(before.entities.some((e) => e.id === `character:job:${running.id}`)).toBe(true);

    applyBusEvent(queryClient, bus({ type: 'job.updated', subject: running.id, status: 'completed', boot: 'boot-a' }));

    const afterJobs = Object.values(queryClient.getQueryData<JobRegistry>(qk.jobs.list()) ?? {});
    expect(afterJobs.find((j) => j.id === running.id)?.status).toBe('completed');

    const after = buildWorldModel(worldFromJobs(afterJobs));
    expect(after.entities.find((e) => e.id === 'place:project:alpha')?.activity).toBe('calm');
    expect(after.entities.some((e) => e.id === `character:job:${running.id}`)).toBe(false);
  });

  it('job.deleted removes the character and calms the house', () => {
    const running = job({ id: 'job_gone', status: 'running', workspace: '/r/alpha' });
    const queryClient = new QueryClient();
    queryClient.setQueryData<JobRegistry>(qk.jobs.list(), { [running.id]: running });

    applyBusEvent(queryClient, bus({ type: 'job.deleted', subject: running.id }));

    const after = buildWorldModel(
      worldFromJobs(Object.values(queryClient.getQueryData<JobRegistry>(qk.jobs.list()) ?? {})),
    );
    expect(after.entities.find((e) => e.id === 'place:project:alpha')?.activity).toBe('calm');
    expect(after.entities.some((e) => e.id === `character:job:${running.id}`)).toBe(false);
  });

  it('memory.changed invalidates memory so archive count refreshes without inventing rows', () => {
    const queryClient = new QueryClient();
    const listed: MemoryListResponse = {
      ok: true,
      message: '',
      entries: [
        {
          id: 'knowledge/learnings/a.md',
          kind: 'learning',
          title: 'Note',
          snippet: '',
          tags: [],
          provenance: {
            file: 'knowledge/learnings/a.md',
            author: '',
            timestamp: '',
            project: '',
            agent: '',
          },
        },
      ],
    };
    queryClient.setQueryData(qk.memory.list(), listed);

    applyBusEvent(queryClient, bus({ type: 'memory.changed', subject: 'learning', status: 'ok', message: 'add' }));

    // Event subject is entry type only — cache rows stay until refetch; world must not invent.
    expect(queryClient.getQueryData<MemoryListResponse>(qk.memory.list())?.entries).toHaveLength(1);
    expect(queryClient.getQueryState(qk.memory.list())?.isInvalidated).toBe(true);

    // Simulate the refetch the bus invalidation triggers.
    const refreshed: MemoryListResponse = {
      ...listed,
      entries: [
        ...listed.entries,
        {
          id: 'knowledge/learnings/b.md',
          kind: 'learning',
          title: 'Newer',
          snippet: '',
          tags: [],
          provenance: {
            file: 'knowledge/learnings/b.md',
            author: '',
            timestamp: '',
            project: '',
            agent: '',
          },
        },
      ],
    };
    queryClient.setQueryData(qk.memory.list(), refreshed);

    const after = buildWorldModel(worldFromJobs([], toRecords(refreshed.entries)));
    const archive = after.entities.find((e) => e.id === 'place:memory');
    expect(archive?.state).toBe('2 records');
  });

  it('backend.resync invalidates jobs and memory — foreign boot means resync, not a guessed picture', () => {
    const queryClient = new QueryClient();
    queryClient.setQueryData<JobRegistry>(qk.jobs.list(), {
      job_1: job({ id: 'job_1', status: 'running', workspace: '/r/alpha' }),
    });
    queryClient.setQueryData(qk.memory.list(), { ok: true, message: '', entries: [] });

    applyBusEvent(
      queryClient,
      bus({ type: 'backend.resync', subject: 'serve', status: 'ok', message: 'refetch', boot: 'boot-b' }),
    );

    expect(queryClient.getQueryState(qk.jobs.list())?.isInvalidated).toBe(true);
    expect(queryClient.getQueryState(qk.memory.list())?.isInvalidated).toBe(true);
  });

  it('backend.ready shares the same resync path as foreign boot', () => {
    const queryClient = new QueryClient();
    queryClient.setQueryData(qk.memory.list(), { ok: true, message: '', entries: [] });
    applyBusEvent(queryClient, bus({ type: 'backend.ready', subject: 'serve', status: 'ok' }));
    expect(queryClient.getQueryState(qk.memory.list())?.isInvalidated).toBe(true);
  });

  it('swarm.changed does not invent house activity — payload has no project id', () => {
    const queryClient = new QueryClient();
    queryClient.setQueryData(qk.swarms.list(), []);
    applyBusEvent(queryClient, bus({ type: 'swarm.changed', subject: 'run_abc', status: 'ok', message: 'status' }));
    expect(queryClient.getQueryState(qk.swarms.list())?.isInvalidated).toBe(true);
    // No project on the event → world house activity stays job-driven only.
    const model = buildWorldModel(worldFromJobs([]));
    expect(model.entities.find((e) => e.id === 'place:project:alpha')?.activity).toBe('calm');
  });
});
