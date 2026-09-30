import { useEffect, useMemo, useState } from 'react';
import { useReport, useSubQuery } from '../../data/commands';
import { useLiveStatus } from '../../data/live';
import { useLoopStatus, useRunLoop } from '../../data/loops';
import { jobCommandLine } from '../../lib/format';
import { useSessionContext } from '../../shell/useSessionContext';
import {
  Button,
  CommandReport,
  Dialog,
  EmptyState,
  ErrorState,
  Field,
  Mono,
  Panel,
  QueryView,
  Report,
  Select,
  Table,
  useActionReceipt,
} from '../../ui';
import { parseLoopNames, type LoopListEntry } from './loopList';
import styles from './operations.module.css';

export function LoopsPanel({
  selectedName,
  dialogOpen,
  onSelect,
  onCloseDialog,
  onStarted,
}: {
  selectedName: string | null;
  dialogOpen: boolean;
  onSelect: (name: string | null) => void;
  onCloseDialog: () => void;
  onStarted: (jobId: string) => void;
}) {
  const list = useReport('loops');
  const templates = useSubQuery('loops', 'templates');
  const installed = useMemo(() => (list.data ? parseLoopNames(list.data, 'installed') : []), [list.data]);
  const templateEntries = useMemo(
    () => (templates.data ? parseLoopNames(templates.data, 'template') : []),
    [templates.data],
  );
  const selected =
    installed.find((entry) => entry.name === selectedName) ??
    templateEntries.find((entry) => entry.name === selectedName);

  return (
    <>
      <Panel title="Loops" meta={list.isSuccess ? `${installed.length} in this workspace` : undefined}>
        <QueryView query={list} loading="Listing loops" errorTitle="Could not list loops">
          {() =>
            installed.length === 0 ? (
              <EmptyState title="No loops in this workspace.">
                Templates below can still be run as a job; the backend reports failure if the loop is not initialized.
              </EmptyState>
            ) : (
              <LoopTable entries={installed} selectedName={selectedName} onSelect={onSelect} />
            )
          }
        </QueryView>
        {templates.isSuccess && templateEntries.length > 0 ? (
          <div className={styles.subsection}>
            <p className={styles.previewLabel}>Templates</p>
            <LoopTable entries={templateEntries} selectedName={selectedName} onSelect={onSelect} />
          </div>
        ) : null}
        {selected ? <LoopDetail entry={selected} /> : null}
      </Panel>
      <RunLoopDialog
        open={dialogOpen}
        names={[...installed, ...templateEntries.filter((entry) => !installed.some((row) => row.name === entry.name))]}
        initialName={selectedName}
        onClose={onCloseDialog}
        onStarted={onStarted}
      />
    </>
  );
}

function LoopTable({
  entries,
  selectedName,
  onSelect,
}: {
  entries: LoopListEntry[];
  selectedName: string | null;
  onSelect: (name: string) => void;
}) {
  return (
    <Table>
      <thead>
        <tr>
          <th scope="col">Name</th>
          <th scope="col">Detail</th>
          <th scope="col">Source</th>
        </tr>
      </thead>
      <tbody>
        {entries.map((entry) => (
          <tr key={`${entry.source}-${entry.name}`} data-selected={entry.name === selectedName} data-interactive="true">
            <th scope="row">
              <button type="button" className={styles.rowButton} onClick={() => onSelect(entry.name)}>
                <Mono>{entry.name}</Mono>
              </button>
            </th>
            <td>{entry.meta || '—'}</td>
            <td>{entry.source}</td>
          </tr>
        ))}
      </tbody>
    </Table>
  );
}

function LoopDetail({ entry }: { entry: LoopListEntry }) {
  const status = useLoopStatus(entry.name);
  return (
    <div className={styles.subsection}>
      <p className={styles.previewLabel}>
        Status <Mono>{entry.name}</Mono>
      </p>
      <QueryView query={status} loading="Reading loop status" errorTitle="Could not read loop status">
        {(envelope) => <CommandReport envelope={envelope} label={`Status of ${entry.name}`} />}
      </QueryView>
    </div>
  );
}

function RunLoopDialog({
  open,
  names,
  initialName,
  onClose,
  onStarted,
}: {
  open: boolean;
  names: LoopListEntry[];
  initialName: string | null;
  onClose: () => void;
  onStarted: (jobId: string) => void;
}) {
  const { context } = useSessionContext();
  const { connection } = useLiveStatus();
  const [name, setName] = useState(initialName ?? names[0]?.name ?? '');
  const run = useRunLoop();
  const receipt = useActionReceipt('Loop started as a job');
  const unique = names.filter((entry, index) => names.findIndex((row) => row.name === entry.name) === index);
  const firstName = unique[0]?.name ?? '';

  useEffect(() => {
    if (!open || name) return;
    setName(initialName || firstName);
  }, [open, initialName, firstName, name]);

  const submit = () => {
    if (!name) return;
    run.mutate(name, {
      onSuccess: (job) => {
        receipt.onSuccess({ message: jobCommandLine(job) });
        onStarted(job.id);
      },
    });
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Run a loop as a job"
      description="POST /api/v1/loops/{name}/run enqueues loop run on the job runner. Output streams in Jobs."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            variant="primary"
            onClick={submit}
            busy={run.isPending}
            busyLabel="Starting…"
            disabled={!name || connection === 'offline'}
            title={connection === 'offline' ? 'The backend is not answering' : undefined}
          >
            Run as job
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
        <Field label="Loop" hint="Name from GET /api/v1/loops or loop templates. The path is the body.">
          {(control) => (
            <Select value={name} onChange={(event) => setName(event.target.value)} required {...control}>
              {unique.length === 0 ? <option value="">No loops listed</option> : null}
              {unique.map((entry) => (
                <option key={entry.name} value={entry.name}>
                  {entry.name}
                  {entry.source === 'template' ? ' (template)' : ''}
                </option>
              ))}
            </Select>
          )}
        </Field>
        <p className={styles.previewLabel}>Workspace</p>
        <p>
          <Mono>{context.workspace || 'Backend default'}</Mono>
        </p>
        <div>
          <p className={styles.previewLabel}>Will call</p>
          <Report text={`POST /api/v1/loops/${name || '<name>'}/run`} label="Request preview" />
        </div>
        {run.error ? <ErrorState title="The loop did not start" error={run.error} /> : null}
        <button type="submit" hidden />
      </form>
    </Dialog>
  );
}
