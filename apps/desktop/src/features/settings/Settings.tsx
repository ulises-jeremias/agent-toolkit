import { useQuery } from '@tanstack/react-query';
import { useBackend } from '../../backend';
import { queryKeys } from '../../lib/query';
import { ConfirmButton, MutationResult, useExecuteMutation, errorMessage } from '../shared';
import { LoadError, Loading, Panel, StatusDot } from '../../components/ui';
import styles from '../../components/ui.module.css';

/**
 * Settings — how is my workstation configured?
 * Backend identity, selfcheck, install/update/uninstall, and raw help text.
 */
export default function Settings() {
  const { client, backend, backendUrl, restartBackend } = useBackend();
  const selfcheck = useQuery({
    queryKey: queryKeys.selfcheck,
    queryFn: () => {
      if (!client) throw new Error('backend not connected');
      return client.selfcheck();
    },
    enabled: client !== null,
  });
  const update = useExecuteMutation('/api/v1/update');
  const uninstall = useExecuteMutation('/api/v1/uninstall');

  const help = useQuery({
    queryKey: ['backend', 'help'] as const,
    queryFn: async () => {
      if (!client) throw new Error('backend not connected');
      const response = await fetch(`${client.url}/api/v1/help`);
      if (!response.ok) throw new Error(`help failed with HTTP ${response.status}`);
      return response.text();
    },
    enabled: client !== null,
  });

  return (
    <>
      <h1>Settings</h1>
      <Panel
        title="Workstation backend"
        actions={
          <button type="button" className={styles.button} onClick={() => void restartBackend()}>
            Restart backend
          </button>
        }
      >
        <dl>
          <dt>Backend URL</dt>
          <dd>{backendUrl ?? 'not connected'}</dd>
          <dt>Status</dt>
          <dd>{backend?.status ?? 'unknown'}</dd>
          <dt>Version</dt>
          <dd>{backend?.version ?? 'unknown'}</dd>
          {backend?.detail && (
            <>
              <dt>Detail</dt>
              <dd>{backend.detail}</dd>
            </>
          )}
        </dl>
      </Panel>
      <Panel title="Selfcheck">
        {selfcheck.isPending ? (
          <Loading label="Running selfcheck" />
        ) : selfcheck.isError ? (
          <LoadError message={errorMessage(selfcheck.error)} onRetry={() => void selfcheck.refetch()} />
        ) : (
          <table className={styles.table}>
            <thead>
              <tr>
                <th scope="col">Status</th>
                <th scope="col">Check</th>
                <th scope="col">Detail</th>
              </tr>
            </thead>
            <tbody>
              {selfcheck.data.checks.map((check) => (
                <tr key={check.name}>
                  <td>
                    <StatusDot status={check.status === 'ok' ? 'ok' : check.status === 'warn' ? 'warn' : 'err'} />{' '}
                    {check.status}
                  </td>
                  <td className={styles.mono}>{check.name}</td>
                  <td>{check.detail}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
      <Panel
        title="Tool profiles"
        actions={
          <>
            <button type="button" className={styles.button} disabled={update.isPending} onClick={() => update.mutate()}>
              {update.isPending ? 'Updating…' : 'Update profiles'}
            </button>
            <ConfirmButton
              label="Uninstall profiles"
              confirmLabel="Confirm uninstall"
              disabled={uninstall.isPending}
              onConfirm={() => uninstall.mutate()}
            />
          </>
        }
      >
        <MutationResult result={update.data} error={update.error instanceof Error ? update.error : undefined} />
        <MutationResult
          result={uninstall.data}
          error={uninstall.error instanceof Error ? uninstall.error : undefined}
        />
        {!update.data && !uninstall.data && !update.error && !uninstall.error && (
          <p>Update refreshes installed profiles; uninstall removes them.</p>
        )}
      </Panel>
      <Panel title="Backend help">
        {help.isPending ? (
          <Loading label="Loading help" />
        ) : help.isError ? (
          <LoadError message={errorMessage(help.error)} onRetry={() => void help.refetch()} />
        ) : (
          <pre>{help.data}</pre>
        )}
      </Panel>
    </>
  );
}
