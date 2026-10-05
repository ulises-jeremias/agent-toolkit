import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useModels, useProviders } from '../../data/catalog';
import { useLiveStatus } from '../../data/live';
import { useSwarmCommand, useSwarmRecipes, useSwarmRun, useSwarmRunAction, useSwarms } from '../../data/swarms';
import { requireOk, type CommandEnvelope, type SubBody, type SwarmRunInfo, type SwarmRunResponse } from '../../lib/api';
import { requireClient, useBackend } from '../../data/backend';
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
  const next: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(body)) {
    if (value === undefined || value === '' || value === false) continue;
    if (typeof value === 'object' && value !== null && Object.keys(value).length === 0) continue;
    next[key] = value;
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
      <div className={`${styles.split} ${styles.board} ${selectedId ? styles.focused : ''}`}>
        <Panel title="Swarms" meta={list.isSuccess ? `${runs.length} on the backend` : 'GET /api/v1/swarms'}>
          <div className={selectedId ? styles.runList : undefined}>
            <QueryView query={list} loading="Listing swarm runs" errorTitle="Could not list swarm runs">
              {() =>
                runs.length === 0 ? (
                  <EmptyState title="No swarm runs on the backend.">
                    The world links here with swarm=. Start one only when you have a recipe; this list is not a
                    dashboard.
                  </EmptyState>
                ) : (
                  <SwarmTable runs={runs} selectedId={selectedId} onSelect={onSelect} />
                )
              }
            </QueryView>
          </div>
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
  const command = useSwarmCommand();
  const receipt = useActionReceipt('Swarm run updated');
  const [cleanupOpen, setCleanupOpen] = useState(false);
  const [cleanupPreview, setCleanupPreview] = useState<CommandEnvelope | null>(null);
  const run = detail.data?.run ?? summary;
  const { context } = useSessionContext();
  const offline = useLiveStatus().connection === 'offline';

  const act = (kind: 'approve' | 'reject' | 'stop') =>
    action.mutate(
      { id: runId, action: kind },
      {
        onSuccess: (result) => receipt.onSuccess({ message: result.message || result.status }),
        onError: receipt.onError,
      },
    );

  const actLifecycle = (sub: 'pause' | 'resume' | 'promote', body: SubBody<'swarms'>) =>
    command.mutate(
      { sub, body },
      {
        onSuccess: (result) => {
          if (result.ok) receipt.onSuccess({ message: result.message || `${sub} completed` });
          else receipt.onError(new Error(result.message || `${sub} failed`));
        },
        onError: receipt.onError,
      },
    );

  const canPause = ['running', 'awaiting_human', 'awaiting_plan_approval'].includes(run?.run_state ?? '');
  const canResume = ['paused', 'budget_exhausted', 'failed'].includes(run?.run_state ?? '');
  const promotionTarget = run?.recipe === 'pair' ? 'team' : run?.recipe === 'team' ? 'full' : null;

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
      <ButtonRow>
        {canPause ? (
          <Button
            size="sm"
            disabled={offline || command.isPending}
            busy={command.isPending}
            onClick={() =>
              actLifecycle('pause', {
                workspace: context.workspace || undefined,
                run_id: runId,
              })
            }
          >
            Pause run
          </Button>
        ) : null}
        {canResume ? (
          <Button
            size="sm"
            disabled={offline || command.isPending}
            busy={command.isPending}
            onClick={() =>
              actLifecycle('resume', {
                workspace: context.workspace || undefined,
                run_id: runId,
              })
            }
          >
            Resume run
          </Button>
        ) : null}
        {promotionTarget ? (
          <ConfirmAction
            label={`Promote to ${promotionTarget}`}
            title={`Promote this run to ${promotionTarget}?`}
            description={`This changes the run recipe from ${run?.recipe} to ${promotionTarget} and adds the approval gates required by that recipe. The run ID and existing artifacts stay in place.`}
            confirmLabel={`Promote to ${promotionTarget}`}
            triggerVariant="secondary"
            variant="primary"
            disabled={offline || command.isPending}
            busy={command.isPending}
            onConfirm={() =>
              actLifecycle('promote', {
                workspace: context.workspace || undefined,
                run_id: runId,
                to_recipe: promotionTarget,
              })
            }
          />
        ) : null}
        <Button
          size="sm"
          variant="secondary"
          disabled={offline || command.isPending}
          onClick={() => {
            setCleanupPreview(null);
            setCleanupOpen(true);
            command.mutate(
              {
                sub: 'cleanup',
                body: { workspace: context.workspace || undefined, run_id: runId, dry_run: true },
              },
              { onSuccess: setCleanupPreview, onError: receipt.onError },
            );
          }}
        >
          Preview cleanup
        </Button>
      </ButtonRow>
      <Dialog
        open={cleanupOpen}
        onClose={() => setCleanupOpen(false)}
        title="Clean up this swarm run"
        description="Review the backend preview before removing any Toolkit-owned worktrees. Branches are preserved. Cleanup refuses worktrees that contain uncommitted changes."
        footer={
          <>
            <Button variant="ghost" onClick={() => setCleanupOpen(false)}>
              Keep run
            </Button>
            <Button
              variant="danger"
              disabled={!cleanupPreview?.ok || offline || command.isPending}
              busy={command.isPending}
              onClick={() =>
                command.mutate(
                  { sub: 'cleanup', body: { workspace: context.workspace || undefined, run_id: runId } },
                  {
                    onSuccess: (result) => {
                      if (result.ok) {
                        receipt.onSuccess({ message: result.message || 'Cleanup completed' });
                        setCleanupOpen(false);
                      } else receipt.onError(new Error(result.message || 'Cleanup failed'));
                    },
                    onError: receipt.onError,
                  },
                )
              }
            >
              Remove previewed worktrees
            </Button>
          </>
        }
      >
        {command.isPending && !cleanupPreview ? <p role="status">Reading the cleanup preview…</p> : null}
        {cleanupPreview ? <Report text={cleanupPreview.message} label="Backend cleanup preview" /> : null}
        {command.error ? <ErrorState title="Cleanup could not continue" error={command.error} /> : null}
        {cleanupPreview && !cleanupPreview.ok ? (
          <ErrorState title="Cleanup preview failed" error={cleanupPreview.message} />
        ) : null}
      </Dialog>
      <QueryView query={detail} loading="Loading swarm run" errorTitle="Could not load this swarm run">
        {(data) => <SwarmRunBody data={data} />}
      </QueryView>
    </Panel>
  );
}

