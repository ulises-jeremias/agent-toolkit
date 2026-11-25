import { useState, type ReactNode } from 'react';
import { useQuery } from '@tanstack/react-query';
import { useLiveStatus } from '../../data/live';
import {
  useCreateSwarmDraftPr,
  useMarkSwarmPrReady,
  useResolveSwarmHandoff,
  swarmRefreshInterval,
  useSwarmCommand,
  useSwarmPrStatus,
  useSwarmRun,
  useSwarmRunAction,
  useSwarms,
} from '../../data/swarms';
import {
  type CommandEnvelope,
  type Person,
  type SubBody,
  type SwarmRunInfo,
  type SwarmRunResponse,
} from '../../lib/api';
import { requireClient, useBackend } from '../../data/backend';
import { useSessionContext } from '../../shell/useSessionContext';
import { hopLabel, needsYouHandoffs, swarmPersonSessionsForRun } from './swarmPreview';
import {
  Button,
  ButtonRow,
  ConfirmAction,
  Dialog,
  EmptyState,
  ErrorState,
  KeyValue,
  Mono,
  Panel,
  QueryView,
  Report,
  StatusBadge,
  Table,
  jobTone,
  useActionReceipt,
} from '../../ui';
import styles from './operations.module.css';

export function SwarmsPanel({
  selectedId,
  onSelect,
}: {
  selectedId: string | null;
  onSelect: (id: string | null) => void;
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
                  <EmptyState title="No historical swarm runs on the backend.">
                    New coding-agent delegation is provided by Veasel Code. Existing Toolkit run records remain
                    available here for inspection and deliberate recovery actions.
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
          <th scope="col">Project</th>
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
              <Mono>{run.project_id || '—'}</Mono>
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
  const { client } = useBackend();
  const people = useQuery({
    queryKey: ['people', context.workspace],
    queryFn: () => requireClient(client).people(context.workspace),
    enabled: client !== null && Boolean(context.workspace),
    staleTime: 10_000,
  });
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
        {(data) => (
          <SwarmRunBody data={data} people={people.data?.people ?? []} workspace={context.workspace} client={client} />
        )}
      </QueryView>
    </Panel>
  );
}

type SwarmHandoff = SwarmRunResponse['handoffs'][number];

function NeedsYouSection({ runId, handoffs }: { runId: string; handoffs: SwarmHandoff[] }) {
  const resolve = useResolveSwarmHandoff();
  const waiting = needsYouHandoffs(handoffs);
  if (waiting.length === 0) return null;
  return (
    <SwarmSection title="Needs you" empty="Nothing is waiting on a human.">
      <p role="note">
        These handoffs passed their reply-chain budget and were routed to you instead of bouncing between agents
        (ADR-039). Resolving completes the handoff; hand the work on explicitly afterwards.
      </p>
      <Table>
        <thead>
          <tr>
            <th scope="col">From</th>
            <th scope="col">To</th>
            <th scope="col">Act</th>
            <th scope="col">Chain</th>
            <th scope="col">Action</th>
          </tr>
        </thead>
        <tbody>
          {waiting.map((handoff) => (
            <tr key={handoff.id}>
              <td>{handoff.from_role}</td>
              <td>{handoff.to_role}</td>
              <td>{handoff.act || '—'}</td>
              <td>{hopLabel(handoff)}</td>
              <td>
                <Button
                  size="sm"
                  disabled={resolve.isPending}
                  busy={resolve.isPending && resolve.variables?.handoffId === handoff.id}
                  onClick={() => resolve.mutate({ id: runId, handoffId: handoff.id })}
                >
                  Resolve
                </Button>
              </td>
            </tr>
          ))}
        </tbody>
      </Table>
      {resolve.isError ? <ErrorState title="Could not resolve the handoff" error={resolve.error} /> : null}
    </SwarmSection>
  );
}

