import type { QueryClient } from '@tanstack/react-query';
import type { ApiEvent, JobRegistry } from '../api';
import { qk } from '../query/keys';
import type { LiveEvent } from './jobStreams';

export const MAX_LIVE_LINES = 500;

function setJobStatus(queryClient: QueryClient, jobId: string, status: string): void {
  queryClient.setQueryData<JobRegistry>(qk.jobs.list(), (registry) => {
    const job = registry?.[jobId];
    if (!registry || !job || job.status === status) return registry;
    return { ...registry, [jobId]: { ...job, status } };
  });
}

function dropJob(queryClient: QueryClient, jobId: string): void {
  queryClient.setQueryData<JobRegistry>(qk.jobs.list(), (registry) => {
    if (!registry || !(jobId in registry)) return registry;
    const next = { ...registry };
    delete next[jobId];
    return next;
  });
  queryClient.removeQueries({ queryKey: qk.jobs.log(jobId) });
  queryClient.removeQueries({ queryKey: qk.jobs.live(jobId) });
}

/**
 * Families LiveProvider subscribes to on GET /api/v1/events.
 * Includes memory so the world archive refreshes without inventing entry payloads.
 */
export const BUS_TYPE_FILTER = 'backend.,job.,loop.,swarm.,memory.,install.';

/** Foreign boot / ready: refetch domains the world and operations share. Never invents rows. */
function refetchWorldDomains(queryClient: QueryClient): void {
  void queryClient.invalidateQueries({ queryKey: qk.domain('jobs') });
  void queryClient.invalidateQueries({ queryKey: qk.domain('memory') });
  void queryClient.invalidateQueries({ queryKey: qk.domain('loops') });
  void queryClient.invalidateQueries({ queryKey: qk.domain('swarms') });
  void queryClient.invalidateQueries({ queryKey: qk.domain('doctor') });
}

/** Write one live event into the Query cache. The only writer of `qk.jobs.live`. */
export function applyLiveEvent(queryClient: QueryClient, { jobId, event }: LiveEvent): void {
  switch (event.type) {
    case 'reset':
      queryClient.setQueryData<string[]>(qk.jobs.live(jobId), []);
      return;
    case 'status':
      setJobStatus(queryClient, jobId, event.status);
      return;
    case 'log':
      queryClient.setQueryData<string[]>(qk.jobs.live(jobId), (lines = []) =>
        lines.length >= MAX_LIVE_LINES
          ? [...lines.slice(lines.length - MAX_LIVE_LINES + 1), event.line]
          : [...lines, event.line],
      );
      return;
    case 'done':
      setJobStatus(queryClient, jobId, event.status);
      // exit_code and ended_at arrive only through the registry.
      void queryClient.invalidateQueries({ queryKey: qk.jobs.list() });
      void queryClient.invalidateQueries({ queryKey: qk.jobs.log(jobId) });
      return;
    case 'unknown':
      return;
  }
}

/**
 * Apply one GET /api/v1/events frame. Events are hints: they patch a known
 * job status or invalidate the owning domain. They never invent a job, log
 * line, or progress value that the read APIs have not returned.
 */
export function applyBusEvent(queryClient: QueryClient, event: ApiEvent): void {
  switch (event.type) {
    case 'backend.ready':
    case 'backend.resync':
      // Foreign boot and ready share one path: resync from read APIs, never guess.
      refetchWorldDomains(queryClient);
      return;
    case 'job.created':
      void queryClient.invalidateQueries({ queryKey: qk.jobs.list() });
      return;
    case 'job.updated':
      // Patch known status immediately so house lamps/characters update before poll.
      if (event.subject && event.status) setJobStatus(queryClient, event.subject, event.status);
      void queryClient.invalidateQueries({ queryKey: qk.jobs.list() });
      return;
    case 'job.deleted':
      if (event.subject) dropJob(queryClient, event.subject);
      void queryClient.invalidateQueries({ queryKey: qk.jobs.list() });
      return;
    case 'loop.started':
    case 'loop.finished':
      // Event has loop name + status + optional job ref — no project id. Do not
      // invent house activity; invalidate loops and the linked job list only.
      void queryClient.invalidateQueries({ queryKey: qk.domain('loops') });
      if (event.ref) void queryClient.invalidateQueries({ queryKey: qk.jobs.list() });
      return;
    case 'swarm.changed':
      // Payload is run_id + ok — no project id. Skip house mapping; refetch list.
      void queryClient.invalidateQueries({ queryKey: qk.domain('swarms') });
      return;
    case 'memory.changed':
      // subject is entry type only — never invent an archive row from the event.
      void queryClient.invalidateQueries({ queryKey: qk.domain('memory') });
      return;
    case 'install.started':
    case 'install.finished':
      void queryClient.invalidateQueries({ queryKey: qk.domain('doctor') });
      void queryClient.invalidateQueries({ queryKey: qk.domain('inventory') });
      return;
  }
}
