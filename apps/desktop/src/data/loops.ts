import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import type { Job, JobRegistry } from '../lib/api';
import { qk } from '../lib/query/keys';
import { requireClient, useBackend } from './backend';

export function useLoopStatus(name: string | null) {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.loops.status(name ?? ''),
    queryFn: () => requireClient(client).loopStatus(name ?? ''),
    enabled: client !== null && Boolean(name),
  });
}

export function useRunLoop() {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  return useMutation<Job, Error, string>({
    mutationKey: ['loops', 'run'],
    mutationFn: (name) => requireClient(client).runLoop(name),
    onSuccess: (job) => {
      queryClient.setQueryData<JobRegistry>(qk.jobs.list(), (registry) => ({ ...registry, [job.id]: job }));
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: qk.jobs.list() });
      void queryClient.invalidateQueries({ queryKey: qk.domain('loops') });
    },
  });
}