function SwarmRunBody({
  data,
  people,
  workspace,
  client,
}: {
  data: SwarmRunResponse;
  people: Person[];
  workspace: string;
  client: ReturnType<typeof useBackend>['client'];
}) {
  const personSessions = useQuery({
    queryKey: ['person-sessions', workspace],
    queryFn: () => requireClient(client).personSessions(workspace),
    enabled: client !== null && Boolean(workspace),
    // Sessions appear and close while the run lives; a mount-once fetch can
    // otherwise keep claiming no role launched while one is running.
    refetchOnMount: 'always',
    refetchInterval: swarmRefreshInterval([data.run.run_state]),
    refetchIntervalInBackground: false,
  });
  const runPersonSessions = swarmPersonSessionsForRun(personSessions.data?.sessions ?? [], data.run.run_id);
  const { run, budget } = data;
  const draftPr = useCreateSwarmDraftPr();
  const prStatus = useSwarmPrStatus(run.run_id, Boolean(run.pr_url));
  const markPrReady = useMarkSwarmPrReady();
  const executionRoles = Object.keys(run.role_runners ?? {}).sort();
  const personBindings = run.person_bindings ?? {};
  const peopleById = new Map(people.map((person) => [person.id, person]));
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
          ...(run.issue_ref ? [{ label: 'Issue', value: run.issue_ref }] : []),
          ...(run.pr_url
            ? [
                {
                  label: 'Pull request',
                  value: (
                    <a href={run.pr_url} target="_blank" rel="noreferrer">
                      {run.pr_url}
                    </a>
                  ),
                },
                {
                  label: 'PR status',
                  value: prStatus.isPending
                    ? 'Checking GitHub…'
                    : prStatus.data?.ok
                      ? `${prStatus.data.state}${prStatus.data.is_draft ? ' (draft)' : ''} · checks ${prStatus.data.checks_pass} passed, ${prStatus.data.checks_fail} failed, ${prStatus.data.checks_pending} pending · mergeable ${prStatus.data.mergeable || 'unknown'} · review ${prStatus.data.review_decision || 'none'} · ${prStatus.data.changed_files} files +${prStatus.data.additions} −${prStatus.data.deletions}`
                      : `Unavailable: ${prStatus.data?.detail ?? prStatus.error?.message ?? 'unknown error'}`,
                },
              ]
            : []),
          { label: 'Session adapter', value: run.backend || '—', mono: true },
          { label: 'Runner', value: data.runner || '—', mono: true },
          { label: 'Model', value: data.model || '—', mono: true },
          { label: 'Tokens', value: `${budget.total_tokens} / ${budget.max_total_tokens}` },
          { label: 'Cost', value: cost },
        ]}
      />
      {run.pr_url && prStatus.data?.ok && prStatus.data.is_draft ? (
        <ButtonRow>
          <Button size="sm" disabled={markPrReady.isPending} onClick={() => markPrReady.mutate({ id: run.run_id })}>
            {markPrReady.isPending ? 'Marking ready…' : 'Mark PR ready for review'}
          </Button>
          {markPrReady.isError ? <span role="alert">{markPrReady.error.message}</span> : null}
          {markPrReady.data?.ok ? <span>{markPrReady.data.detail}</span> : null}
        </ButtonRow>
      ) : null}
      {!run.pr_url ? (
        <ButtonRow>
          <Button size="sm" disabled={draftPr.isPending} onClick={() => draftPr.mutate({ id: run.run_id })}>
            {draftPr.isPending ? 'Creating draft PR…' : 'Create draft PR'}
          </Button>
          {draftPr.isError ? <span role="alert">{draftPr.error.message}</span> : null}
          {draftPr.data?.pr_url ? (
            <a href={draftPr.data.pr_url} target="_blank" rel="noreferrer">
              View draft PR
            </a>
          ) : null}
        </ButtonRow>
      ) : null}
      {executionRoles.length > 0 ? (
        <SwarmSection
          title="Role execution"
          empty="No People are explicitly bound; recipe roles use automatic ephemeral sessions."
        >
          <Table>
            <thead>
              <tr>
                <th scope="col">Role</th>
                <th scope="col">Collaborator</th>
                <th scope="col">Runner and model</th>
              </tr>
            </thead>
            <tbody>
              {executionRoles.map((role) => {
                const id = personBindings[role] ?? '';
                return (
                  <SwarmPersonBindingRow
                    key={role}
                    role={role}
                    id={id}
                    person={peopleById.get(id)}
                    runner={run.role_runners?.[role]}
                    model={run.role_models?.[role]}
                  />
                );
              })}
            </tbody>
          </Table>
          <p role="note">
            Runner and model show the saved launch configuration. A Person binding alone does not create a live Person
            session or a World character: a canonical Person session appears below only when the runner for that role
            really launched, and it closes when the run stops.
          </p>
          {runPersonSessions.length > 0 ? (
            <Table>
              <thead>
                <tr>
                  <th scope="col">Person session</th>
                  <th scope="col">Role</th>
                  <th scope="col">Status</th>
                </tr>
              </thead>
              <tbody>
                {runPersonSessions.map((session) => (
                  <tr key={session.id}>
                    <td>
                      <strong>{session.person}</strong>
                      <div>{[session.provider, session.model].filter(Boolean).join(' · ')}</div>
                      <Mono>{session.id}</Mono>
                    </td>
                    <td>{session.swarm_role}</td>
                    <td>
                      <StatusBadge tone={jobTone(session.status)} label={session.status} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </Table>
          ) : (
            <p>No bound role has launched yet, so this run has no Person sessions.</p>
          )}
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
      <NeedsYouSection runId={run.run_id} handoffs={data.handoffs} />
      <SwarmSection title="Handoffs" empty="No handoffs reported.">
        {data.handoffs.length > 0 ? (
          <Table>
            <thead>
              <tr>
                <th scope="col">State</th>
                <th scope="col">From</th>
                <th scope="col">To</th>
                <th scope="col">Act</th>
                <th scope="col">Chain</th>
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
                  <td>{handoff.act || '—'}</td>
                  <td>{hopLabel(handoff)}</td>
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

function SwarmPersonBindingRow({
  role,
  id,
  person,
  runner,
  model,
}: {
  role: string;
  id: string;
  person: Person | undefined;
  runner?: string;
  model?: string;
}) {
  return (
    <tr>
      <th scope="row">{role}</th>
      <td>
        {person ? (
          <>
            <strong>{person.name}</strong>
            <div>{person.role}</div>
            <Mono>{id}</Mono>
            {person.archived ? <div>Archived after this run was configured</div> : null}
          </>
        ) : id ? (
          <Mono>{id} · no longer in this workspace roster</Mono>
        ) : (
          'Ephemeral role session'
        )}
      </td>
      <td>{[runner, model].filter(Boolean).join(' · ') || 'Runner/model unavailable'}</td>
    </tr>
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
