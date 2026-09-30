import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { useAgents, useModels, useProviders, useTools } from '../../data/catalog';
import { useLiveStatus } from '../../data/live';
import { useSwarmCommand, useSwarmRun, useSwarmRunAction, useSwarms } from '../../data/swarms';
import type { SubBody, SwarmRunInfo, SwarmRunResponse } from '../../lib/api';
import { useSessionContext } from '../../shell/useSessionContext';
import {
  Button,
  ButtonRow,
  ConfirmAction,
  Dialog,
  EmptyState,
  ErrorState,
  Field,
  FormRow,
  KeyValue,
  Mono,
  Panel,
  QueryView,
  Report,
  Select,
  StatusBadge,
  Table,
  TextInput,
  jobTone,
  useActionReceipt,
} from '../../ui';
import styles from './operations.module.css';

function compactBody(body: SubBody<'swarms'>): SubBody<'swarms'> {
  const next: Record<string, string | boolean | number> = {};
  for (const [key, value] of Object.entries(body)) {
    if (value === undefined || value === '' || value === false) continue;
    next[key] = value as string | boolean | number;
  }
  return next as SubBody<'swarms'>;
}

export function SwarmsPanel({
  selectedId,
  dialogOpen,
  onSelect,
  onCloseDialog,
}: {
  selectedId: string | null;
  dialogOpen: boolean;
  onSelect: (id: string | null) => void;
  onCloseDialog: () => void;
}) {
  const list = useSwarms();
  const runs = list.data?.runs ?? [];
  const selected = selectedId ? runs.find((run) => run.run_id === selectedId) : undefined;

  return (
    <>
      <div className={`${styles.split} ${styles.board}`}>
        <Panel title="Swarms" meta={list.isSuccess ? `${runs.length} on the backend` : 'GET /api/v1/swarms'}>
          <QueryView query={list} loading="Listing swarm runs" errorTitle="Could not list swarm runs">
            {() =>
              runs.length === 0 ? (
                <EmptyState title="No swarm runs on the backend.">
                  The world links here with swarm=. Start one only when you have a recipe; this list is not a dashboard.
                </EmptyState>
              ) : (
                <SwarmTable runs={runs} selectedId={selectedId} onSelect={onSelect} />
              )
            }
          </QueryView>
        </Panel>
        {selectedId ? (
          selected || list.isPending ? (
            <SwarmInspector runId={selectedId} summary={selected} onClose={() => onSelect(null)} />
          ) : list.isSuccess ? (
            <Panel title="Run not found">
              <EmptyState title={`No swarm run ${selectedId}.`}>It may have been cleaned up.</EmptyState>
              <Button size="sm" onClick={() => onSelect(null)}>
                Clear selection
              </Button>
            </Panel>
          ) : null
        ) : (
          <Panel title="Swarm inspector">
            <EmptyState title="No swarm selected.">
              Pick a run. Approvals, tasks and handoffs come from GET /api/v1/swarms/runs/{'{id}'}.
            </EmptyState>
          </Panel>
        )}
      </div>
      <StartSwarmDialog open={dialogOpen} onClose={onCloseDialog} />
    </>
  );
}

function SwarmTable({
  runs,
  selectedId,
  onSelect,
}: {
  runs: SwarmRunInfo[];
  selectedId: string | null;
  onSelect: (id: string) => void;
}) {
  return (
    <Table>
      <thead>
        <tr>
          <th scope="col">State</th>
          <th scope="col">Run</th>
          <th scope="col">Recipe</th>
          <th scope="col">Backend</th>
        </tr>
      </thead>
      <tbody>
        {runs.map((run) => (
          <tr key={run.run_id} data-selected={run.run_id === selectedId} data-interactive="true">
            <td>
              <StatusBadge tone={jobTone(run.run_state)} label={run.run_state} />
            </td>
            <th scope="row">
              <button
                type="button"
                className={styles.rowButton}
                onClick={() => onSelect(run.run_id)}
                aria-current={run.run_id === selectedId ? 'true' : undefined}
              >
                <Mono>{run.run_id}</Mono>
                <span className={styles.jobId}>{run.task || 'No task text'}</span>
              </button>
            </th>
            <td>
              <Mono>{run.recipe || '—'}</Mono>
            </td>
            <td>
              <Mono>{run.backend || '—'}</Mono>
            </td>
          </tr>
        ))}
      </tbody>
    </Table>
  );
}

