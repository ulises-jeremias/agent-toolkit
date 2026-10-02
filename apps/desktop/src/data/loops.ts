import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { requireOk, type Job, type JobRegistry } from '../lib/api';
import { qk } from '../lib/query/keys';
import { requireClient, useBackend } from './backend';

export function useLoops() {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.loops.list(),
    queryFn: () => requireClient(client).loops(),
    enabled: client !== null,
    refetchInterval: 15_000,
  });
}

export function useLoopStatus(name: string | null) {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.loops.status(name ?? ''),
    queryFn: () => requireClient(client).loopStatusTyped(name ?? ''),
    enabled: client !== null && Boolean(name),
  });
}

export function useLoopHistory(name: string | null) {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.loops.history(name ?? ''),
    queryFn: () => requireClient(client).loopHistory(name ?? ''),
    enabled: client !== null && Boolean(name),
  });
}

export function useLoopAudit(name: string | null) {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.loops.audit(name ?? ''),
    queryFn: () => requireClient(client).loopAudit(name ?? ''),
    enabled: client !== null && Boolean(name),
  });
}

export function useLoopCost(name: string | null) {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.loops.cost(name ?? ''),
    queryFn: () => requireClient(client).loopCost(name ?? ''),
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

export function useInitializeLoop() {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  return useMutation({
    mutationKey: ['loops', 'initialize'],
    mutationFn: async (input: { name: string; custom_name?: string; workspace?: string }) =>
      requireOk(await requireClient(client).sub('loops', 'init', input)),
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: qk.loops.list() });
      void queryClient.invalidateQueries({ queryKey: qk.domain('loops') });
    },
  });
}
