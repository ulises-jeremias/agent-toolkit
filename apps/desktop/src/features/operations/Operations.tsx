import { useEffect, useRef, useState } from 'react';
import { useSearchParams } from 'react-router';
import {
  useCancelJob,
  useCreateJob,
  useDeleteJob,
  useJobLiveLines,
  useJobLog,
  useJobs,
  useRetryJob,
  sortJobs,
} from '../../data/jobs';
import { useLiveStatus } from '../../data/live';
import { isRetryableJobStatus, isTerminalJobStatus, type Job } from '../../lib/api';
import { formatDuration, formatWhen, jobCommandLine, jobDuration } from '../../lib/format';
import { useSessionContext } from '../../shell/useSessionContext';
import {
  Button,
  ButtonRow,
  ConfirmAction,
  Dialog,
  EmptyState,
  ErrorState,
  Field,
  KeyValue,
  LoadingState,
  Mono,
  PageHeader,
  Panel,
  QueryView,
  Report,
  Stack,
  StatusBadge,
  Table,
  TextInput,
  jobTone,
  useActionReceipt,
} from '../../ui';
import { DoctorPanel } from './Doctor';
import { LoopsPanel } from './Loops';
import { SwarmsPanel } from './Swarms';
import styles from './operations.module.css';

function patchParams(setParams: ReturnType<typeof useSearchParams>[1], patch: Record<string, string | null>): void {
  setParams(
    (current) => {
      const next = new URLSearchParams(current);
      for (const [key, value] of Object.entries(patch)) {
        if (value) next.set(key, value);
        else next.delete(key);
      }
      return next;
    },
    { replace: true },
  );
}

/**
 * Operations is the workshop inspector: jobs, loops, swarms and doctor.
 * The world and Office link here. This destination is not a second home.
 */
export default function Operations() {
  const [params, setParams] = useSearchParams();
  const selectedId = params.get('job');
  const selectedLoop = params.get('loop');
  const selectedSwarm = params.get('swarm');
  const dialog = params.get('dialog');
  const jobs = useJobs();
  const { connection } = useLiveStatus();
  const offline = connection === 'offline';

  const selectJob = (id: string | null) => patchParams(setParams, { job: id });
  const list = sortJobs(jobs.data);
  const selected = selectedId ? jobs.data?.[selectedId] : undefined;

  return (
    <>
      <PageHeader
        eyebrow="Operations"
        title="Workshop"
        lede="The world opens a job, loop, swarm or doctor report here. The board lists only what serve returned."
        actions={
          <>
            <Button
              onClick={() => patchParams(setParams, { dialog: 'start-swarm' })}
              disabled={offline}
              title={offline ? 'The backend is not answering' : undefined}
            >
              Start swarm
            </Button>
            <Button
              onClick={() => patchParams(setParams, { dialog: 'run-loop' })}
              disabled={offline}
              title={offline ? 'The backend is not answering' : undefined}
            >
              Run loop
            </Button>
            <Button
              variant="primary"
              onClick={() => patchParams(setParams, { dialog: 'start-job' })}
              disabled={offline}
              title={offline ? 'The backend is not answering' : undefined}
            >
              Start job
            </Button>
          </>
        }
      />
      <StartJobDialog
        open={dialog === 'start-job'}
        onClose={() => patchParams(setParams, { dialog: null })}
        onStarted={(id) => patchParams(setParams, { job: id, dialog: null })}
      />
      <Stack>
        <div className={`${styles.split} ${styles.board}`}>
          <Panel title="Board" meta={jobs.isSuccess ? `${list.length} on the backend` : undefined}>
            <QueryView query={jobs} loading="Loading jobs" errorTitle="Could not load jobs">
              {() =>
                list.length === 0 ? (
                  <EmptyState title="No jobs on the backend.">
                    Open one from the world, or start a command here. Nothing is invented while the list is empty.
                  </EmptyState>
                ) : (
                  <JobTable jobs={list} selectedId={selectedId} onSelect={selectJob} />
                )
              }
            </QueryView>
          </Panel>
          {selectedId ? (
            selected ? (
              <JobDetail
                job={selected}
                onClose={() => selectJob(null)}
                onRetried={(id) => patchParams(setParams, { job: id })}
              />
            ) : jobs.isSuccess ? (
              <Panel title="Job not found">
                <EmptyState title={`No job with id ${selectedId}.`}>It may have been deleted.</EmptyState>
                <Button size="sm" onClick={() => selectJob(null)}>
                  Clear selection
                </Button>
              </Panel>
            ) : null
          ) : (
            <Panel title="Inspector">
              <EmptyState title="Nothing selected.">
                Pick a job, loop or swarm. Progress and status come from GET /api/v1/events and the job log — never a
                decorative bar.
              </EmptyState>
            </Panel>
          )}
        </div>
        <LoopsPanel
          selectedName={selectedLoop}
          dialogOpen={dialog === 'run-loop'}
          onSelect={(name) => patchParams(setParams, { loop: name })}
          onCloseDialog={() => patchParams(setParams, { dialog: null })}
          onStarted={(id) => patchParams(setParams, { job: id, dialog: null })}
        />
        <SwarmsPanel
          selectedId={selectedSwarm}
          dialogOpen={dialog === 'start-swarm'}
          onSelect={(id) => patchParams(setParams, { swarm: id })}
          onCloseDialog={() => patchParams(setParams, { dialog: null })}
        />
        <DoctorPanel />
      </Stack>
    </>
  );
}

