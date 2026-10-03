import { useEffect, useMemo, useState } from 'react';
import { useSubMutation, useSubQuery } from '../../data/commands';
import {
  useInitializeLoop,
  useLoopAudit,
  useLoopCost,
  useLoopHistory,
  useLoopStatus,
  useLoops,
  useRunLoop,
} from '../../data/loops';
import { envelopeText, type CommandEnvelope, type LoopInfo } from '../../lib/api';
import { jobCommandLine } from '../../lib/format';
import { useSessionContext } from '../../shell/useSessionContext';
import {
  Button,
  ButtonRow,
  Dialog,
  EmptyState,
  ErrorState,
  Field,
  KeyValue,
  LoadingState,
  Mono,
  Panel,
  QueryView,
  Report,
  Select,
  StatusBadge,
  Table,
  TextInput,
  useActionReceipt,
} from '../../ui';
import { parseLoopNames, type LoopListEntry } from './loopList';
import styles from './operations.module.css';

export function LoopsPanel({
  selectedName,
  scheduleName,
  dialogOpen,
  onSelect,
  onRun,
  onSchedule,
  onCloseSchedule,
  onCloseDialog,
  onStarted,
}: {
  selectedName: string | null;
  scheduleName: string | null;
  dialogOpen: boolean;
  onSelect: (name: string | null) => void;
  onRun: (name: string) => void;
  onSchedule: (name: string) => void;
  onCloseSchedule: () => void;
  onCloseDialog: () => void;
  onStarted: (jobId: string) => void;
}) {
  const list = useLoops();
  const templates = useSubQuery('loops', 'templates');
  const installed = list.data?.loops ?? [];
  const templateEntries = useMemo(
    () => (templates.data ? parseLoopNames(templates.data, 'template') : []),
    [templates.data],
  ).filter((entry) => !installed.some((loop) => loop.name === entry.name));
  const selectedLoop = installed.find((loop) => loop.name === selectedName);
  const selectedTemplate = templateEntries.find((entry) => entry.name === selectedName);

  return (
    <>
      <Panel title="Loops" meta={list.isSuccess ? `${installed.length} installed` : undefined}>
        <QueryView query={list} loading="Loading workspace loops" errorTitle="Could not load loops">
          {() =>
            installed.length === 0 ? (
              <EmptyState title="No loops installed yet.">
                Choose a reviewed template below to add one to this workspace. Its definition will be created in
                <Mono> loops/</Mono> before it can run.
              </EmptyState>
            ) : (
              <LoopTable entries={installed.map(toLoopEntry)} selectedName={selectedName} onSelect={onSelect} />
            )
          }
        </QueryView>
        {templates.isSuccess && templateEntries.length > 0 ? (
          <div className={styles.subsection}>
            <p className={styles.previewLabel}>Available templates</p>
            <LoopTable entries={templateEntries} selectedName={selectedName} onSelect={onSelect} />
          </div>
        ) : null}
        {templates.isPending ? <LoadingState label="Loading loop templates" /> : null}
        {templates.isError ? (
          <ErrorState
            title="Could not load loop templates"
            error={templates.error}
            onRetry={() => void templates.refetch()}
          />
        ) : null}
        {selectedLoop ? (
          <LoopDetail
            loop={selectedLoop}
            onRun={() => onRun(selectedLoop.name)}
            onSchedule={() => onSchedule(selectedLoop.name)}
          />
        ) : null}
        {selectedTemplate ? <TemplateDetail entry={selectedTemplate} onInitialized={onSelect} /> : null}
      </Panel>
      <RunLoopDialog
        open={dialogOpen}
        loops={installed}
        initialName={selectedName}
        onClose={onCloseDialog}
        onStarted={onStarted}
      />
      <ManageLoopScheduleDialog
        open={scheduleName !== null}
        loop={installed.find((loop) => loop.name === scheduleName) ?? null}
        onClose={onCloseSchedule}
      />
    </>
  );
}

