import { useEffect, useMemo, useRef, useState, type ChangeEvent, type FormEvent } from 'react';
import { useNavigate, useSearchParams } from 'react-router';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useAgents, useModels, useProviders } from '../../data/catalog';
import { requireClient, useBackend } from '../../data/backend';
import { errorMessage, envelopeText, type Person } from '../../lib/api';
import { useSubQuery } from '../../data/commands';
import { useTerminalSessions } from '../../data/terminal';
import { useSessionContext } from '../../shell/useSessionContext';
import {
  Button,
  ButtonRow,
  ConfirmAction,
  Dialog,
  EmptyState,
  ErrorState,
  Field,
  PageHeader,
  Panel,
  QueryView,
  Select,
  Stack,
  StatusBadge,
  TextInput,
} from '../../ui';
import styles from './people.module.css';
import { reviewMunderHire, type MunderReview } from './importMunder';
import { parseProjectListMessage } from '../world/model';
import { personSessionOptions } from './personRunner';
import { personCharacter } from './avatar';

const blank: Person = {
  spec: 'agent-toolkit/person@1',
  id: '',
  name: '',
  role: '',
  goal: '',
  archived: false,
};

function commaList(value: string): string[] {
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function optionalText(value: string): string | undefined {
  return value.trim() || undefined;
}

function PersonForm({
  initial,
  existing,
  onSave,
  onCancel,
  busy,
  error,
}: {
  initial: Person;
  existing: boolean;
  onSave: (person: Person) => void;
  onCancel: () => void;
  busy: boolean;
  error: unknown;
}) {
  const [draft, setDraft] = useState<Person>(initial);
  const agents = useAgents();
  const providers = useProviders();
  const editing = existing;
  const update = (patch: Partial<Person>) => setDraft((current) => ({ ...current, ...patch }));
  const submit = (event: FormEvent) => {
    event.preventDefault();
    onSave(draft);
  };

  return (
    <form className={styles.form} onSubmit={submit}>
      <div className={styles.formGrid}>
        <Field label="Name">
          {(control) => (
            <TextInput
              {...control}
              required
              maxLength={128}
              value={draft.name}
              onChange={(event) => update({ name: event.target.value })}
            />
          )}
        </Field>
        <Field
          label="ID"
          hint={editing ? 'Identity stays stable after creation.' : 'Lowercase letters, numbers, hyphen or underscore.'}
        >
          {(control) => (
            <TextInput
              {...control}
              mono
              required
              maxLength={64}
              readOnly={editing}
              pattern="[a-z0-9][a-z0-9_-]*"
              value={draft.id}
              onChange={(event) => update({ id: event.target.value })}
            />
          )}
        </Field>
        <Field label="Role" hint="A durable description such as reviewer or architect.">
          {(control) => (
            <TextInput
              {...control}
              required
              maxLength={64}
              pattern="[a-z0-9][a-z0-9_-]*"
              value={draft.role}
              onChange={(event) => update({ role: event.target.value })}
            />
          )}
        </Field>
        <Field label="Agent definition" hint="Reusable toolkit template; this Person remains a separate identity.">
          {(control) => (
            <Select
              {...control}
              value={draft.definition_id ?? ''}
              onChange={(event) => update({ definition_id: optionalText(event.target.value) })}
            >
              <option value="">Choose later</option>
              {agents.data?.agents.map((agent) => (
                <option key={agent.id} value={agent.id}>
                  {agent.name}
                </option>
              ))}
            </Select>
          )}
        </Field>
      </div>
      <Field label="Goal" hint="What this collaborator is configured to help with.">
        {(control) => (
          <textarea
            {...control}
            className={styles.textarea}
            required
            maxLength={2048}
            rows={3}
            value={draft.goal}
            onChange={(event) => update({ goal: event.target.value })}
          />
        )}
      </Field>
      <details className={styles.details}>
        <summary>Runner and appearance</summary>
        <div className={styles.formGrid}>
          <Field label="Preferred runner">
            {(control) => (
              <Select
                {...control}
                value={draft.preferred_provider ?? ''}
                onChange={(event) => update({ preferred_provider: optionalText(event.target.value) })}
              >
                <option value="">Choose when starting</option>
                {providers.data?.providers.map((provider) => (
                  <option key={provider.id} value={provider.id}>
                    {provider.id}
                    {provider.available ? '' : ' · unavailable'}
                  </option>
                ))}
              </Select>
            )}
          </Field>
          <Field label="Preferred model">
            {(control) => (
              <TextInput
                {...control}
                value={draft.preferred_model ?? ''}
                onChange={(event) => update({ preferred_model: optionalText(event.target.value) })}
                placeholder="Model ID"
              />
            )}
          </Field>
          <Field label="Character" hint="Appearance is saved even while this Person is offline.">
            {(control) => (
              <Select
                {...control}
                value={draft.avatar?.character ?? ''}
                onChange={(event) =>
                  update({ avatar: { ...draft.avatar, character: optionalText(event.target.value) } })
                }
              >
                <option value="">Default</option>
                <option value="scout">Scout</option>
                <option value="maker">Maker</option>
                <option value="scholar">Scholar</option>
                <option value="keeper">Keeper</option>
              </Select>
            )}
          </Field>
          <Field label="Accent color">
            {(control) => (
              <TextInput
                {...control}
                type="color"
                value={draft.avatar?.accent ?? '#56a6a0'}
                onChange={(event) => update({ avatar: { ...draft.avatar, accent: event.target.value } })}
              />
            )}
          </Field>
        </div>
      </details>
      <details className={styles.details}>
        <summary>Capabilities and limits</summary>
        <div className={styles.formGrid}>
          {(['capabilities', 'skills', 'mcp_servers'] as const).map((field) => (
            <Field
              key={field}
              label={field === 'mcp_servers' ? 'MCP servers' : field[0]!.toUpperCase() + field.slice(1)}
              hint="Comma-separated references; no installation happens here."
            >
              {(control) => (
                <TextInput
                  {...control}
                  value={draft[field]?.join(', ') ?? ''}
                  onChange={(event) => update({ [field]: commaList(event.target.value) })}
                />
              )}
            </Field>
          ))}
          <Field label="Isolation">
            {(control) => (
              <Select
                {...control}
                value={draft.isolation ?? 'inherited'}
                onChange={(event) => update({ isolation: event.target.value as Person['isolation'] })}
              >
                <option value="inherited">Inherited</option>
                <option value="worktree">Worktree</option>
                <option value="session">Session</option>
              </Select>
            )}
          </Field>
          <Field label="Max tokens" hint="Empty inherits the workspace limit.">
            {(control) => (
              <TextInput
                {...control}
                type="number"
                min={0}
                max={1000000000}
                value={draft.budget?.max_tokens ?? ''}
                onChange={(event) =>
                  update({
                    budget: {
                      ...draft.budget,
                      max_tokens: event.target.value ? Number(event.target.value) : undefined,
                    },
                  })
                }
              />
            )}
          </Field>
          <Field label="Max cost (USD)">
            {(control) => (
              <TextInput
                {...control}
                type="number"
                min={0}
                max={1000000}
                step="0.01"
                value={draft.budget?.max_cost_usd ?? ''}
                onChange={(event) =>
                  update({
                    budget: {
                      ...draft.budget,
                      max_cost_usd: event.target.value ? Number(event.target.value) : undefined,
                    },
                  })
                }
              />
            )}
          </Field>
          <Field label="Max seconds">
            {(control) => (
              <TextInput
                {...control}
                type="number"
                min={0}
                max={31536000}
                value={draft.budget?.max_seconds ?? ''}
                onChange={(event) =>
                  update({
                    budget: {
                      ...draft.budget,
                      max_seconds: event.target.value ? Number(event.target.value) : undefined,
                    },
                  })
                }
              />
            )}
          </Field>
        </div>
      </details>
      {error ? (
        <p role="alert" className={styles.error}>
          {errorMessage(error)}. Review the highlighted fields and try again.
        </p>
      ) : null}
      <div className={styles.formActions}>
        <ButtonRow>
          <Button type="submit" variant="primary" busy={busy} busyLabel="Saving…">
            {editing ? 'Save changes' : 'Create Person'}
          </Button>
          <Button onClick={onCancel}>Cancel</Button>
        </ButtonRow>
      </div>
    </form>
  );
}

export default function People() {
  const { client } = useBackend();
  const { context, href } = useSessionContext();
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const terminals = useTerminalSessions();
  const workspace = context.workspace;
  const queryClient = useQueryClient();
  const [editing, setEditing] = useState<Person | null>(null);
  const [importDraft, setImportDraft] = useState<Person | null>(null);
  const [creating, setCreating] = useState(false);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [importReview, setImportReview] = useState<MunderReview | null>(null);
  const [importError, setImportError] = useState<string | null>(null);
  const [starting, setStarting] = useState<Person | null>(null);
  const [startProject, setStartProject] = useState('');
  const [startProvider, setStartProvider] = useState('');
  const [startModel, setStartModel] = useState('');
  const [stoppingSessionId, setStoppingSessionId] = useState<string | null>(null);
  const [sessionActionError, setSessionActionError] = useState<string | null>(null);
  const [startError, setStartError] = useState<string | null>(null);
  const [startBusy, setStartBusy] = useState(false);
  const projectsQuery = useSubQuery('project', 'list');
  const providersQuery = useProviders();
  const modelsQuery = useModels();
  const importInput = useRef<HTMLInputElement>(null);
  const chooseImport = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;
    try {
      if (file.size > 65536) throw new Error('Import file is too large');
      setImportReview(reviewMunderHire(await file.text()));
      setImportError(null);
      save.reset();
    } catch (error) {
      setImportReview(null);
      setImportError(errorMessage(error));
    }
  };
  const list = useQuery({
    queryKey: ['people', workspace],
    queryFn: () => requireClient(client).people(workspace),
    enabled: client !== null && Boolean(workspace),
  });
  const save = useMutation({
    mutationFn: (person: Person) =>
      editing
        ? requireClient(client).updatePerson(workspace, person)
        : requireClient(client).createPerson(workspace, person),
    onSuccess: (response) => {
      void queryClient.invalidateQueries({ queryKey: ['people', workspace] });
      setSelectedId(response.person.id);
      setCreating(false);
      setEditing(null);
      setImportDraft(null);
      setImportReview(null);
    },
  });
  const archive = useMutation({
    mutationFn: (person: Person) =>
      person.archived
        ? requireClient(client).updatePerson(workspace, { ...person, archived: false })
        : requireClient(client).archivePerson(workspace, person.id),
    onSuccess: () => void queryClient.invalidateQueries({ queryKey: ['people', workspace] }),
  });
  const people = list.data?.people ?? [];
  const selected = people.find((person) => person.id === selectedId) ?? people[0];
  const projects = useMemo(
    () =>
      projectsQuery.isSuccess && projectsQuery.data ? parseProjectListMessage(envelopeText(projectsQuery.data)) : [],
    [projectsQuery.data, projectsQuery.isSuccess],
  );
  const selectedSession = selected
    ? terminals.sessions.find((session) => session.personId === selected.id && session.exitCode === null)
    : undefined;
  const selectedRecentSession = selected
    ? terminals.sessions
        .filter((session) => session.personId === selected.id)
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt))[0]
    : undefined;
  const displaySession = selectedSession ?? selectedRecentSession;
  const activePersonIds = useMemo(
    () =>
      new Set(
        terminals.sessions.flatMap((session) =>
          session.personId && session.exitCode === null ? [session.personId] : [],
        ),
      ),
    [terminals.sessions],
  );
  const providers = useMemo(() => providersQuery.data?.providers ?? [], [providersQuery.data]);
  const models = useMemo(() => modelsQuery.data?.models ?? [], [modelsQuery.data]);
  const matchingModels = models.filter((model) => model.runner === startProvider);
  const chosenProvider = providers.find((provider) => provider.id === startProvider);
  const chosenModel = matchingModels.find((model) => model.model === startModel);
  const chosenProject = projects.find((project) => project.name === startProject);
  const formOpen = creating || editing !== null || importDraft !== null;

  useEffect(() => {
    const personId = params.get('person');
    if (personId) setSelectedId(personId);
  }, [params]);

  useEffect(() => {
    if (params.get('start') !== '1' || !list.isSuccess) return;
    const personId = params.get('person');
    const person = list.data?.people.find((candidate) => candidate.id === personId);
    if (person && !person.archived) setStarting(person);
    const next = new URLSearchParams(params);
    next.delete('start');
    setParams(next, { replace: true });
  }, [list.data, list.isSuccess, params, setParams]);

  useEffect(() => {
    if (!starting) return;
    setStartProject('');
    setStartProvider(starting.preferred_provider || '');
    setStartModel(starting.preferred_model || '');
    setStartError(null);
  }, [starting]);

  useEffect(() => {
    if (!starting) return;
    setStartProject((current) => current || projects.find((project) => project.status === 'ok')?.name || '');
    setStartProvider(
      (current) => current || providers.find((provider) => provider.available && provider.id !== 'skeleton')?.id || '',
    );
  }, [starting, projects, providers]);

  const beginPerson = async () => {
    if (!starting || !chosenProvider || !chosenProject || startBusy) return;
    setStartError(null);
    const options = personSessionOptions(
      starting,
      chosenProvider,
      chosenModel,
      chosenProject.target,
      chosenProject.name,
    );
    if (!options) {
      setStartError(
        'This runner is not available for a local PTY session. Choose an installed runner and a valid project.',
      );
      return;
    }
    setStartBusy(true);
    try {
      const session = await terminals.create(options);
      if (!session)
        throw new Error(
          'The session was not created. Recheck the project folder and confirm Desktop is still connected.',
        );
      setStarting(null);
      navigate(href('/terminal', { pty: session.id }));
    } catch (error) {
      setStartError(errorMessage(error));
    } finally {
      setStartBusy(false);
    }
  };

  return (
    <>
      <PageHeader
        eyebrow="Roster"
        title="People"
        lede="Durable collaborators in this workspace. Configuration alone never starts a process or places a character in the world."
        actions={
          <ButtonRow>
            <input
              ref={importInput}
              className={styles.fileInput}
              type="file"
              accept="application/json,.json"
              aria-label="Choose Munder hire JSON"
              onChange={(event) => void chooseImport(event)}
            />
            <Button disabled={!workspace} onClick={() => importInput.current?.click()}>
              Import from Munder
            </Button>
            <Button
              variant="primary"
              disabled={!workspace}
              onClick={() => {
                save.reset();
                setCreating(true);
              }}
            >
              Create Person
            </Button>
          </ButtonRow>
        }
      />
      {!workspace ? (
        <EmptyState title="Choose a workspace first.">
          People belong to a workspace. Select one in Workspace, then return here.
        </EmptyState>
      ) : (
        <Stack>
          {importError ? <ErrorState title="Could not review import" error={new Error(importError)} /> : null}
          <div className={styles.layout}>
            <Panel title="Roster" meta={list.isSuccess ? `${people.length} configured` : undefined}>
              <QueryView query={list} loading="Loading People" errorTitle="Could not load People">
                {() =>
                  people.length === 0 ? (
                    <EmptyState title="No People yet.">
                      Create a reusable collaborator. Offline People do not appear as workers in the world.
                    </EmptyState>
                  ) : (
                    <div className={styles.roster}>
                      {people.map((person) => (
                        <button
                          key={person.id}
                          className={styles.personCard}
                          data-selected={person.id === selected?.id}
                          onClick={() => setSelectedId(person.id)}
                        >
                          <span
                            className={styles.avatar}
                            style={
                              {
                                '--person-accent': person.avatar?.accent ?? '#56a6a0',
                                '--person-sprite': `url(/world/char-${personCharacter(person)}.png)`,
                              } as React.CSSProperties
                            }
                            aria-hidden="true"
                          />
                          <span className={styles.cardText}>
                            <strong>{person.name}</strong>
                            <small>{person.role}</small>
                          </span>
                          <StatusBadge
                            tone={activePersonIds.has(person.id) ? 'ok' : person.archived ? 'idle' : 'info'}
                            label={
                              activePersonIds.has(person.id)
                                ? person.archived
                                  ? 'Archived · session open'
                                  : 'Session open'
                                : person.archived
                                  ? 'Archived'
                                  : 'Offline'
                            }
                          />
                        </button>
                      ))}
                    </div>
                  )
                }
              </QueryView>
            </Panel>
            {selected ? (
              <Panel
                title={selected.name}
                meta={selected.role}
                actions={
                  <StatusBadge
                    tone={selectedSession ? 'ok' : selected.archived ? 'idle' : 'info'}
                    label={
                      selectedSession
                        ? selected.archived
                          ? 'Archived · session open'
                          : 'Session open'
                        : selected.archived
                          ? 'Archived'
                          : 'Configured · offline'
                    }
                  />
                }
              >
                <div className={styles.profile}>
                  <p>{selected.goal}</p>
                  {selectedSession ? (
                    <p role="status">
                      {stoppingSessionId === selectedSession.id ? 'Stop requested. ' : ''}A real PTY session is
                      {stoppingSessionId === selectedSession.id ? ' still running' : ' open'} in project{' '}
                      {selectedSession.projectId || 'unassigned'} at {selectedSession.cwd}. It will leave the world
                      after its process exits.
                    </p>
                  ) : selectedRecentSession ? (
                    <p role="status">Last local PTY exited with code {selectedRecentSession.exitCode ?? 'unknown'}.</p>
                  ) : null}
                  <dl>
                    <dt>Definition</dt>
                    <dd>{selected.definition_id || 'Choose when starting'}</dd>
                    <dt>Project</dt>
                    <dd>{displaySession?.projectId || 'Choose when starting'}</dd>
                    <dt>Runner</dt>
                    <dd>{displaySession?.provider || selected.preferred_provider || 'Choose when starting'}</dd>
                    <dt>Model</dt>
                    <dd>{displaySession?.model || selected.preferred_model || 'Runner default'}</dd>
                    <dt>Isolation</dt>
                    <dd>{selected.isolation || 'Inherited'}</dd>
                    <dt>Skills</dt>
                    <dd>{selected.skills?.join(', ') || 'None configured'}</dd>
                    <dt>MCP</dt>
                    <dd>{selected.mcp_servers?.join(', ') || 'None configured'}</dd>
                  </dl>
                  <ButtonRow>
                    {selectedSession ? (
                      <>
                        <Button
                          variant="primary"
                          onClick={() => navigate(href('/terminal', { pty: selectedSession.id }))}
                        >
                          Open session
                        </Button>
                        <ConfirmAction
                          label="Stop session"
                          title={`Stop ${selected.name}'s session?`}
                          description="Desktop sends a termination signal and keeps the real session visible until the process exits. The saved Person stays in the roster."
                          confirmLabel="Stop session"
                          disabled={stoppingSessionId === selectedSession.id}
                          onConfirm={() => {
                            setSessionActionError(null);
                            void terminals.stop(selectedSession.id).then((stopped) => {
                              if (stopped) setStoppingSessionId(selectedSession.id);
                              else
                                setSessionActionError(
                                  'Desktop could not signal this session. It may have already exited.',
                                );
                            });
                          }}
                        />
                      </>
                    ) : !selected.archived ? (
                      <Button
                        variant="primary"
                        disabled={!terminals.available || projectsQuery.isPending || providersQuery.isPending}
                        onClick={() => setStarting(selected)}
                      >
                        Start {selected.name}
                      </Button>
                    ) : null}
                    <Button
                      onClick={() => {
                        save.reset();
                        setEditing(selected);
                      }}
                    >
                      Edit Person
                    </Button>
                    <ConfirmAction
                      label={selected.archived ? 'Restore' : 'Archive'}
                      title={selected.archived ? `Restore ${selected.name}?` : `Archive ${selected.name}?`}
                      description={
                        selected.archived
                          ? 'This returns the Person to the active roster. It does not start a session.'
                          : selectedSession
                            ? 'The Person is archived but remains stored. This does not stop the active PTY; that real session remains visible until you stop it.'
                            : 'The Person remains stored and can be restored later. No session is started or stopped by archiving.'
                      }
                      confirmLabel={selected.archived ? 'Restore' : 'Archive'}
                      onConfirm={() => archive.mutate(selected)}
                      busy={archive.isPending}
                    />
                  </ButtonRow>
                  {sessionActionError ? <ErrorState title="Could not stop session" error={sessionActionError} /> : null}
                  {archive.error ? <ErrorState title="Could not change archive state" error={archive.error} /> : null}
                </div>
              </Panel>
            ) : null}
          </div>
        </Stack>
      )}
      <Dialog
        open={formOpen}
        onClose={() => {
          setCreating(false);
          setEditing(null);
          setImportDraft(null);
        }}
        title={editing ? `Edit ${editing.name}` : 'Create Person'}
        description="A Person is a saved collaborator. Saving this form does not start a process."
        size="wide"
      >
        <PersonForm
          key={editing?.id ?? importDraft?.id ?? 'new'}
          initial={editing ?? importDraft ?? blank}
          existing={editing !== null}
          onSave={(person) => save.mutate(person)}
          onCancel={() => {
            setCreating(false);
            setEditing(null);
            setImportDraft(null);
          }}
          busy={save.isPending}
          error={save.error}
        />
      </Dialog>
      <Dialog
        open={starting !== null}
        onClose={() => setStarting(null)}
        title={starting ? `Start ${starting.name}` : 'Start Person'}
        description="This opens the runner in a real local terminal. The goal is shown for reference but not sent automatically; this PTY does not enforce Person budgets or isolation."
        size="wide"
        footer={
          <ButtonRow>
            <Button onClick={() => setStarting(null)}>Cancel</Button>
            <Button
              variant="primary"
              busy={startBusy}
              busyLabel="Starting…"
              disabled={!chosenProject || !chosenProvider || startBusy}
              onClick={() => void beginPerson()}
            >
              Start and open terminal
            </Button>
          </ButtonRow>
        }
      >
        {starting ? (
          <div className={styles.form}>
            <div className={styles.formGrid}>
              <Field label="Project and working folder">
                {(control) => (
                  <Select {...control} value={startProject} onChange={(event) => setStartProject(event.target.value)}>
                    <option value="">Choose a project</option>
                    {projects
                      .filter((project) => project.status === 'ok')
                      .map((project) => (
                        <option key={project.name} value={project.name}>
                          {project.name} · {project.target}
                        </option>
                      ))}
                  </Select>
                )}
              </Field>
              <Field label="Runner">
                {(control) => (
                  <Select
                    {...control}
                    value={startProvider}
                    onChange={(event) => {
                      setStartProvider(event.target.value);
                      setStartModel('');
                    }}
                  >
                    <option value="">Choose an installed runner</option>
                    {providers.map((provider) => (
                      <option
                        key={provider.id}
                        value={provider.id}
                        disabled={!provider.available || provider.id === 'skeleton'}
                      >
                        {provider.id}
                        {provider.available ? '' : ' · unavailable'}
                      </option>
                    ))}
                  </Select>
                )}
              </Field>
              <Field label="Model" hint="Optional. Only models discovered for this runner are offered.">
                {(control) => (
                  <Select {...control} value={startModel} onChange={(event) => setStartModel(event.target.value)}>
                    <option value="">Runner default</option>
                    {startModel && !matchingModels.some((model) => model.model === startModel) ? (
                      <option value={startModel} disabled>
                        {startModel} · not discovered
                      </option>
                    ) : null}
                    {matchingModels.map((model) => (
                      <option key={`${model.profile}:${model.model}`} value={model.model}>
                        {model.profile} · {model.model}
                      </option>
                    ))}
                  </Select>
                )}
              </Field>
            </div>
            <Panel title="Start preview" meta={starting.role}>
              <p>
                <strong>Goal:</strong> {starting.goal}
              </p>
              <p>
                <strong>Command:</strong>{' '}
                <code>
                  {chosenProvider?.bin || 'Choose a runner'}
                  {chosenModel ? ` --model ${chosenModel.model}` : ''}
                </code>
              </p>
              {startModel && !chosenModel ? (
                <p role="status">
                  Preferred model “{startModel}” is not in this runner&apos;s discovered catalog; the runner default
                  will be used.
                </p>
              ) : null}
              <p>
                <strong>Working folder:</strong> <code>{chosenProject?.target || 'Choose a project'}</code>
              </p>
              <p>The runner opens interactively. Enter the task in its terminal to begin.</p>
            </Panel>
            {projectsQuery.isError ? <ErrorState title="Could not load projects" error={projectsQuery.error} /> : null}
            {providersQuery.isError ? (
              <ErrorState title="Could not discover runners" error={providersQuery.error} />
            ) : null}
            {providersQuery.isSuccess &&
            !providers.some((provider) => provider.available && provider.id !== 'skeleton') ? (
              <p role="status">
                No interactive runner is installed. Install or configure one from Library, then retry.
              </p>
            ) : null}
            {projectsQuery.isSuccess && !projects.some((project) => project.status === 'ok') ? (
              <p role="status">
                No healthy project is linked yet. Link an existing folder from World or Workspace before starting this
                Person.
              </p>
            ) : null}
            {startError ? (
              <p role="alert" className={styles.error}>
                {startError}
              </p>
            ) : null}
          </div>
        ) : null}
      </Dialog>
      <Dialog
        open={importReview !== null}
        onClose={() => setImportReview(null)}
        title="Review Munder import"
        description="Review the mapped identity before saving. Import never starts a session, installs code, or enables live sync."
        size="wide"
      >
        {importReview ? (
          <div className={styles.importReview}>
            <dl>
              <dt>Name</dt>
              <dd>{importReview.person.name}</dd>
              <dt>Toolkit ID</dt>
              <dd>{importReview.person.id}</dd>
              <dt>Role</dt>
              <dd>{importReview.person.role}</dd>
              <dt>Goal</dt>
              <dd>{importReview.person.goal}</dd>
              <dt>Provider</dt>
              <dd>{importReview.person.preferred_provider || 'Choose later'}</dd>
              <dt>Model</dt>
              <dd>{importReview.person.preferred_model || 'Choose later'}</dd>
              <dt>Capabilities</dt>
              <dd>{importReview.person.capabilities?.join(', ') || 'None'}</dd>
              <dt>Skills</dt>
              <dd>{importReview.person.skills?.join(', ') || 'None'}</dd>
              <dt>MCP references</dt>
              <dd>{importReview.person.mcp_servers?.join(', ') || 'None; never auto-enabled'}</dd>
              <dt>Budget</dt>
              <dd>{importReview.person.budget ? JSON.stringify(importReview.person.budget) : 'Inherited'}</dd>
              <dt>Isolation</dt>
              <dd>{importReview.person.isolation || 'Inherited'}</dd>
              <dt>Appearance</dt>
              <dd>Original Toolkit appearance; source character is attribution only</dd>
              <dt>Ignored fields</dt>
              <dd>{importReview.ignored.join(', ') || 'None'}</dd>
            </dl>
            {save.error ? <ErrorState title="Could not save imported Person" error={save.error} /> : null}
            <ButtonRow>
              <Button
                variant="primary"
                busy={save.isPending}
                busyLabel="Saving…"
                onClick={() => save.mutate(importReview.person)}
              >
                Save Person
              </Button>
              <Button
                onClick={() => {
                  setImportReview(null);
                  setImportDraft(importReview.person);
                }}
              >
                Edit before saving
              </Button>
              <Button onClick={() => setImportReview(null)}>Cancel</Button>
            </ButtonRow>
          </div>
        ) : null}
      </Dialog>
    </>
  );
}