function SwarmInspector({
  runId,
  summary,
  onClose,
}: {
  runId: string;
  summary: SwarmRunInfo | undefined;
  onClose: () => void;
}) {
  const detail = useSwarmRun(runId);
  const action = useSwarmRunAction();
  const receipt = useActionReceipt('Swarm run updated');
  const run = detail.data?.run ?? summary;
  const offline = useLiveStatus().connection === 'offline';

  const act = (kind: 'approve' | 'reject' | 'stop') =>
    action.mutate(
      { id: runId, action: kind },
      {
        onSuccess: (result) => receipt.onSuccess({ message: result.message || result.status }),
        onError: receipt.onError,
      },
    );

  return (
    <Panel
      title={run?.recipe || runId}
      meta={<Mono>{runId}</Mono>}
      actions={
        <ButtonRow>
          <ConfirmAction
            label="Approve"
            title="Approve this swarm run?"
            description={`POST /api/v1/swarms/runs/${runId}/approve. No request body; the path is the gate.`}
            confirmLabel="Approve run"
            disabled={offline}
            busy={action.isPending}
            onConfirm={() => act('approve')}
          />
          <ConfirmAction
            label="Reject"
            title="Reject this swarm run?"
            description={`POST /api/v1/swarms/runs/${runId}/reject.`}
            confirmLabel="Reject run"
            variant="danger"
            disabled={offline}
            busy={action.isPending}
            onConfirm={() => act('reject')}
          />
          <ConfirmAction
            label="Stop"
            title="Stop this swarm run?"
            description={`POST /api/v1/swarms/runs/${runId}/stop.`}
            confirmLabel="Stop run"
            variant="danger"
            disabled={offline}
            busy={action.isPending}
            onConfirm={() => act('stop')}
          />
          <Button size="sm" variant="ghost" onClick={onClose}>
            Close
          </Button>
        </ButtonRow>
      }
    >
      <QueryView query={detail} loading="Loading swarm run" errorTitle="Could not load this swarm run">
        {(data) => <SwarmRunBody data={data} />}
      </QueryView>
    </Panel>
  );
}

function SwarmRunBody({ data }: { data: SwarmRunResponse }) {
  const { run, budget } = data;
  const cost =
    budget.cost_status === 'accounted'
      ? `${budget.total_cost} / ${budget.max_cost_usd}`
      : `unavailable (${budget.cost_status})`;
  return (
    <>
      <KeyValue
        items={[
          { label: 'State', value: <StatusBadge tone={jobTone(run.run_state)} label={run.run_state} /> },
          { label: 'Task', value: run.task || '—' },
          { label: 'Runner', value: data.runner || '—', mono: true },
          { label: 'Model', value: data.model || '—', mono: true },
          { label: 'Tokens', value: `${budget.total_tokens} / ${budget.max_total_tokens}` },
          { label: 'Cost', value: cost },
        ]}
      />
      <SwarmSection title="Approvals" empty="No gates on this run.">
        {data.approvals.length > 0 ? (
          <Table>
            <thead>
              <tr>
                <th scope="col">Gate</th>
                <th scope="col">Required</th>
                <th scope="col">Approved</th>
                <th scope="col">Rejected</th>
              </tr>
            </thead>
            <tbody>
              {data.approvals.map((gate) => (
                <tr key={gate.id}>
                  <th scope="row">{gate.description || gate.id}</th>
                  <td>{gate.required ? 'yes' : 'no'}</td>
                  <td>{gate.approved ? 'yes' : 'no'}</td>
                  <td>{gate.rejected ? 'yes' : 'no'}</td>
                </tr>
              ))}
            </tbody>
          </Table>
        ) : null}
      </SwarmSection>
      <SwarmSection title="Tasks" empty="No tasks reported.">
        {data.tasks.length > 0 ? (
          <Table>
            <thead>
              <tr>
                <th scope="col">Status</th>
                <th scope="col">Task</th>
                <th scope="col">Owner</th>
              </tr>
            </thead>
            <tbody>
              {data.tasks.map((task) => (
                <tr key={task.id}>
                  <td>
                    <StatusBadge tone={jobTone(task.status)} label={task.status} />
                  </td>
                  <th scope="row">
                    <Mono>{task.id}</Mono>
                  </th>
                  <td>{task.owner || '—'}</td>
                </tr>
              ))}
            </tbody>
          </Table>
        ) : null}
      </SwarmSection>
      <SwarmSection title="Handoffs" empty="No handoffs reported.">
        {data.handoffs.length > 0 ? (
          <Table>
            <thead>
              <tr>
                <th scope="col">State</th>
                <th scope="col">From</th>
                <th scope="col">To</th>
              </tr>
            </thead>
            <tbody>
              {data.handoffs.map((handoff) => (
                <tr key={handoff.id}>
                  <td>
                    <StatusBadge tone={jobTone(handoff.state)} label={handoff.state} />
                  </td>
                  <td>{handoff.from_role}</td>
                  <td>{handoff.to_role}</td>
                </tr>
              ))}
            </tbody>
          </Table>
        ) : null}
      </SwarmSection>
      {data.trace_tail.length > 0 ? (
        <section aria-label="Trace">
          <p className={styles.previewLabel}>Trace tail</p>
          <Report text={data.trace_tail.join('\n')} label="Swarm trace" />
        </section>
      ) : null}
    </>
  );
}