function toLoopEntry(loop: LoopInfo): LoopListEntry {
  return {
    name: loop.name,
    meta: `${loop.tier} · ${loop.cadence} · ${loop.goal}`,
    source: 'installed',
  };
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
          <th scope="col">Loop</th>
          <th scope="col">Goal / cadence</th>
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

function TemplateDetail({ entry, onInitialized }: { entry: LoopListEntry; onInitialized: (name: string) => void }) {
  const [open, setOpen] = useState(false);
  return (
    <div className={styles.subsection}>
      <p className={styles.previewLabel}>Template preview</p>
      <KeyValue
        items={[
          { label: 'Template', value: <Mono>{entry.name}</Mono> },
          { label: 'Definition', value: entry.meta },
        ]}
      />
      <ButtonRow>
        <Button variant="primary" onClick={() => setOpen(true)}>
          Add to workspace
        </Button>
      </ButtonRow>
      <InitializeLoopDialog
        open={open}
        entry={entry}
        onClose={() => setOpen(false)}
        onInitialized={(name) => {
          setOpen(false);
          onInitialized(name);
        }}
      />
    </div>
  );
}

function LoopDetail({ loop, onRun, onSchedule }: { loop: LoopInfo; onRun: () => void; onSchedule: () => void }) {
  const status = useLoopStatus(loop.name);
  const history = useLoopHistory(loop.name);
  const audit = useLoopAudit(loop.name);
  const cost = useLoopCost(loop.name);
  return (
    <div className={styles.subsection}>
      <div className={styles.detailHeading}>
        <div>
          <p className={styles.previewLabel}>Loop report</p>
          <h3>{loop.name}</h3>
        </div>
        <ButtonRow>
          <Button onClick={onSchedule}>Manage schedule</Button>
          <Button variant="primary" onClick={onRun}>
            Run once
          </Button>
        </ButtonRow>
      </div>
      <QueryView query={status} loading="Reading loop definition and budget" errorTitle="Could not read loop status">
        {(report) => (
          <KeyValue
            items={[
              { label: 'Goal', value: report.info.goal },
              { label: 'Tier / cadence', value: `${report.info.tier} · ${report.info.cadence}` },
              {
                label: 'Last state',
                value: <StatusBadge tone={toneForLoop(report.info.status)} label={report.info.status} />,
              },
              { label: 'Runs recorded', value: report.info.runs },
              { label: 'Run budget', value: `${report.budget.max_runs_per_day} per day` },
              { label: 'Token budget', value: report.budget.max_tokens.toLocaleString() },
              { label: 'Wall budget', value: `${report.budget.max_wall_seconds}s` },
            ]}
          />
        )}
      </QueryView>
      <QueryView query={history} loading="Reading run history" errorTitle="Could not read loop history">
        {(report) => (
          <section aria-label={`${loop.name} run history`}>
            <p className={styles.previewLabel}>Recent runs</p>
            {report.runs.length === 0 ? (
              <EmptyState title="No run records yet.">
                The first real run will appear here with its backend status.
              </EmptyState>
            ) : (
              <Table>
                <thead>
                  <tr>
                    <th scope="col">Run</th>
                    <th scope="col">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {[...report.runs]
                    .reverse()
                    .slice(0, 8)
                    .map((run) => (
                      <tr key={run.id}>
                        <th scope="row">
                          <Mono>{run.id}</Mono>
                        </th>
                        <td>
                          <StatusBadge tone={toneForLoop(run.status)} label={run.status} />
                        </td>
                      </tr>
                    ))}
                </tbody>
              </Table>
            )}
          </section>
        )}
      </QueryView>
      <QueryView query={audit} loading="Reading loop audit" errorTitle="Could not read loop audit">
        {(report) => (
          <section aria-label={`${loop.name} audit`}>
            <p className={styles.previewLabel}>Audit</p>
            <KeyValue
              items={[
                { label: 'Completed', value: report.completed },
                { label: 'Failed', value: report.failed },
                { label: 'Success rate', value: report.rate },
                { label: 'Tokens', value: report.tokens ? `≈ ${report.tokens.toLocaleString()}` : 'Not recorded' },
              ]}
            />
          </section>
        )}
      </QueryView>
      <QueryView query={cost} loading="Checking cost evidence" errorTitle="Could not read cost report">
        {(report) => (
          <section aria-label={`${loop.name} cost report`}>
            <p className={styles.previewLabel}>Cost</p>
            <p>{report.cost_status === 'accounted' ? report.detail : `Unavailable — ${report.detail}`}</p>
          </section>
        )}
      </QueryView>
    </div>
  );
}

function ManageLoopScheduleDialog({
  open,
  loop,
  onClose,
}: {
  open: boolean;
  loop: LoopInfo | null;
  onClose: () => void;
}) {
  const schedules = useSubQuery('loops', 'schedule', { list_mode: true }, { enabled: open });
  const action = useSubMutation('loops', 'schedule');
  const receipt = useActionReceipt('Loop schedule updated');
  const [reviewed, setReviewed] = useState<('install' | 'remove') | null>(null);
  const [requestedPreview, setRequestedPreview] = useState<('install' | 'remove') | null>(null);
  const [plan, setPlan] = useState<CommandEnvelope | null>(null);

  useEffect(() => {
    if (!open) {
      setReviewed(null);
      setRequestedPreview(null);
      setPlan(null);
    }
  }, [open]);

  const preview = (kind: 'install' | 'remove') => {
    if (!loop) return;
    setRequestedPreview(kind);
    setReviewed(null);
    setPlan(null);
    action.mutate(
      { name: loop.name, dry_run: true, remove_mode: kind === 'remove' },
      {
        onSuccess: (result) => {
          setPlan(result);
          setReviewed(kind);
        },
      },
    );
  };

  const apply = () => {
    if (!loop || !reviewed) return;
    action.mutate(
      { name: loop.name, remove_mode: reviewed === 'remove' },
      {
        onSuccess: (result) => {
          receipt.onSuccess(result);
          setPlan(null);
          setReviewed(null);
          setRequestedPreview(null);
        },
      },
    );
  };

  return (
    <Dialog
      open={open && loop !== null}
      onClose={onClose}
      title={`Schedule ${loop?.name ?? 'loop'}`}
      description="Schedules run this loop automatically using the cadence in its definition. Review the real scheduler changes before applying them."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Close
          </Button>
          {reviewed ? (
            <Button
              variant={reviewed === 'remove' ? 'danger' : 'primary'}
              onClick={apply}
              busy={action.isPending}
              busyLabel="Applying…"
            >
              {reviewed === 'remove' ? 'Disable schedule' : 'Install schedule'}
            </Button>
          ) : null}
        </>
      }
    >
      {loop ? (
        <>
          <KeyValue
            items={[
              { label: 'Loop', value: <Mono>{loop.name}</Mono> },
              { label: 'Cadence', value: loop.cadence },
              { label: 'Scheduler', value: 'Current user · systemd or launchd' },
              { label: 'Automatic run', value: loop.goal },
            ]}
          />
          <section className={styles.subsection} aria-label="Installed loop schedules">
            <p className={styles.previewLabel}>Schedules on this machine</p>
            <QueryView query={schedules} loading="Checking installed schedules" errorTitle="Could not check schedules">
              {(result) => <Report text={envelopeText(result)} label="Installed schedules from the local scheduler" />}
            </QueryView>
          </section>
          <ButtonRow>
            <Button onClick={() => preview('install')} busy={action.isPending}>
              Review install
            </Button>
            <Button onClick={() => preview('remove')} busy={action.isPending}>
              Review disable
            </Button>
          </ButtonRow>
          {reviewed && plan ? (
            <section className={styles.subsection} aria-label="Schedule change preview">
              <p className={styles.previewLabel}>{reviewed === 'remove' ? 'Disable preview' : 'Install preview'}</p>
              <KeyValue
                items={[
                  ...(plan.data['service_path']
                    ? [
                        {
                          label: reviewed === 'remove' ? 'Remove service' : 'Create service',
                          value: <Mono>{plan.data['service_path']}</Mono>,
                        },
                      ]
                    : []),
                  ...(plan.data['timer_path']
                    ? [
                        {
                          label: reviewed === 'remove' ? 'Remove timer' : 'Create timer',
                          value: <Mono>{plan.data['timer_path']}</Mono>,
                        },
                      ]
                    : []),
                  ...(plan.data['plist_path']
                    ? [
                        {
                          label: reviewed === 'remove' ? 'Remove launch agent' : 'Create launch agent',
                          value: <Mono>{plan.data['plist_path']}</Mono>,
                        },
                      ]
                    : []),
                  ...(plan.data['on_calendar']
                    ? [{ label: 'Runs on', value: <Mono>{plan.data['on_calendar']}</Mono> }]
                    : []),
                  ...(plan.data['interval_seconds']
                    ? [{ label: 'Run interval', value: `${plan.data['interval_seconds']} seconds` }]
                    : []),
                ]}
              />
              <details className={styles.scheduleDetails}>
                <summary>View generated scheduler details</summary>
                <Report text={envelopeText(plan)} label="Exact scheduler files and commands" />
              </details>
              <p>
                {reviewed === 'remove'
                  ? 'This removes only this loop’s user-level timer or launch agent. The loop definition and past reports stay in the workspace.'
                  : 'Applying writes a user-level service and timer (Linux) or launch agent (macOS), then asks the OS scheduler to enable it.'}
              </p>
            </section>
          ) : null}
          {action.error ? (
            <ErrorState
              title="Scheduler change needs attention"
              error={action.error}
              guidance={
                reviewed === null
                  ? 'The preview could not be prepared, so no schedule change was applied. Check the error, then retry the preview.'
                  : reviewed === 'remove'
                    ? 'The timer may already be stopped, but its files remain when cleanup fails. Check the scheduler output, then retry the disable action.'
                    : 'Installation may have written scheduler files before activation failed. Review the output, then retry to complete or replace the schedule.'
              }
              retryLabel={
                reviewed === null ? 'Retry preview' : reviewed === 'remove' ? 'Retry disable' : 'Retry install'
              }
              onRetry={() => {
                if (reviewed) apply();
                else if (requestedPreview) preview(requestedPreview);
              }}
            />
          ) : null}
        </>
      ) : null}
    </Dialog>
  );
}