function SwarmRunBody({ data }: { data: SwarmRunResponse }) {
  const { run, budget } = data;
  const bindings = Object.entries(run.person_bindings ?? {});
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
          { label: 'Session adapter', value: run.backend || '—', mono: true },
          { label: 'Runner', value: data.runner || '—', mono: true },
          { label: 'Model', value: data.model || '—', mono: true },
          { label: 'Tokens', value: `${budget.total_tokens} / ${budget.max_total_tokens}` },
          { label: 'Cost', value: cost },
        ]}
      />
      {bindings.length > 0 ? (
        <SwarmSection
          title="People bound to roles"
          empty="No People are explicitly bound; recipe roles use automatic ephemeral sessions."
        >
          <Table>
            <thead>
              <tr>
                <th scope="col">Role</th>
                <th scope="col">Person ID</th>
              </tr>
            </thead>
            <tbody>
              {bindings.map(([role, id]) => (
                <tr key={role}>
                  <th scope="row">{role}</th>
                  <td>
                    <Mono>{id}</Mono>
                  </td>
                </tr>
              ))}
            </tbody>
          </Table>
        </SwarmSection>
      ) : null}
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
      <SwarmSection title="Artifacts" empty="No artifacts recorded for this run.">
        {data.artifacts.length > 0 ? (
          <Table>
            <thead>
              <tr>
                <th scope="col">Artifact</th>
                <th scope="col">Path</th>
                <th scope="col">Size</th>
              </tr>
            </thead>
            <tbody>
              {data.artifacts.map((artifact) => (
                <tr key={artifact.path}>
                  <th scope="row">{artifact.name}</th>
                  <td>
                    <Mono>{artifact.path}</Mono>
                  </td>
                  <td>{artifact.size.toLocaleString()} bytes</td>
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
  const { client } = useBackend();
  const { context } = useSessionContext();
  const providers = useProviders();
  const models = useModels();
  const catalog = useSwarmRecipes();
  const mutate = useSwarmCommand();
  const queryClient = useQueryClient();
  const receipt = useActionReceipt('Swarm start posted');
  const [recipe, setRecipe] = useState('pair');
  const [task, setTask] = useState('');
  const [runner, setRunner] = useState('');
  const [model, setModel] = useState('');
  const [backend, setBackend] = useState('auto');
  const [dryRun, setDryRun] = useState(false);
  const [launchSessions, setLaunchSessions] = useState(true);
  const [personBindings, setPersonBindings] = useState<Record<string, string>>({});
  const [previewTask, setPreviewTask] = useState('');
  useEffect(() => {
    const timer = window.setTimeout(() => setPreviewTask(task.trim()), 300);
    return () => window.clearTimeout(timer);
  }, [task]);
  const peopleQuery = useQuery({
    queryKey: ['people', context.workspace],
    queryFn: () => requireClient(client).people(context.workspace),
    enabled: open && Boolean(context.workspace) && client !== null,
  });
  const defaultsQuery = useQuery({
    queryKey: ['people', 'bindings', context.workspace],
    queryFn: () => requireClient(client).personBindings(context.workspace),
    enabled: open && Boolean(context.workspace) && client !== null,
  });
  const saveDefaults = useMutation({
    mutationFn: (roles: Record<string, string>) =>
      requireClient(client).savePersonBindings(context.workspace, recipe, roles),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['people', 'bindings', context.workspace] });
      receipt.onSuccess({ message: 'Workspace swarm People defaults saved' });
    },
  });

  const selectedRecipe = catalog.data?.recipes.find((item) => item.name === recipe);
  const workspaceName =
    context.workspace
      .replace(/[\\/]+$/, '')
      .split(/[\\/]/)
      .at(-1) || context.workspace;
  const availableProviders = providers.data?.providers.filter((provider) => provider.available) ?? [];
  const runnerModels = (models.data?.models ?? []).filter((item) => !runner || item.runner === runner);
  const modelProfiles = [...new Map(runnerModels.map((item) => [item.profile, item])).values()];
  const availableBackends = catalog.data?.backends.filter((item) => item.available) ?? [];
  const hasProcessBackend =
    catalog.data?.backends.some((item) => ['herdr', 'tmux'].includes(item.name) && item.available) ?? false;
  const willLaunchSessions = launchSessions && backend !== 'headless' && hasProcessBackend;
  const people = (peopleQuery.data?.people ?? []).filter((person) => !person.archived);
  const activePersonBindings = useMemo(
    () =>
      (selectedRecipe?.roles ?? []).reduce<Record<string, string>>((bindings, role) => {
        const personId = personBindings[role.name];
        if (personId) bindings[role.name] = personId;
        return bindings;
      }, {}),
    [personBindings, selectedRecipe],
  );
  const boundPeople = Object.values(activePersonBindings);

  const body = useMemo(() => {
    const payload: SubBody<'swarms'> = {
      workspace: context.workspace || undefined,
      recipe,
      task: task.trim() || undefined,
      runner: runner || undefined,
      backend,
      model_profile: model || undefined,
      person_bindings: activePersonBindings,
      launch_sessions: willLaunchSessions,
      dry_run: dryRun || undefined,
    };
    return compactBody(payload);
  }, [activePersonBindings, backend, context.workspace, dryRun, model, recipe, runner, task, willLaunchSessions]);
  const previewBody = useMemo(
    () => compactBody({ ...body, task: previewTask, launch_sessions: false, dry_run: true }),
    [body, previewTask],
  );
  const startPreview = useQuery({
    queryKey: ['swarms', 'start-preview', previewBody],
    queryFn: async () => requireOk(await requireClient(client).sub('swarms', 'start', previewBody)),
    enabled: open && Boolean(context.workspace) && Boolean(previewTask) && Boolean(selectedRecipe) && client !== null,
    retry: false,
    staleTime: 500,
  });
  const resolvedPeople = useMemo<Record<string, string>>(() => {
    const raw = startPreview.data?.data['person_bindings'];
    if (!raw) return {};
    try {
      const parsed: unknown = JSON.parse(raw);
      if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) return {};
      return Object.fromEntries(
        Object.entries(parsed).filter((entry): entry is [string, string] => typeof entry[1] === 'string'),
      );
    } catch {
      return {};
    }
  }, [startPreview.data]);

  const close = () => {
    setRecipe('pair');
    setTask('');
    setRunner('');
    setModel('');
    setBackend('auto');
    setDryRun(false);
    setLaunchSessions(true);
    setPersonBindings({});
    onClose();
  };

  const submit = () => {
    if (!context.workspace || !task.trim() || !selectedRecipe || catalog.isLoading || mutate.isPending) return;
    mutate.mutate(
      { sub: 'start', body },
      {
        onSuccess: (envelope) => {
          receipt.onSuccess({ message: envelope.message || 'swarms start' });
          close();
        },
      },
    );
  };

  return (
    <Dialog
      open={open}
      onClose={close}
      title="Start a swarm"
      description="Choose a canonical recipe, review its role topology and People, then start real role sessions in this workspace."
      footer={
        <>
          <Button variant="ghost" onClick={close}>
            Cancel
          </Button>
          <Button
            variant="primary"
            onClick={submit}
            disabled={!context.workspace || !task.trim() || !selectedRecipe || catalog.isLoading}
            busy={mutate.isPending}
            busyLabel="Starting…"
          >
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
        <div className={styles.workspaceContext} title={context.workspace}>
          <span className={styles.previewLabel}>Current workspace</span>
          <strong>{workspaceName || 'No workspace selected'}</strong>
        </div>
        <Field label="Team recipe" hint="Roles and approval gates come from the canonical Toolkit recipe.">
          {(control) => (
            <Select value={recipe} onChange={(event) => setRecipe(event.target.value)} {...control}>
              {(catalog.data?.recipes ?? []).map((item) => (
                <option key={item.name} value={item.name}>
                  {item.name} · {item.roles.length} roles
                </option>
              ))}
            </Select>
          )}
        </Field>
        {selectedRecipe ? (
          <section className={styles.recipeCard} aria-label={`${selectedRecipe.name} recipe topology`}>
            <p className={styles.previewLabel}>{selectedRecipe.description}</p>
            <div className={styles.recipeRoles}>
              {selectedRecipe.roles.map((item) => {
                const assigned = personBindings[item.name] ?? '';
                const savedPreference = defaultsQuery.data?.roles.find((entry) => entry.role === item.name);
                const savedId = savedPreference?.person_id ?? '';
                const savedPerson = people.find((candidate) => candidate.id === savedId);
                const assignedPerson = people.find((candidate) => candidate.id === assigned);
                const fallbackNames = (savedPreference?.preferred_people ?? []).map(
                  (personId) => people.find((candidate) => candidate.id === personId)?.name ?? personId,
                );
                return (
                  <div className={styles.recipeRole} key={item.name}>
                    <strong>{item.name}</strong>
                    <span>{item.persona}</span>
                    <small>
                      {item.model_profile} · {item.policy}
                    </small>
                    <Field label={`Person for ${item.name}`}>
                      {(control) => (
                        <Select
                          value={assigned}
                          onChange={(event) =>
                            setPersonBindings((current) => {
                              const next = { ...current };
                              if (event.target.value) next[item.name] = event.target.value;
                              else delete next[item.name];
                              return next;
                            })
                          }
                          {...control}
                        >
                          <option value="">Auto · match role, else ephemeral</option>
                          {people.map((candidate) => (
                            <option
                              key={candidate.id}
                              value={candidate.id}
                              disabled={boundPeople.includes(candidate.id) && candidate.id !== assigned}
                            >
                              {candidate.name} · {candidate.role}
                            </option>
                          ))}
                        </Select>
                      )}
                    </Field>
                    <div className={styles.rolePreference}>
                      <span>
                        Workspace default: <strong>{savedPerson?.name ?? (savedId || 'automatic')}</strong>
                        {fallbackNames.length > 0 ? ` · then ${fallbackNames.join(', ')}` : ''}
                      </span>
                      {assigned && assigned !== savedId ? (
                        <button
                          type="button"
                          className={styles.preferenceAction}
                          disabled={saveDefaults.isPending}
                          onClick={() => saveDefaults.mutate({ [item.name]: assigned })}
                        >
                          Remember {assignedPerson?.name ?? assigned}
                        </button>
                      ) : null}
                      {savedId ? (
                        <button
                          type="button"
                          className={styles.preferenceAction}
                          disabled={saveDefaults.isPending}
                          onClick={() => saveDefaults.mutate({ [item.name]: '' })}
                        >
                          Clear pinned Person
                        </button>
                      ) : null}
                    </div>
                  </div>
                );
              })}
            </div>
            {peopleQuery.isPending ? <p>Loading People…</p> : null}
            {peopleQuery.isError ? <ErrorState title="Could not load People" error={peopleQuery.error} /> : null}
            {defaultsQuery.isError ? (
              <ErrorState title="Could not load workspace People defaults" error={defaultsQuery.error} />
            ) : null}
            {saveDefaults.error ? (
              <ErrorState title="Could not save this role default" error={saveDefaults.error} />
            ) : null}
            {people.length === 0 && peopleQuery.isSuccess ? (
              <p>
                No active People are configured. Auto keeps every recipe role available with ephemeral role sessions.
              </p>
            ) : null}
            {Object.keys(activePersonBindings).length > 0 ? (
              <p className={styles.bindingNote}>
                Explicit choices win. Auto assigns a unique active Person with a matching saved role or Agent
                Definition, then falls back to an ephemeral role. Runner and model remain swarm-wide settings.
              </p>
            ) : null}
            <div className={styles.recipeSummary}>
              <span>
                Workspace <strong>{selectedRecipe.workspace_strategy}</strong>
              </span>
              <span>
                Concurrency <strong>{selectedRecipe.max_concurrency}</strong>
              </span>
              <span>
                Token ceiling <strong>{selectedRecipe.budget.max_total_tokens.toLocaleString()}</strong>
              </span>
              <span>
                Cost ceiling <strong>${selectedRecipe.budget.max_cost_usd.toFixed(2)}</strong>
              </span>
              <span>
                Time ceiling <strong>{Math.round(selectedRecipe.max_wall_seconds / 60)} min</strong>
              </span>
              <span>
                Plan gate <strong>{selectedRecipe.require_plan_approval ? 'Required' : 'Off'}</strong>
              </span>
              <span>
                Final gate <strong>{selectedRecipe.require_final_approval ? 'Required' : 'Off'}</strong>
              </span>
            </div>
            <div className={styles.recipePolicy} role="group" aria-label="Recipe write permissions">
              <span>
                Direct base merge: <strong>{selectedRecipe.allow_direct_base_merge ? 'Allowed' : 'Not allowed'}</strong>
              </span>
              <span>
                Push: <strong>{selectedRecipe.allow_push ? 'Allowed' : 'Not allowed'}</strong>
              </span>
              <span>
                Failure worktree: <strong>{selectedRecipe.keep_on_failure ? 'Kept for recovery' : 'Removed'}</strong>
              </span>
            </div>
          </section>
        ) : catalog.isError ? (
          <ErrorState title="Recipe catalog unavailable" error={catalog.error} />
        ) : (
          <EmptyState title="Loading canonical swarm recipes…" />
        )}
        <Field label="Task" hint="Describe the outcome the team should deliver.">
          {(control) => <TextInput value={task} onChange={(event) => setTask(event.target.value)} {...control} />}
        </Field>
        <details className={styles.runtimeOptions}>
          <summary>
            Runtime options{' '}
            <span>
              {runner || 'Automatic runner'} · {backend} adapter
            </span>
          </summary>
          <div className={styles.runtimeFields}>
            <FormRow>
              <Field label="Runner" hint="Coding-agent runtime.">
                {(control) => (
                  <Select
                    value={runner}
                    onChange={(event) => {
                      setRunner(event.target.value);
                      setModel('');
                    }}
                    {...control}
                  >
                    <option value="">Automatic runner</option>
                    {availableProviders.map((provider) => (
                      <option key={provider.id} value={provider.id}>
                        {provider.id}
                        {provider.version ? ` · ${provider.version}` : ''}
                      </option>
                    ))}
                  </Select>
                )}
              </Field>
              <Field
                label="Model profile"
                hint={runner ? `Profiles supported by ${runner}.` : 'Use recipe defaults or choose a shared profile.'}
              >
                {(control) => (
                  <Select value={model} onChange={(event) => setModel(event.target.value)} {...control}>
                    <option value="">Recipe defaults</option>
                    {modelProfiles.map((item) => (
                      <option key={item.profile} value={item.profile}>
                        {item.profile} · {item.model}
                      </option>
                    ))}
                  </Select>
                )}
              </Field>
            </FormRow>
            <Field label="Session adapter" hint="Where role sessions run; this is not the LLM runner.">
              {(control) => (
                <Select
                  value={backend}
                  onChange={(event) => {
                    setBackend(event.target.value);
                    if (event.target.value === 'headless') setLaunchSessions(false);
                  }}
                  {...control}
                >
                  {availableBackends.map((item) => (
                    <option key={item.name} value={item.name}>
                      {item.name}
                      {item.detail ? ` · ${item.detail}` : ''}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
            <label className={styles.check}>
              <input
                type="checkbox"
                checked={willLaunchSessions}
                disabled={backend === 'headless' || !hasProcessBackend}
                onChange={(event) => setLaunchSessions(event.target.checked)}
              />
              Launch real role sessions
            </label>
            {!hasProcessBackend || backend === 'headless' ? (
              <p className={styles.bindingNote}>
                {backend === 'headless'
                  ? 'Headless records the run without launching agents. Choose Herdr or tmux to start real role sessions.'
                  : 'No Herdr or tmux session adapter is available. This run can be recorded headlessly, but no role processes will start.'}
              </p>
            ) : null}

            <label className={styles.check}>
              <input type="checkbox" checked={dryRun} onChange={(event) => setDryRun(event.target.checked)} />
              Dry run · validate without creating a run
            </label>
          </div>
        </details>
        <div>
          <p className={styles.previewLabel}>Start review</p>
          <p>
            {recipe} swarm{task.trim() ? ` · ${task.trim()}` : ' · Add a task to continue'}
          </p>
          <p className={styles.previewLabel}>Runtime selection</p>
          <p>
            {runner || 'Automatic runner'} · {backend}
          </p>
          <p>
            {willLaunchSessions
              ? 'Real role processes will start in the selected session adapter.'
              : 'No role processes will start; only the run record will be created.'}
          </p>
          <section aria-label="Resolved swarm People">
            <p className={styles.previewLabel}>People per role</p>
            {!previewTask ? <p>Add a task to preview compatible People and ephemeral fallbacks.</p> : null}
            {startPreview.isFetching ? <p role="status">Resolving role assignments…</p> : null}
            {startPreview.isError ? (
              <ErrorState title="Could not preview role assignments" error={startPreview.error} />
            ) : null}
            {startPreview.data ? (
              <div className={styles.recipeSummary}>
                {(selectedRecipe?.roles ?? []).map((role) => {
                  const personId = resolvedPeople[role.name];
                  const person = people.find((item) => item.id === personId);
                  const explicit = activePersonBindings[role.name] === personId;
                  const preference = defaultsQuery.data?.roles.find((item) => item.role === role.name);
                  const workspaceDefault =
                    personId !== undefined &&
                    (preference?.person_id === personId || preference?.preferred_people.includes(personId) === true);
                  return (
                    <span key={role.name}>
                      {role.name} → <strong>{person?.name ?? (personId ? personId : 'Ephemeral role session')}</strong>
                      {person
                        ? ` · ${explicit ? 'selected' : workspaceDefault ? 'workspace default' : 'matched role'}`
                        : ''}
                    </span>
                  );
                })}
              </div>
            ) : null}
          </section>
          {dryRun ? <StatusBadge tone="warn" label="Dry run · no run will be created" /> : null}
        </div>
        {mutate.error ? <ErrorState title="The swarm did not start" error={mutate.error} /> : null}
        <button type="submit" hidden />
      </form>
    </Dialog>
  );
}
