import { useMutation, useQuery, useQueryClient, type UseQueryResult } from '@tanstack/react-query';
import type { ReactNode } from 'react';
import { useBackend } from '../backend';
import { ApiError, type CommandEnvelope } from '../lib/api';
import { queryKeys } from '../lib/query';
import { ConfirmButton, Empty, LoadError, Loading, Panel } from '../components/ui';
import styles from '../components/ui.module.css';

export { ConfirmButton };

export function errorMessage(error: unknown): string {
  if (error instanceof ApiError) return error.message;
  if (error instanceof Error) return error.message;
  return String(error);
}

/** GET read-API envelope (inventory, doctor, matrix, diff, insights, loops, swarms, help excluded). */
export function useReadApi(
  path: Parameters<import('../lib/api').ApiClient['readApi']>[0],
): UseQueryResult<CommandEnvelope, Error> {
  const { client } = useBackend();
  return useQuery({
    queryKey: queryKeys.readApi(path),
    queryFn: () => {
      if (!client) throw new Error('backend not connected');
      return client.readApi(path);
    },
    enabled: client !== null,
  });
}

export type SubResource = 'skills' | 'mcp' | 'plugin' | 'workspace' | 'memory' | 'project' | 'loops' | 'dc' | 'swarms';

export function useSubApiQuery(resource: SubResource, sub: string): UseQueryResult<CommandEnvelope, Error> {
  const { client } = useBackend();
  return useQuery({
    queryKey: queryKeys.subApi(resource, sub),
    queryFn: () => {
      if (!client) throw new Error('backend not connected');
      return client.subApi(resource, sub);
    },
    enabled: client !== null,
  });
}

export function useSubApiMutation(resource: SubResource, sub: string) {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (body?: unknown): Promise<CommandEnvelope> => {
      if (!client) throw new Error('backend not connected');
      return client.subApi(resource, sub, body ?? {});
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: queryKeys.subApi(resource, sub) });
      void queryClient.invalidateQueries({ queryKey: queryKeys.jobs });
    },
  });
}

export function useExecuteMutation(
  path: '/api/v1/install' | '/api/v1/update' | '/api/v1/uninstall' | '/api/v1/build' | '/api/v1/doctor/fix',
) {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (): Promise<CommandEnvelope> => {
      if (!client) throw new Error('backend not connected');
      return client.execute(path);
    },
    onSettled: () => {
      void queryClient.invalidateQueries();
    },
  });
}

/** Renders a backend envelope honestly: message + data table + mutation state. */
export function EnvelopePanel({
  title,
  query,
  actions,
}: {
  title: string;
  query: UseQueryResult<CommandEnvelope, Error>;
  actions?: ReactNode;
}) {
  if (query.isPending) {
    return (
      <Panel title={title} actions={actions}>
        <Loading label={`Loading ${title}`} />
      </Panel>
    );
  }
  if (query.isError) {
    return (
      <Panel title={title} actions={actions}>
        <LoadError message={errorMessage(query.error)} onRetry={() => void query.refetch()} />
      </Panel>
    );
  }
  const envelope = query.data;
  const entries = Object.entries(envelope.data);
  return (
    <Panel title={title} actions={actions}>
      <p>{envelope.message || (envelope.ok ? 'OK' : 'Failed')}</p>
      {entries.length === 0 ? (
        <Empty message="No detail fields returned." />
      ) : (
        <table className={styles.table}>
          <thead>
            <tr>
              <th scope="col">Field</th>
              <th scope="col">Value</th>
            </tr>
          </thead>
          <tbody>
            {entries.map(([key, value]) => (
              <tr key={key}>
                <th scope="row" className={styles.mono}>
                  {key}
                </th>
                <td className={styles.mono}>{value}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Panel>
  );
}

export function MutationResult({ result, error }: { result?: CommandEnvelope; error?: Error | null }) {
  if (error) return <LoadError message={errorMessage(error)} />;
  if (!result) return null;
  return <p role="status">{result.message || (result.ok ? 'Done.' : 'Failed.')}</p>;
}