function toneForLoop(status: string): 'ok' | 'warn' | 'err' | 'idle' {
  const value = status.toLowerCase();
  if (value.includes('completed') || value === 'ok' || value === 'success') return 'ok';
  if (value.includes('fail') || value.includes('error') || value.includes('blocked')) return 'err';
  if (value === 'unknown' || value === 'unavailable' || value === '—') return 'idle';
  return 'warn';
}

function InitializeLoopDialog({
  open,
  entry,
  onClose,
  onInitialized,
}: {
  open: boolean;
  entry: LoopListEntry | null;
  onClose: () => void;
  onInitialized: (name: string) => void;
}) {
  const { context } = useSessionContext();
  const initialize = useInitializeLoop();
  const receipt = useActionReceipt('Loop added');
  const [customName, setCustomName] = useState('');
  useEffect(() => {
    setCustomName(entry?.name ?? '');
  }, [entry?.name]);
  const submit = () => {
    if (!entry || !customName.trim()) return;
    initialize.mutate(
      { name: entry.name, custom_name: customName.trim(), workspace: context.workspace || undefined },
      {
        onSuccess: (result) => {
          receipt.onSuccess(result);
          onInitialized(customName.trim());
        },
      },
    );
  };
  return (
    <Dialog
      open={open && entry !== null}
      onClose={onClose}
      title={`Add ${entry?.name ?? 'loop'} to this workspace`}
      description="This creates a Toolkit loop definition in the active workspace. It does not run the loop or install a schedule."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            variant="primary"
            onClick={submit}
            busy={initialize.isPending}
            busyLabel="Adding…"
            disabled={!entry || !customName.trim()}
          >
            Create loop
          </Button>
        </>
      }
    >
      {entry ? (
        <>
          <KeyValue
            items={[
              { label: 'Template', value: <Mono>{entry.name}</Mono> },
              { label: 'Definition', value: entry.meta },
              { label: 'Workspace', value: <Mono>{context.workspace || 'Backend default'}</Mono> },
              { label: 'Will create', value: <Mono>loops/{customName || entry.name}/loop.yaml</Mono> },
              { label: 'Existing files', value: 'The backend refuses to overwrite an existing loop.' },
            ]}
          />
          <Field label="Loop name" hint="Choose a short id for this workspace copy.">
            {(control) => (
              <TextInput
                {...control}
                value={customName}
                onChange={(event) => setCustomName(event.target.value)}
                required
                pattern="[a-zA-Z0-9][a-zA-Z0-9_-]*"
              />
            )}
          </Field>
        </>
      ) : null}
      {initialize.error ? <ErrorState title="The loop was not added" error={initialize.error} /> : null}
    </Dialog>
  );
}

