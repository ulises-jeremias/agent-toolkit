import type { QueryClient } from '@tanstack/react-query';
import type { JobRegistry } from '../api';
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
        lines.length >= MAX_LIVE_LINES ? [...lines.slice(lines.length - MAX_LIVE_LINES + 1), event.line] : [...lines, event.line],
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
