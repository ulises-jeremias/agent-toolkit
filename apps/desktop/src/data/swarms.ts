import { useMutation, useQueryClient } from '@tanstack/react-query';
import { requireOk, type CommandEnvelope, type SubBody, type SubCommand } from '../lib/api';
import { invalidateDomains } from '../lib/query/invalidation';
import { requireClient, useBackend } from './backend';

export function useSwarmCommand() {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  return useMutation<CommandEnvelope, Error, { sub: SubCommand<'swarms'>; body?: SubBody<'swarms'> }>({
    mutationKey: ['swarms', 'command'],
    mutationFn: async ({ sub, body }) => requireOk(await requireClient(client).sub('swarms', sub, body)),
    onSettled: () => invalidateDomains(queryClient, ['swarms']),
  });
}