function SwarmSection({ title, empty, children }: { title: string; empty: string; children: ReactNode }) {
  const hasRows = children !== null;
  return (
    <section aria-label={title} className={styles.subsection}>
      <p className={styles.previewLabel}>{title}</p>
      {hasRows ? children : <EmptyState title={empty} />}
    </section>
  );
}

function StartSwarmDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { context } = useSessionContext();
  const agents = useAgents();
  const tools = useTools();
  const providers = useProviders();
  const models = useModels();
  const mutate = useSwarmCommand();
  const receipt = useActionReceipt('Swarm start posted');
  const [recipe, setRecipe] = useState('');
  const [task, setTask] = useState('');
  const [runner, setRunner] = useState('');
  const [model, setModel] = useState('');
  const [role, setRole] = useState(context.agent);
  const [dryRun, setDryRun] = useState(false);

  useEffect(() => {
    if (!role && context.agent) setRole(context.agent);
  }, [context.agent, role]);

  const body = useMemo(() => {
    const payload: SubBody<'swarms'> = {
      workspace: context.workspace || undefined,
      recipe: recipe.trim() || undefined,
      task: task.trim() || undefined,
      runner: runner || undefined,
      backend: runner || undefined,
      model_profile: model || undefined,
      role: role.trim() || undefined,
      dry_run: dryRun || undefined,
    };
    return compactBody(payload);
  }, [context.workspace, dryRun, model, recipe, role, runner, task]);

  const preview = `POST /api/v1/swarms/start\n${JSON.stringify(body, null, 2)}`;
  const availableProviders = providers.data?.providers.filter((provider) => provider.available) ?? [];

  const submit = () => {
    mutate.mutate(
      { sub: 'start', body },
      {
        onSuccess: (envelope) => {
          receipt.onSuccess({ message: envelope.message || 'swarms start' });
          onClose();
        },
      },
    );
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Start a swarm"
      description="POST /api/v1/swarms/start with the OpenAPI body. List, approve, reject and stop use the typed /runs routes."
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="primary" onClick={submit} busy={mutate.isPending} busyLabel="Starting…">
            Start swarm
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
        <Field label="Recipe">
          {(control) => (
            <TextInput mono value={recipe} onChange={(event) => setRecipe(event.target.value)} {...control} />
          )}
        </Field>
        <Field label="Task">
          {(control) => <TextInput value={task} onChange={(event) => setTask(event.target.value)} {...control} />}
        </Field>
        <FormRow>
          <Field
            label="Runner"
            hint={
              tools.isSuccess
                ? `${tools.data.tools.filter((tool) => tool.verified).length} verified coding tools.`
                : 'GET /api/v1/providers. enabled=unknown is not treated as false.'
            }
          >
            {(control) => (
              <Select value={runner} onChange={(event) => setRunner(event.target.value)} {...control}>
                <option value="">Backend default</option>
                {(availableProviders.length > 0 ? availableProviders : (providers.data?.providers ?? [])).map(
                  (provider) => (
                    <option key={provider.id} value={provider.id}>
                      {provider.id}
                      {provider.available ? '' : ' (unavailable)'}
                    </option>
                  ),
                )}
              </Select>
            )}
          </Field>
          <Field label="Model profile" hint="GET /api/v1/models">
            {(control) => (
              <Select value={model} onChange={(event) => setModel(event.target.value)} {...control}>
                <option value="">Backend default</option>
                {(models.data?.models ?? []).map((item) => (
                  <option key={`${item.profile}-${item.runner}`} value={item.profile}>
                    {item.profile} · {item.runner}
                  </option>
                ))}
              </Select>
            )}
          </Field>
        </FormRow>
        <Field label="Role" hint="Persona id from GET /api/v1/agents">
          {(control) => (
            <Select value={role} onChange={(event) => setRole(event.target.value)} {...control}>
              <option value="">None</option>
              {(agents.data?.agents ?? []).map((agent) => (
                <option key={agent.id} value={agent.id}>
                  {agent.id} — {agent.name}
                </option>
              ))}
            </Select>
          )}
        </Field>
        <label className={styles.check}>
          <input type="checkbox" checked={dryRun} onChange={(event) => setDryRun(event.target.checked)} />
          Dry run
        </label>
        <div>
          <p className={styles.previewLabel}>Will call</p>
          <Report text={preview} label="Swarm request preview" />
        </div>
        {mutate.error ? <ErrorState title="The swarm did not start" error={mutate.error} /> : null}
        <button type="submit" hidden />
      </form>
    </Dialog>
  );
}
