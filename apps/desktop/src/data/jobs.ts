import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { isTerminalJobStatus, type Job, type JobCreateRequest, type JobRegistry } from '../lib/api';
import { qk } from '../lib/query/keys';
import { requireClient, useBackend } from './backend';

/** Jobs created outside this window (CLI, another app) appear within this interval. */
export const JOBS_POLL_MS = 5_000;

/** Newest first. Job ids share a date prefix, so order by start time, then id. */
export function sortJobs(registry: JobRegistry | undefined): Job[] {
  return Object.values(registry ?? {}).sort(
    (a, b) => b.started_at.localeCompare(a.started_at) || b.id.localeCompare(a.id),
  );
}

export function activeJobIds(registry: JobRegistry | undefined): string[] {
  return Object.values(registry ?? {})
    .filter((job) => !isTerminalJobStatus(job.status))
    .map((job) => job.id);
}

export function useJobs() {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.jobs.list(),
    queryFn: () => requireClient(client).jobs(),
    enabled: client !== null,
    refetchInterval: JOBS_POLL_MS,
  });
}

export function useJob(id: string | null): Job | undefined {
  const jobs = useJobs();
  return id ? jobs.data?.[id] : undefined;
}

/** Persisted log. Refetched by the live bridge when the job reaches `done`. */
export function useJobLog(id: string | null) {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.jobs.log(id ?? ''),
    queryFn: () => requireClient(client).jobLog(id ?? ''),
    enabled: client !== null && id !== null,
  });
}

/** Lines streamed since the current SSE connection opened. Written only by the live bridge. */
export function useJobLiveLines(id: string | null): readonly string[] {
  const query = useQuery<string[]>({
    queryKey: qk.jobs.live(id ?? ''),
    queryFn: () => [],
    enabled: false,
    initialData: [],
    staleTime: Infinity,
  });
  return id ? query.data : [];
}

export function useCreateJob() {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  return useMutation<Job, Error, JobCreateRequest>({
    mutationKey: ['jobs', 'create'],
    mutationFn: (request) => requireClient(client).createJob(request),
    onSuccess: (job) => {
      // Insert immediately so the live bridge opens its stream without waiting for the poll.
      queryClient.setQueryData<JobRegistry>(qk.jobs.list(), (registry) => ({ ...registry, [job.id]: job }));
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: qk.jobs.list() }),
  });
}

export function useCancelJob() {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  return useMutation<Job, Error, string>({
    mutationKey: ['jobs', 'cancel'],
    mutationFn: (id) => requireClient(client).cancelJob(id),
    onSuccess: (job) => {
      queryClient.setQueryData<JobRegistry>(qk.jobs.list(), (registry) =>
        registry ? { ...registry, [job.id]: job } : registry,
      );
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: qk.jobs.list() }),
  });
}

export function useDeleteJob() {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  return useMutation<unknown, Error, { id: string; force?: boolean }>({
    mutationKey: ['jobs', 'delete'],
    mutationFn: ({ id, force }) => requireClient(client).deleteJob(id, force),
    onSuccess: (_result, { id }) => {
      queryClient.setQueryData<JobRegistry>(qk.jobs.list(), (registry) => {
        if (!registry) return registry;
        const { [id]: _removed, ...rest } = registry;
        return rest;
      });
      queryClient.removeQueries({ queryKey: qk.jobs.log(id) });
      queryClient.removeQueries({ queryKey: qk.jobs.live(id) });
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey: qk.jobs.list() }),
  });
}
