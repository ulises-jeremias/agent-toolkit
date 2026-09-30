import { useMemo, useState } from 'react';
import { useAgents, useModels, useProviders, useTools } from '../../data/catalog';
import { useReport } from '../../data/commands';
import { useLiveStatus } from '../../data/live';
import { useSwarmCommand } from '../../data/swarms';
import type { SubBody, SubCommand } from '../../lib/api';
import { useSessionContext } from '../../shell/useSessionContext';
import {
  Button,
  CommandReport,
  ConfirmAction,
  EmptyState,
  ErrorState,
  Field,
  FormRow,
  Panel,
  QueryView,
  Report,
  Select,
  TextInput,
  useActionReceipt,
} from '../../ui';
import styles from './operations.module.css';

const SWARM_SUBS: ReadonlyArray<{ value: SubCommand<'swarms'>; label: string; danger?: boolean }> = [
  { value: 'list', label: 'list' },
  { value: 'status', label: 'status' },
  { value: 'start', label: 'start' },
  { value: 'graph', label: 'graph' },
  { value: 'report', label: 'report' },
  { value: 'logs', label: 'logs' },
  { value: 'approvals', label: 'approvals' },
  { value: 'cancel', label: 'cancel', danger: true },
  { value: 'pause', label: 'pause' },
  { value: 'resume', label: 'resume' },
  { value: 'stop', label: 'stop', danger: true },
  { value: 'cleanup', label: 'cleanup', danger: true },
  { value: 'help', label: 'help' },
];

function compactBody(body: SubBody<'swarms'>): SubBody<'swarms'> {
  const next: Record<string, string | boolean | number> = {};
  for (const [key, value] of Object.entries(body)) {
    if (value === undefined || value === '' || value === false) continue;
    next[key] = value as string | boolean | number;
  }
  return next as SubBody<'swarms'>;
}

export function SwarmsPanel() {
  const swarms = useReport('swarms');
  const agents = useAgents();
  const tools = useTools();
  const providers = useProviders();
  const models = useModels();
  const { context } = useSessionContext();
  const { connection } = useLiveStatus();
  const mutate = useSwarmCommand();
  const receipt = useActionReceipt('Swarm command finished');
  const [sub, setSub] = useState<SubCommand<'swarms'>>('list');
  const [runId, setRunId] = useState(context.run);
  const [recipe, setRecipe] = useState('');
  const [task, setTask] = useState('');
  const [runner, setRunner] = useState('');
  const [model, setModel] = useState('');
  const [role, setRole] = useState(context.agent);
  const [dryRun, setDryRun] = useState(false);
  const [lastSub, setLastSub] = useState<SubCommand<'swarms'>>('start');

  const selected = SWARM_SUBS.find((item) => item.value === sub) ?? { value: sub, label: sub };
  const body = useMemo(() => {
    const payload: SubBody<'swarms'> = {
      workspace: context.workspace || undefined,
      run_id: runId.trim() || undefined,
      recipe: recipe.trim() || undefined,
      task: task.trim() || undefined,
      runner: runner || undefined,
      backend: runner || undefined,
      model_profile: model || undefined,
      role: role.trim() || undefined,
      dry_run: dryRun || undefined,
    };
    return compactBody(payload);
  }, [context.workspace, dryRun, model, recipe, role, runId, runner, task]);

  const preview = `POST /api/v1/swarms/${sub}\n${JSON.stringify(body, null, 2)}`;

  const run = (chosen: SubCommand<'swarms'>) => {
    setLastSub(chosen);
    mutate.mutate(
      { sub: chosen, body },
      {
        onSuccess: (envelope) => {
          receipt.onSuccess({ message: envelope.message || `swarms ${chosen}` });
        },
        onError: receipt.onError,
      },
    );
  };

  const offline = connection === 'offline';
  const verifiedTools = tools.data?.tools.filter((tool) => tool.verified) ?? [];
  const availableProviders = providers.data?.providers.filter((provider) => provider.available) ?? [];

  return (
    <Panel title="Swarms" meta="GET /api/v1/swarms · typed POST /api/v1/swarms/{sub}">
      <QueryView query={swarms} loading="Listing swarms" errorTitle="Could not list swarms">
        {(envelope) =>
          envelope.message.trim() === '' && Object.keys(envelope.data).length === 0 ? (
            <EmptyState title="No swarm runs reported.">The list endpoint returned an empty envelope.</EmptyState>
          ) : (
            <CommandReport envelope={envelope} label="Swarm list" />
          )
        }
      </QueryView>
      <form
        className={styles.form}
        onSubmit={(event) => {
          event.preventDefault();
          if (!selected.danger) run(sub);
        }}
      >
        <p className={styles.previewLabel}>Run a swarm subcommand</p>
        <FormRow>
          <Field label="Subcommand" hint="OpenAPI {sub} enum. The path names the command; the body never can.">
            {(control) => (
              <Select value={sub} onChange={(event) => setSub(event.target.value as SubCommand<'swarms'>)} {...control}>
                {SWARM_SUBS.map((item) => (
                  <option key={item.value} value={item.value}>
                    {item.label}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          <Field label="Run id" hint="Optional. Seeded from the session run.">
            {(control) => (
              <TextInput mono value={runId} onChange={(event) => setRunId(event.target.value)} {...control} />
            )}
          </Field>
        </FormRow>
        {sub === 'start' ? (
          <>
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
                    ? `${verifiedTools.length} verified coding tool${verifiedTools.length === 1 ? '' : 's'} on this machine.`
                    : 'From GET /api/v1/providers. enabled=unknown is not treated as false.'
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
          </>
        ) : null}
        <div>
          <p className={styles.previewLabel}>Will call</p>
          <Report text={preview} label="Swarm request preview" />
        </div>
        {selected.danger ? (
          <ConfirmAction
            label={`Run ${sub}`}
            title={`Run swarms ${sub}?`}
            description={`POST /api/v1/swarms/${sub} with the JSON body previewed above. This changes swarm state.`}
            confirmLabel={`Run ${sub}`}
            disabled={offline}
            busy={mutate.isPending && lastSub === sub}
            onConfirm={() => run(sub)}
          />
        ) : (
          <Button
            variant="primary"
            type="submit"
            disabled={offline}
            busy={mutate.isPending}
            busyLabel="Running…"
            title={offline ? 'The backend is not answering' : undefined}
          >
            Run {sub}
          </Button>
        )}
        {mutate.error ? <ErrorState title="The swarm command failed" error={mutate.error} /> : null}
      </form>
    </Panel>
  );
}