function RunLoopDialog({
  open,
  loops,
  initialName,
  onClose,
  onStarted,
}: {
  open: boolean;
  loops: LoopInfo[];
  initialName: string | null;
  onClose: () => void;
  onStarted: (jobId: string) => void;
}) {
  const { context } = useSessionContext();
  const run = useRunLoop();
  const receipt = useActionReceipt('Loop started as a job');
  const [name, setName] = useState(initialName ?? loops[0]?.name ?? '');
  const status = useLoopStatus(name || null);
  useEffect(() => {
    if (open && initialName) setName(initialName);
    else if (open && !loops.some((loop) => loop.name === name)) setName(loops[0]?.name ?? '');
  }, [open, initialName, loops, name]);
  const selected = loops.find((loop) => loop.name === name);
  const submit = () => {
    if (!selected) return;
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
      title="Run a loop once"
      description="The active backend starts a real loop job. Follow its output and final report in Operations."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="primary" onClick={submit} busy={run.isPending} busyLabel="Starting…" disabled={!selected}>
            Run loop
          </Button>
        </>
      }
    >
      {loops.length === 0 ? (
        <EmptyState title="Add a loop before running it.">
          Choose an available template from the Loops panel.
        </EmptyState>
      ) : (
        <>
          <Field label="Installed loop" hint="Only loops present in this workspace can run.">
            {(control) => (
              <Select {...control} value={name} onChange={(event) => setName(event.target.value)}>
                {loops.map((loop) => (
                  <option key={loop.name} value={loop.name}>
                    {loop.name}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          {selected ? (
            <KeyValue
              items={[
                { label: 'Goal', value: selected.goal },
                { label: 'Runner', value: 'Loop definition / backend default' },
                { label: 'Previous runs', value: selected.runs },
                { label: 'Workspace', value: <Mono>{context.workspace || 'Backend default'}</Mono> },
                { label: 'Result', value: 'A new job with live output; this does not create a schedule.' },
              ]}
            />
          ) : null}
          {status.isSuccess ? (
            <KeyValue
              items={[
                { label: 'Daily run limit', value: status.data.budget.max_runs_per_day },
                { label: 'Token budget', value: status.data.budget.max_tokens.toLocaleString() },
                { label: 'Time limit', value: `${status.data.budget.max_wall_seconds}s` },
              ]}
            />
          ) : status.isError ? (
            <ErrorState title="Budget preview unavailable" error={status.error} />
          ) : null}
        </>
      )}
      {run.error ? <ErrorState title="The loop did not start" error={run.error} /> : null}
    </Dialog>
  );
}
