import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router';
import { useBackend } from '../../backend';
import { queryKeys } from '../../lib/query';
import { Empty, Loading, LoadError, Panel, StatusDot } from '../../components/ui';
import styles from '../../components/ui.module.css';
import { errorMessage } from '../shared';

/**
 * Office — what is happening and what needs me?
 * Attention = backend health + selfcheck warn/err + running jobs.
 */
export default function Office() {
  const { client, backend, backendUrl } = useBackend();

  const health = useQuery({
    queryKey: queryKeys.health,
    queryFn: () => {
      if (!client) throw new Error('backend not connected');
      return client.health();
    },
    enabled: client !== null,
  });

  const selfcheck = useQuery({
    queryKey: queryKeys.selfcheck,
    queryFn: () => {
      if (!client) throw new Error('backend not connected');
      return client.selfcheck();
    },
    enabled: client !== null,
  });

  const jobs = useQuery({
    queryKey: queryKeys.jobs,
    queryFn: () => {
      if (!client) throw new Error('backend not connected');
      return client.jobsList();
    },
    enabled: client !== null,
    refetchInterval: 5_000,
  });

  const running = jobs.data
    ? Object.values(jobs.data).filter((job) => job.status === 'running' || job.status === 'queued')
    : [];
  const attention = selfcheck.data?.checks.filter((check) => check.status !== 'ok') ?? [];

  return (
    <>
      <h1>Office</h1>
      <Panel title="Backend">
        {health.isPending ? (
          <Loading label="Checking backend" />
        ) : health.isError ? (
          <LoadError message={errorMessage(health.error)} onRetry={() => void health.refetch()} />
        ) : (
          <p>
            <StatusDot status="ok" /> backend {health.data.version}
            {backend?.version && backend.version !== health.data.version
              ? ` (main reports ${backend.version})`
              : ''} · <span className={styles.mono}>{backendUrl}</span>
          </p>
        )}
      </Panel>
      <Panel title={`Needs attention (${attention.length + running.length})`}>
        {selfcheck.isPending || jobs.isPending ? (
          <Loading label="Gathering attention items" />
        ) : (
          <>
            {attention.length === 0 && running.length === 0 && (
              <Empty message="Nothing needs you. The workstation is quiet." />
            )}
            <ul>
              {attention.map((check) => (
                <li key={check.name}>
                  <StatusDot status={check.status === 'warn' ? 'warn' : 'err'} /> <strong>{check.name}</strong> —{' '}
                  {check.detail} <Link to="/insights">Inspect</Link>
                </li>
              ))}
              {running.map((job) => (
                <li key={job.id}>
                  <StatusDot status="warn" /> job <span className={styles.mono}>{job.id}</span> ({job.cmd}) is{' '}
                  {job.status} <Link to="/operations">Open in Operations</Link>
                </li>
              ))}
            </ul>
          </>
        )}
      </Panel>
    </>
  );
}
