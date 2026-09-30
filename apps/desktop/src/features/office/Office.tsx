import { Link } from 'react-router';
import { useBackend, useSelfcheck } from '../../data/backend';
import { sortJobs, useJobs } from '../../data/jobs';
import { useLiveStatus } from '../../data/live';
import { isTerminalJobStatus, type Job } from '../../lib/api';
import { formatDuration, formatWhen, jobCommandLine, jobDuration } from '../../lib/format';
import {
  EmptyState,
  ErrorState,
  LoadingState,
  Mono,
  PageHeader,
  Panel,
  Stack,
  StatusBadge,
  Table,
  VisuallyHidden,
  jobTone,
} from '../../ui';

const RECENT_FAILURE_MS = 24 * 60 * 60 * 1000;

interface AttentionItem {
  key: string;
  tone: 'err' | 'warn';
  title: string;
  detail: string;
  action: { to: string; label: string };
}

/**
 * Office: what is happening and what needs me?
 * Needs-me is only what a person must act on: the backend being down,
 * failed work, and failing self-checks. Running work is shown separately.
 */
export default function Office() {
  const { backend } = useBackend();
  const live = useLiveStatus();
  const jobs = useJobs();
  const selfcheck = useSelfcheck();
  const now = Date.now();

  const all = sortJobs(jobs.data);
  const running = all.filter((job) => !isTerminalJobStatus(job.status));
  const finished = all.filter((job) => isTerminalJobStatus(job.status));
  const recentFailures = finished.filter((job) => {
    if (job.status !== 'failed' && job.status !== 'rejected') return false;
    const ended = Date.parse(job.ended_at || job.started_at);
    return Number.isNaN(ended) || now - ended < RECENT_FAILURE_MS;
  });

  const attention: AttentionItem[] = [];
  const backendDown = backend?.status === 'crashed' || backend?.status === 'failed' || backend?.status === 'stopped';
  if (backendDown || live.connection === 'offline') {
    attention.push({
      key: 'backend',
      tone: 'err',
      title: backendDown ? `Backend ${backend?.status}` : 'Backend not answering',
      detail: backend?.detail ?? 'Nothing below can refresh until it answers.',
      action: { to: '/settings', label: 'Open backend settings' },
    });
  }
  for (const job of recentFailures) {
    attention.push({
      key: job.id,
      tone: 'err',
      title: `${job.cmd} ${job.status}`,
      detail: `${jobCommandLine(job)} · exit ${job.exit_code} · ${formatWhen(job.ended_at || job.started_at, now)}`,
      action: { to: `/operations?job=${encodeURIComponent(job.id)}`, label: 'Review job' },
    });
  }
  for (const check of selfcheck.data?.checks ?? []) {
    if (check.status === 'ok') continue;
    attention.push({
      key: `check-${check.name}`,
      tone: check.status === 'err' ? 'err' : 'warn',
      title: `Self-check: ${check.name}`,
      detail: check.detail,
      action: { to: '/settings', label: 'See self-check' },
    });
  }

  const gathering = jobs.isPending || selfcheck.isPending;
  const failedToGather = jobs.isError && selfcheck.isError;

  return (
    <>
      <PageHeader
        eyebrow="Office"
        title="What needs you"
        lede="Failures and blocked work first, then what is running."
      />
      <Stack>
        <Panel
          tone="manila"
          title="Needs you"
          meta={gathering ? undefined : `${attention.length} ${attention.length === 1 ? 'item' : 'items'}`}
        >
          {gathering && attention.length === 0 ? (
            <LoadingState label="Checking jobs and self-checks" />
          ) : failedToGather && attention.length === 0 ? (
            <ErrorState
              title="Could not check for attention items"
              error={jobs.error}
              onRetry={() => void jobs.refetch()}
            />
          ) : attention.length === 0 ? (
            <EmptyState title="Nothing needs you.">
              No failed jobs in the last day and every self-check passes.
            </EmptyState>
          ) : (
            <Table>
              <thead>
                <tr>
                  <th scope="col">State</th>
                  <th scope="col">What</th>
                  <th scope="col">Detail</th>
                  <th scope="col">
                    <VisuallyHidden>Action</VisuallyHidden>
                  </th>
                </tr>
              </thead>
              <tbody>
                {attention.map((item) => (
                  <tr key={item.key}>
                    <td>
                      <StatusBadge tone={item.tone} label={item.tone === 'err' ? 'Failed' : 'Warning'} />
                    </td>
                    <th scope="row">{item.title}</th>
                    <td>{item.detail}</td>
                    <td data-align="end">
                      <Link to={item.action.to}>{item.action.label}</Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </Table>
          )}
        </Panel>

        <Panel title="Running now" meta={jobs.isSuccess ? `${running.length} active` : undefined}>
          {jobs.isPending ? (
            <LoadingState label="Loading jobs" />
          ) : jobs.isError ? (
            <ErrorState title="Could not load jobs" error={jobs.error} onRetry={() => void jobs.refetch()} />
          ) : running.length === 0 ? (
            <EmptyState title="No work is running.">
              <Link to="/operations">Start a job in Operations</Link>
            </EmptyState>
          ) : (
            <JobRows jobs={running} now={now} />
          )}
        </Panel>

        {jobs.isSuccess && finished.length > 0 ? (
          <Panel title="Recently finished" meta="Last five">
            <JobRows jobs={finished.slice(0, 5)} now={now} />
          </Panel>
        ) : null}
      </Stack>
    </>
  );
}

function JobRows({ jobs, now }: { jobs: Job[]; now: number }) {
  return (
    <Table>
      <thead>
        <tr>
          <th scope="col">Status</th>
          <th scope="col">Command</th>
          <th scope="col">Started</th>
          <th scope="col" data-align="end">
            Duration
          </th>
        </tr>
      </thead>
      <tbody>
        {jobs.map((job) => {
          const duration = jobDuration(job, now);
          return (
            <tr key={job.id}>
              <td>
                <StatusBadge tone={jobTone(job.status)} label={job.status} live={!isTerminalJobStatus(job.status)} />
              </td>
              <th scope="row">
                <Link to={`/operations?job=${encodeURIComponent(job.id)}`}>
                  <Mono>{jobCommandLine(job)}</Mono>
                </Link>
              </th>
              <td>{formatWhen(job.started_at, now)}</td>
              <td data-align="end">{duration === null ? '—' : formatDuration(duration)}</td>
            </tr>
          );
        })}
      </tbody>
    </Table>
  );
}
