import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import {
  requireOk,
  type CommandEnvelope,
  type OperationKind,
  type ReportKind,
  type SubBody,
  type SubCommand,
  type SubFamily,
} from '../lib/api';
import { invalidateDomains, OPERATION_EFFECTS } from '../lib/query/invalidation';
import { qk, type Domain } from '../lib/query/keys';
import { requireClient, useBackend } from './backend';

/**
 * GET report (inventory, doctor, matrix, diff, insights, loops, swarms).
 * Reports keep `ok: false` as data: a doctor run that finds problems is an
 * answer, not a transport failure.
 */
export function useReport(kind: ReportKind, options: { enabled?: boolean } = {}) {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.report(kind),
    queryFn: () => requireClient(client).report(kind),
    enabled: client !== null && (options.enabled ?? true),
  });
}

/**
 * Read through an allowlisted subcommand (e.g. `workspace/context`,
 * `project/list`). By default `ok: false` surfaces as an error; checks whose
 * failure is the answer (validate) pass `failureIsData`.
 */
export function useSubQuery<F extends SubFamily>(
  family: F,
  sub: SubCommand<F>,
  body?: SubBody<F>,
  options: { enabled?: boolean; staleTime?: number; failureIsData?: boolean } = {},
) {
  const { client } = useBackend();
  const failureIsData = options.failureIsData ?? false;
  return useQuery({
    queryKey: qk.sub(family, sub, body),
    queryFn: async () => {
      const envelope = await requireClient(client).sub(family, sub, body);
      return failureIsData ? envelope : requireOk(envelope);
    },
    enabled: client !== null && (options.enabled ?? true),
    staleTime: options.staleTime,
  });
}

/**
 * Run a subcommand that changes state. `invalidates` names every domain the
 * command can change; the family's own domain is always included.
 */
export function useSubMutation<F extends SubFamily>(
  family: F,
  sub: SubCommand<F>,
  options: { invalidates?: readonly Domain[] } = {},
) {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  return useMutation<CommandEnvelope, Error, SubBody<F> | undefined>({
    mutationKey: [family, 'mutate', sub],
    mutationFn: async (body) => requireOk(await requireClient(client).sub(family, sub, body)),
    onSettled: () => invalidateDomains(queryClient, [family, ...(options.invalidates ?? [])]),
  });
}

/** Whole-toolkit operation (install, update, uninstall, build, doctor --fix). */
export function useOperation(kind: OperationKind) {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  return useMutation<CommandEnvelope, Error, void>({
    mutationKey: ['operation', kind],
    mutationFn: async () => requireOk(await requireClient(client).operation(kind)),
    onSettled: () => invalidateDomains(queryClient, OPERATION_EFFECTS[kind]),
  });
}
