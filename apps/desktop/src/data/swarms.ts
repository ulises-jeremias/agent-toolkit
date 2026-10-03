import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  requireOk,
  type CommandEnvelope,
  type SubBody,
  type SubCommand,
  type SwarmActionResponse,
  type SwarmListResponse,
  type SwarmRunResponse,
  type SwarmRecipesResponse,
} from '../lib/api';
import { qk } from '../lib/query/keys';
import { requireClient, useBackend } from './backend';

const SWARM_FAST_REFRESH_STATES = new Set(['planning', 'running', 'awaiting_human', 'awaiting_plan_approval']);
const SWARM_RECOVERABLE_REFRESH_STATES = new Set(['paused', 'budget_exhausted', 'failed']);

export function swarmRefreshInterval(states: string[]): number | false {
  if (states.some((state) => SWARM_FAST_REFRESH_STATES.has(state))) return 2_000;
  if (states.some((state) => SWARM_RECOVERABLE_REFRESH_STATES.has(state))) return 10_000;
  return false;
}

export function useSwarms() {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.swarms.list(),
    queryFn: () => requireClient(client).swarms(),
    enabled: client !== null,
    refetchInterval: (query) => swarmRefreshInterval(query.state.data?.runs.map((run) => run.run_state) ?? []),
    refetchIntervalInBackground: false,
  });
}

export function useSwarmRecipes() {
  const { client } = useBackend();
  return useQuery<SwarmRecipesResponse>({
    queryKey: qk.swarms.recipes(),
    queryFn: () => requireClient(client).swarmRecipes(),
    enabled: client !== null,
  });
}

export function useSwarmRun(id: string | null) {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.swarms.run(id ?? ''),
    queryFn: () => requireClient(client).swarmRun(id ?? ''),
    enabled: client !== null && Boolean(id),
    refetchInterval: (query) => {
      const state = query.state.data?.run.run_state;
      if (!state) return false;
      return swarmRefreshInterval([state]);
    },
    refetchIntervalInBackground: false,
  });
}

export function useSwarmCommand() {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  return useMutation<CommandEnvelope, Error, { sub: SubCommand<'swarms'>; body?: SubBody<'swarms'> }>({
    mutationKey: ['swarms', 'command'],
    mutationFn: async ({ sub, body }) => requireOk(await requireClient(client).sub('swarms', sub, body)),
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: qk.domain('swarms') });
    },
  });
}

type SwarmAction = 'approve' | 'reject' | 'stop';

export function useSwarmRunAction() {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  return useMutation<SwarmActionResponse, Error, { id: string; action: SwarmAction }>({
    mutationKey: ['swarms', 'run-action'],
    mutationFn: ({ id, action }) => {
      const api = requireClient(client);
      if (action === 'approve') return api.approveSwarm(id);
      if (action === 'reject') return api.rejectSwarm(id);
      return api.stopSwarm(id);
    },
    onSettled: (_data, _error, variables) => {
      void queryClient.invalidateQueries({ queryKey: qk.swarms.list() });
      if (variables) void queryClient.invalidateQueries({ queryKey: qk.swarms.run(variables.id) });
    },
  });
}

export type { SwarmListResponse, SwarmRunResponse };
