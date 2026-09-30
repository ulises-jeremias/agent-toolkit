import { Link, useNavigate, useSearchParams } from 'react-router';
import { isTerminalJobStatus, type Job } from '../../lib/api';
import { formatDuration, formatWhen, jobCommandLine, jobDuration } from '../../lib/format';
import {
  Button,
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
import { attentionVacancy, inspectorHref, matchesInspect, takeNextNeedsMe, type HrefFn } from './attention';
import { useAttention } from './useAttention';
import styles from './office.module.css';

/**
 * Attention inspector for the current harness. The semantic world is the
 * product front door; this destination is the detailed list the world (or
 * palette) opens. Never invents agent or run fields.
 */
export default function Office() {
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const inspect = params.get('inspect');
  const model = useAttention();
  const vacancy = attentionVacancy(model.input, model.items);
  const now = Date.now();
  const bus = model.live.bus;
  const stale =
    bus.state === 'unavailable'
      ? 'Live events unavailable; jobs refresh every 5 seconds.'
      : bus.state === 'reconnecting' || bus.state === 'offline'
        ? 'Event bus is not live; showing last-known jobs.'
        : null;

  const goNext = () => {
    const target = takeNextNeedsMe(model.targets);
    navigate(target ? target.href : inspectorHref(model.href));
  };

  return (
    <>
      <PageHeader
        eyebrow="Office"
        title="Attention"
        lede={<span className={styles.ledeFresh}>{model.lede}</span>}
        actions={
          <Button variant="primary" onClick={goNext} disabled={model.targets.length === 0}>
            Next that needs me
          </Button>
        }
      />
      <Stack>
        <Panel
          tone="manila"
          title="Needs you"
          meta={
            model.items.length > 0 ? `${model.items.length} ${model.items.length === 1 ? 'item' : 'items'}` : undefined
          }
        >
          {vacancy.kind === 'gathering' && model.items.length === 0 ? (
            <LoadingState label="Checking jobs and self-checks" />
          ) : vacancy.kind === 'unknown' && model.items.length === 0 ? (
            <ErrorState
              title="Could not prove that nothing needs you"
              error={model.jobs.error ?? model.selfcheck.error ?? new Error(vacancy.reason)}
              onRetry={() => void model.jobs.refetch()}
            />
          ) : model.items.length === 0 ? (
            <EmptyState title="Nothing needs you.">
              No failed jobs and every self-check passes. Running work is listed below, not here.
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
                {model.items.map((item) => (
                  <tr
                    key={item.key}
                    data-attention={item.kind}
                    data-inspect={matchesInspect(item.key, inspect) ? 'true' : undefined}
                  >
                    <td>
                      <StatusBadge tone={item.tone} label={item.tone === 'err' ? 'failed' : 'warning'} />
                    </td>
                    <th scope="row">{item.title}</th>
                    <td>{item.detail}</td>
                    <td data-align="end">
                      <Link to={item.href}>{item.label}</Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </Table>
          )}
        </Panel>

        <Panel
          title="Happening now"
          meta={
            model.jobs.isSuccess
              ? `${model.running.length} running`
              : bus.state === 'live'
                ? 'event bus live'
                : undefined
          }
        >
          {stale ? <p className={styles.stale}>{stale}</p> : null}
          {model.jobs.isPending ? (
            <LoadingState label="Loading jobs" />
          ) : model.jobs.isError ? (
            <ErrorState
              title="Could not load jobs"
              error={model.jobs.error}
              onRetry={() => void model.jobs.refetch()}
            />
          ) : model.running.length === 0 ? (
            <EmptyState title="No work is running.">
              <Link to={model.href('/operations')}>Start a job in Operations</Link>
            </EmptyState>
          ) : (
            <JobRows jobs={model.running} now={now} href={model.href} inspect={inspect} />
          )}
        </Panel>

        <Panel title="Failed" meta={model.jobs.isSuccess ? `${model.failed.length}` : undefined}>
          {model.jobs.isPending ? (
            <LoadingState label="Loading jobs" />
          ) : model.jobs.isError ? (
            <ErrorState
              title="Could not list failed jobs"
              error={model.jobs.error}
              onRetry={() => void model.jobs.refetch()}
            />
          ) : model.failed.length === 0 ? (
            <EmptyState title="Nothing has failed.">Failed and rejected jobs land here and in Needs you.</EmptyState>
          ) : (
            <JobRows jobs={model.failed} now={now} href={model.href} inspect={inspect} />
          )}
        </Panel>

        {model.jobs.isSuccess && model.finished.length > 0 ? (
          <Panel title="Completed" meta={`${model.finished.length} recently finished`}>
            <JobRows jobs={model.finished.slice(0, 5)} now={now} href={model.href} inspect={inspect} />
          </Panel>
        ) : null}

        <Panel title="What next">
          {model.actions.length === 0 ? (
            <EmptyState title="No next step from this harness." />
          ) : (
            <ol className={styles.nextList}>
              {model.actions.map((action) => (
                <li key={action.key}>
                  <Link to={action.href}>{action.label}</Link>
                  <span className={styles.nextDetail}>{action.detail}</span>
                </li>
              ))}
            </ol>
          )}
        </Panel>
      </Stack>
    </>
  );
}

function JobRows({ jobs, now, href, inspect }: { jobs: Job[]; now: number; href: HrefFn; inspect: string | null }) {
  return (
    <Table>
      <thead>
        <tr>
          <th scope="col">Status</th>
          <th scope="col">Command</th>
          <th scope="col">Workspace</th>
          <th scope="col">Started</th>
          <th scope="col" data-align="end">
            Duration
          </th>
          <th scope="col">
            <VisuallyHidden>Open</VisuallyHidden>
          </th>
        </tr>
      </thead>
      <tbody>
        {jobs.map((job) => {
          const duration = jobDuration(job, now);
          const extra = job.workspace ? { workspace: job.workspace } : undefined;
          const focused = matchesInspect(`job-${job.id}`, inspect) || matchesInspect(job.id, inspect);
          return (
            <tr key={job.id} data-inspect={focused ? 'true' : undefined}>
              <td>
                <StatusBadge tone={jobTone(job.status)} label={job.status} live={!isTerminalJobStatus(job.status)} />
              </td>
              <th scope="row">
                <Link to={href('/operations', { job: job.id })}>
                  <Mono>{jobCommandLine(job)}</Mono>
                </Link>
              </th>
              <td>
                <Mono>{job.workspace || '—'}</Mono>
              </td>
              <td>{formatWhen(job.started_at, now)}</td>
              <td data-align="end">{duration === null ? '—' : formatDuration(duration)}</td>
              <td data-align="end">
                <div className={styles.rowLinks}>
                  <Link to={href('/operations', { job: job.id })}>Operations</Link>
                  <Link to={href('/terminal', extra)}>Terminal</Link>
                  <Link to={href('/insights', extra)}>Insights</Link>
                </div>
              </td>
            </tr>
          );
        })}
      </tbody>
    </Table>
  );
}
