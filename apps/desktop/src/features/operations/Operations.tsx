import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useState } from 'react';
import { useBackend } from '../../backend';
import type { Job } from '../../lib/api';
import { queryKeys } from '../../lib/query';
import { Empty, LoadError, Loading, Panel, StatusDot } from '../../components/ui';
import styles from '../../components/ui.module.css';
import { MutationResult, errorMessage } from '../shared';

/**
 * Operations — what work is running and how can I control it?
 * Jobs are created against the real backend; live output arrives over SSE and
 * reconciles with the TanStack Query jobs cache. The server exposes no
 * cancel/delete endpoint, so none is offered.
 */
export default function Operations() {
  const { client } = useBackend();
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const jobsQuery = useQuery({
    queryKey: queryKeys.jobs,
    queryFn: () => {
      if (!client) throw new Error('backend not connected');
      return client.jobsList();
    },
    enabled: client !== null,
    refetchInterval: 2_000,
  });

  const jobs = jobsQuery.data
    ? Object.values(jobsQuery.data).sort((a, b) => b.started_at.localeCompare(a.started_at))
    : [];
  const selected = selectedId ? (jobs.find((job) => job.id === selectedId) ?? null) : null;

  return (
    <>
      <h1>Operations</h1>
      <StartJobForm onStarted={setSelectedId} />
      <Panel title={`Jobs (${jobs.length})`}>
        {jobsQuery.isPending ? (
          <Loading label="Loading jobs" />
        ) : jobsQuery.isError ? (
          <LoadError message={errorMessage(jobsQuery.error)} onRetry={() => void jobsQuery.refetch()} />
        ) : jobs.length === 0 ? (
          <Empty message="No jobs yet. Start one above." />
        ) : (
          <table className={styles.table}>
            <thead>
              <tr>
                <th scope="col">Status</th>
                <th scope="col">ID</th>
                <th scope="col">Command</th>
                <th scope="col">Started</th>
                <th scope="col">Exit</th>
              </tr>
            </thead>
            <tbody>
              {jobs.map((job) => (
                <tr key={job.id}>
                  <td>
                    <StatusDot status={job.status === 'completed' ? 'ok' : job.status === 'failed' ? 'err' : 'warn'} />{' '}
                    {job.status}
                  </td>
                  <td>
                    <button type="button" className={styles.button} onClick={() => setSelectedId(job.id)}>
                      <span className={styles.mono}>{job.id.slice(0, 8)}</span>
                    </button>
                  </td>
                  <td className={styles.mono}>{[job.cmd, ...job.args.slice(1)].join(' ')}</td>
                  <td className={styles.mono}>{job.started_at}</td>
                  <td className={styles.mono}>
                    {job.status === 'completed' || job.status === 'failed' ? job.exit_code : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Panel>
      {selected && <JobDetail job={selected} onClose={() => setSelectedId(null)} />}
    </>
  );
}

function StartJobForm({ onStarted }: { onStarted: (id: string) => void }) {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  const [cmd, setCmd] = useState('doctor');
  const [args, setArgs] = useState('');
  const [workspace, setWorkspace] = useState('');

  const create = useMutation({
    mutationFn: async () => {
      if (!client) throw new Error('backend not connected');
      return client.jobsCreate({
        cmd: cmd.trim(),
        args: args.split(/\s+/).filter(Boolean),
        workspace: workspace.trim() || undefined,
      });
    },
    onSuccess: (job) => {
      onStarted(job.id);
      void queryClient.invalidateQueries({ queryKey: queryKeys.jobs });
    },
  });

  return (
    <Panel title="Start work">
      <form
        onSubmit={(event) => {
          event.preventDefault();
          if (cmd.trim()) create.mutate();
        }}
      >
        <label className={styles.field}>
          <span>Command (agent-toolkit subcommand, e.g. doctor, loop, swarm)</span>
          <input
            className={styles.input}
            value={cmd}
            onChange={(event) => setCmd(event.target.value)}
            required
            aria-label="Command"
          />
        </label>
        <label className={styles.field}>
          <span>Arguments (space-separated, optional)</span>
          <input
            className={styles.input}
            value={args}
            onChange={(event) => setArgs(event.target.value)}
            aria-label="Arguments"
          />
        </label>
        <label className={styles.field}>
          <span>Workspace directory (optional; defaults to detected workspace)</span>
          <input
            className={styles.input}
            value={workspace}
            onChange={(event) => setWorkspace(event.target.value)}
            aria-label="Workspace"
          />
        </label>
        <button type="submit" className={styles.button} disabled={create.isPending || cmd.trim().length === 0}>
          {create.isPending ? 'Starting…' : 'Start job'}
        </button>
      </form>
      <MutationResult error={create.error instanceof Error ? create.error : undefined} />
    </Panel>
  );
}

function JobDetail({ job, onClose }: { job: Job; onClose: () => void }) {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  const [liveLines, setLiveLines] = useState<string[]>([]);
  const [liveStatus, setLiveStatus] = useState<string | null>(null);

  const logQuery = useQuery({
    queryKey: queryKeys.jobLog(job.id),
    queryFn: () => {
      if (!client) throw new Error('backend not connected');
      return client.jobsLog(job.id);
    },
    enabled: client !== null,
    refetchInterval: job.status === 'running' || job.status === 'queued' ? 2_000 : false,
  });

  // Subscribe once per active job: depending on `job.status` directly would
  // tear down and reopen the EventSource on every queued->running
  // transition, duplicating replayed log lines into liveLines.
  const isActive = job.status === 'running' || job.status === 'queued';
  useEffect(() => {
    if (!client) return;
    if (!isActive) return;
    const controller = new AbortController();
    void client.subscribeJobEvents(
      job.id,
      (event) => {
        if (event.type === 'log') setLiveLines((lines) => [...lines.slice(-500), event.line]);
        if (event.type === 'status') {
          setLiveStatus(event.status);
          void queryClient.invalidateQueries({ queryKey: queryKeys.jobs });
        }
        if (event.type === 'done') {
          void queryClient.invalidateQueries({ queryKey: queryKeys.jobs });
          void queryClient.invalidateQueries({ queryKey: queryKeys.jobLog(job.id) });
        }
      },
      controller.signal,
    );
    return () => controller.abort();
  }, [client, job.id, isActive, queryClient]);

  return (
    <Panel
      title={`Job ${job.id}`}
      actions={
        <button type="button" className={styles.button} onClick={onClose}>
          Close
        </button>
      }
    >
      <p>
        <StatusDot status={job.status === 'completed' ? 'ok' : job.status === 'failed' ? 'err' : 'warn'} />{' '}
        {liveStatus ?? job.status} · <span className={styles.mono}>{[job.cmd, ...job.args.slice(1)].join(' ')}</span>
      </p>
      <h3>Live output</h3>
      {liveLines.length === 0 ? (
        <Empty message="No live lines yet — output appears here as the job runs." />
      ) : (
        <pre className={styles.mono} aria-live="polite">
          {liveLines.join('\n')}
        </pre>
      )}
      <h3>Persisted log</h3>
      {logQuery.isPending ? (
        <Loading label="Loading log" />
      ) : logQuery.isError ? (
        <LoadError message={errorMessage(logQuery.error)} onRetry={() => void logQuery.refetch()} />
      ) : (
        <pre className={styles.mono}>{logQuery.data}</pre>
      )}
    </Panel>
  );
}