function JobTable({
  jobs,
  selectedId,
  onSelect,
}: {
  jobs: Job[];
  selectedId: string | null;
  onSelect: (id: string) => void;
}) {
  const now = Date.now();
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
          <th scope="col" data-align="end">
            Exit
          </th>
        </tr>
      </thead>
      <tbody>
        {jobs.map((job) => {
          const duration = jobDuration(job, now);
          const done = isTerminalJobStatus(job.status);
          return (
            <tr key={job.id} data-selected={job.id === selectedId} data-interactive="true">
              <td>
                <StatusBadge tone={jobTone(job.status)} label={job.status} live={!done} />
              </td>
              <th scope="row">
                <button
                  type="button"
                  className={styles.rowButton}
                  onClick={() => onSelect(job.id)}
                  aria-current={job.id === selectedId ? 'true' : undefined}
                >
                  <Mono>{jobCommandLine(job)}</Mono>
                  <span className={styles.jobId}>{job.retry_of ? `${job.id} · retry of ${job.retry_of}` : job.id}</span>
                </button>
              </th>
              <td>{formatWhen(job.started_at, now)}</td>
              <td data-align="end">{duration === null ? '—' : formatDuration(duration)}</td>
              <td data-align="end">{done ? job.exit_code : '—'}</td>
            </tr>
          );
        })}
      </tbody>
    </Table>
  );
}

function splitArgs(raw: string): string[] {
  return raw.split(/\s+/).filter(Boolean);
}

function StartJobDialog({
  open,
  onClose,
  onStarted,
}: {
  open: boolean;
  onClose: () => void;
  onStarted: (id: string) => void;
}) {
  const { context } = useSessionContext();
  const [cmd, setCmd] = useState('doctor');
  const [args, setArgs] = useState('');
  const [workspace, setWorkspace] = useState(context.workspace);
  const create = useCreateJob();
  const receipt = useActionReceipt('Job started');
  const cmdRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!workspace && context.workspace) setWorkspace(context.workspace);
  }, [context.workspace, workspace]);

  const preview = ['agent-toolkit', cmd.trim() || '<command>', ...splitArgs(args)].join(' ');

  const submit = () => {
    if (!cmd.trim()) return;
    create.mutate(
      {
        cmd: cmd.trim(),
        args: splitArgs(args),
        workspace: workspace.trim() || context.workspace || undefined,
      },
      {
        onSuccess: (job) => {
          receipt.onSuccess({ message: jobCommandLine(job) });
          onStarted(job.id);
        },
      },
    );
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Start a job"
      description="POST /api/v1/jobs with cmd, args and workspace. The inspector follows the job the backend creates."
      initialFocus={cmdRef}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            variant="primary"
            onClick={submit}
            busy={create.isPending}
            busyLabel="Starting…"
            disabled={cmd.trim() === ''}
          >
            Start job
          </Button>
        </>
      }
    >
      <form
        className={styles.form}
        onSubmit={(event) => {
          event.preventDefault();
          submit();
        }}
      >
        <Field
          label="Command"
          hint="JobCreateReq.cmd — an agent-toolkit subcommand. OpenAPI has no argv schema for this route."
        >
          {(control) => (
            <TextInput
              ref={cmdRef}
              mono
              value={cmd}
              onChange={(event) => setCmd(event.target.value)}
              required
              {...control}
            />
          )}
        </Field>
        <Field label="Arguments" hint="JobCreateReq.args, separated by spaces. Optional.">
          {(control) => <TextInput mono value={args} onChange={(event) => setArgs(event.target.value)} {...control} />}
        </Field>
        <Field label="Workspace folder" hint="Optional. Defaults to the session workspace.">
          {(control) => (
            <TextInput mono value={workspace} onChange={(event) => setWorkspace(event.target.value)} {...control} />
          )}
        </Field>
        <div>
          <p className={styles.previewLabel}>Will run</p>
          <Report text={preview} label="Command preview" />
        </div>
        {create.error ? <ErrorState title="The job did not start" error={create.error} /> : null}
        <button type="submit" hidden />
      </form>
    </Dialog>
  );
}

