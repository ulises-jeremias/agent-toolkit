import { useRef, useState } from 'react';
import { useSearchParams } from 'react-router';
import {
  useCancelJob,
  useCreateJob,
  useDeleteJob,
  useJobLiveLines,
  useJobLog,
  useJobs,
  sortJobs,
} from '../../data/jobs';
import { useLiveStatus } from '../../data/live';
import { isTerminalJobStatus, type Job } from '../../lib/api';
import { formatDuration, formatWhen, jobCommandLine, jobDuration } from '../../lib/format';
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
  StatusBadge,
  Table,
  TextInput,
  jobTone,
  useActionReceipt,
} from '../../ui';
import styles from './operations.module.css';

/**
 * Operations: what work is running and how do I control it?
 * Jobs live in V; this view lists them, streams output through the shared
 * live bridge, and exposes cancel/delete where the server supports them.
 */
export default function Operations() {
  const [params, setParams] = useSearchParams();
  const selectedId = params.get('job');
  const jobs = useJobs();
  const [starting, setStarting] = useState(false);
  const { connection } = useLiveStatus();

  const select = (id: string | null) => {
    setParams(
      (current) => {
        const next = new URLSearchParams(current);
        if (id) next.set('job', id);
        else next.delete('job');
        return next;
      },
      { replace: true },
    );
  };

  const list = sortJobs(jobs.data);
  const selected = selectedId ? jobs.data?.[selectedId] : undefined;

  return (
    <>
      <PageHeader
        eyebrow="Operations"
        title="Jobs"
        lede="Every agent-toolkit command started from Desktop, the CLI or another window."
        actions={
          <Button
            variant="primary"
            onClick={() => setStarting(true)}
            disabled={connection === 'offline'}
            title={connection === 'offline' ? 'The backend is not answering' : undefined}
          >
            Start job
          </Button>
        }
      />
      <StartJobDialog open={starting} onClose={() => setStarting(false)} onStarted={select} />
      <div className={styles.split}>
        <Panel title="All jobs" meta={jobs.isSuccess ? `${list.length} total` : undefined}>
          <QueryView query={jobs} loading="Loading jobs" errorTitle="Could not load jobs">
            {() =>
              list.length === 0 ? (
                <EmptyState title="No jobs yet.">
                  Start one to run an agent-toolkit command in the background.
                </EmptyState>
              ) : (
                <JobTable jobs={list} selectedId={selectedId} onSelect={select} />
              )
            }
          </QueryView>
        </Panel>
        {selectedId ? (
          selected ? (
            <JobDetail job={selected} onClose={() => select(null)} />
          ) : jobs.isSuccess ? (
            <Panel title="Job not found">
              <EmptyState title={`No job with id ${selectedId}.`}>It may have been deleted.</EmptyState>
              <Button size="sm" onClick={() => select(null)}>
                Clear selection
              </Button>
            </Panel>
          ) : null
        ) : null}
      </div>
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
                  <span className={styles.jobId}>{job.id}</span>
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
  const [cmd, setCmd] = useState('doctor');
  const [args, setArgs] = useState('');
  const [workspace, setWorkspace] = useState('');
  const create = useCreateJob();
  const receipt = useActionReceipt('Job started');
  const cmdRef = useRef<HTMLInputElement>(null);

  const preview = ['agent-toolkit', cmd.trim() || '<command>', ...splitArgs(args)].join(' ');

  const submit = () => {
    if (!cmd.trim()) return;
    create.mutate(
      { cmd: cmd.trim(), args: splitArgs(args), workspace: workspace.trim() || undefined },
      {
        onSuccess: (job) => {
          receipt.onSuccess({ message: jobCommandLine(job) });
          onStarted(job.id);
          onClose();
        },
      },
    );
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Start a job"
      description="Runs one agent-toolkit command in the background on the backend. Output streams into Operations."
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
        <Field label="Command" hint="An agent-toolkit subcommand, for example doctor, loop or swarm.">
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
        <Field label="Arguments" hint="Separated by spaces. Optional.">
          {(control) => <TextInput mono value={args} onChange={(event) => setArgs(event.target.value)} {...control} />}
        </Field>
        <Field label="Workspace folder" hint="Optional. Defaults to the backend's workspace.">
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

function JobDetail({ job, onClose }: { job: Job; onClose: () => void }) {
  const active = !isTerminalJobStatus(job.status);
  const cancel = useCancelJob();
  const remove = useDeleteJob();
  const cancelReceipt = useActionReceipt('Job canceled');
  const deleteReceipt = useActionReceipt('Job deleted');
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