function JobDetail({ job, onClose, onRetried }: { job: Job; onClose: () => void; onRetried: (id: string) => void }) {
  const active = !isTerminalJobStatus(job.status);
  const retryable = isRetryableJobStatus(job.status);
  const cancel = useCancelJob();
  const remove = useDeleteJob();
  const retry = useRetryJob();
  const cancelReceipt = useActionReceipt('Job canceled');
  const deleteReceipt = useActionReceipt('Job deleted');
  const retryReceipt = useActionReceipt('Job retried');
  const duration = jobDuration(job);

  return (
    <Panel
      title={job.cmd}
      meta={<Mono>{job.id}</Mono>}
      actions={
        <ButtonRow>
          {active ? (
            <Button
              size="sm"
              busy={cancel.isPending}
              busyLabel="Canceling…"
              onClick={() => cancel.mutate(job.id, cancelReceipt)}
            >
              Cancel job
            </Button>
          ) : null}
          {retryable ? (
            <Button
              size="sm"
              variant="primary"
              busy={retry.isPending}
              busyLabel="Retrying…"
              onClick={() =>
                retry.mutate(job.id, {
                  onSuccess: (next) => {
                    retryReceipt.onSuccess({ message: jobCommandLine(next) });
                    onRetried(next.id);
                  },
                  onError: retryReceipt.onError,
                })
              }
            >
              Retry job
            </Button>
          ) : null}
          <ConfirmAction
            label="Delete"
            title={active ? 'Delete a running job?' : 'Delete this job?'}
            description={
              active
                ? 'The process is terminated first, then its record and log are removed. This cannot be undone.'
                : 'Its record and log are removed from the backend. This cannot be undone.'
            }
            confirmLabel={active ? 'Terminate and delete' : 'Delete job'}
            busy={remove.isPending}
            onConfirm={() =>
              remove.mutate(
                { id: job.id, force: active },
                {
                  onSuccess: (result) => {
                    deleteReceipt.onSuccess(result);
                    onClose();
                  },
                  onError: deleteReceipt.onError,
                },
              )
            }
          />
          <Button size="sm" variant="ghost" onClick={onClose}>
            Close
          </Button>
        </ButtonRow>
      }
    >
      <KeyValue
        items={[
          { label: 'Status', value: <StatusBadge tone={jobTone(job.status)} label={job.status} live={active} /> },
          { label: 'Command', value: jobCommandLine(job), mono: true },
          { label: 'Workspace', value: job.workspace || 'Backend default', mono: job.workspace !== '' },
          { label: 'Retry of', value: job.retry_of || '—', mono: Boolean(job.retry_of) },
          { label: 'Started', value: formatWhen(job.started_at) },
          { label: 'Duration', value: duration === null ? '—' : formatDuration(duration) },
          { label: 'Exit code', value: active ? 'Still running' : String(job.exit_code) },
        ]}
      />
      {active ? <LiveOutput jobId={job.id} /> : <PersistedLog jobId={job.id} />}
    </Panel>
  );
}

function LiveOutput({ jobId }: { jobId: string }) {
  const lines = useJobLiveLines(jobId);
  const { streams } = useLiveStatus();
  return (
    <section aria-label="Live output">
      <p className={styles.previewLabel}>
        Live output{streams.state === 'reconnecting' ? ' (reconnecting; the log replays on reconnect)' : ''}
      </p>
      {lines.length === 0 ? (
        <EmptyState title="No output yet.">Lines appear here as the job writes them.</EmptyState>
      ) : (
        <Report text={lines.join('\n')} label="Live output" />
      )}
    </section>
  );
}

function PersistedLog({ jobId }: { jobId: string }) {
  const log = useJobLog(jobId);
  return (
    <section aria-label="Log">
      <p className={styles.previewLabel}>Log</p>
      {log.isPending ? (
        <LoadingState label="Loading log" />
      ) : log.isError ? (
        <ErrorState title="Could not load the log" error={log.error} onRetry={() => void log.refetch()} />
      ) : log.data.trim() === '' ? (
        <EmptyState title="The job wrote no output." />
      ) : (
        <Report text={log.data} label="Job log" />
      )}
    </section>
  );
}
