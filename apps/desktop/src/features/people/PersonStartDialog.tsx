import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router';
import { useBackend } from '../../data/backend';
import { useFocusBridge, useFocusProviders } from '../../data/focus';
import { useProjects } from '../../data/projects';
import type { Person, PersonSession } from '../../lib/api';
import { useSessionContext } from '../../shell/useSessionContext';
import type { FocusPermissionMode } from '../../types/focus';
import { Button, ButtonRow, Dialog, ErrorState, Field, Panel, Select } from '../../ui';
import { MODE_OPTIONS, providerBlocker } from '../focus/labels';
import { personInitialPrompt } from './personRunner';
import styles from './people.module.css';

export function PersonStartDialog({
  person,
  previousSession,
  onClose,
}: {
  person: Person | null;
  previousSession: PersonSession | null;
  onClose: () => void;
}) {
  const { backend } = useBackend();
  const { context, href } = useSessionContext();
  const navigate = useNavigate();
  const bridge = useFocusBridge();
  const workspace = context.workspace || backend?.harness?.path || '';
  const projectsQuery = useProjects(workspace);
  const providersQuery = useFocusProviders();
  const projects = useMemo(() => projectsQuery.data?.projects ?? [], [projectsQuery.data]);
  const providers = useMemo(() => providersQuery.data ?? [], [providersQuery.data]);
  const usableProviders = useMemo(
    () => providers.filter((provider) => providerBlocker(provider) === null),
    [providers],
  );
  const [projectName, setProjectName] = useState('');
  const [providerId, setProviderId] = useState('');
  const [modelId, setModelId] = useState('');
  const [permissionMode, setPermissionMode] = useState<FocusPermissionMode>('ask');
  const [task, setTask] = useState('');
  const [acknowledgeUnenforcedPolicy, setAcknowledgeUnenforcedPolicy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [savedThreadId, setSavedThreadId] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const project = projects.find((candidate) => candidate.name === projectName && candidate.status === 'ok');
  const provider = usableProviders.find((candidate) => candidate.id === providerId);
  const model = provider?.models.find((candidate) => candidate.id === modelId);
  const prompt = person && task.trim() ? personInitialPrompt(person, task) : null;
  const policyLimits = person
    ? [
        person.isolation && person.isolation !== 'inherited' ? `Isolation: ${person.isolation}` : null,
        person.budget?.max_seconds ? `runtime limit: ${person.budget.max_seconds}s` : null,
        person.budget?.max_tokens ? `token limit: ${person.budget.max_tokens.toLocaleString()}` : null,
        person.budget?.max_cost_usd ? `cost limit: $${person.budget.max_cost_usd.toFixed(2)}` : null,
      ].filter((reason): reason is string => reason !== null)
    : [];
  const acknowledgementReasons = [
    ...policyLimits,
    ...(permissionMode === 'bypass' ? ['the provider will run without approval prompts'] : []),
  ];
  const needsAcknowledgement = Boolean(provider && project && acknowledgementReasons.length > 0);

  useEffect(() => {
    if (!person) return;
    setProjectName(previousSession?.project_id || '');
    setProviderId(previousSession?.provider || person.preferred_provider || '');
    setModelId(previousSession?.model || person.preferred_model || '');
    setPermissionMode('ask');
    setTask(person.goal);
    setAcknowledgeUnenforcedPolicy(false);
    setError(null);
    setSavedThreadId(null);
  }, [person, previousSession]);

  useEffect(() => {
    if (!person || !projectsQuery.isSuccess || !providersQuery.isSuccess) return;
    setProjectName((current) =>
      projects.some((candidate) => candidate.name === current && candidate.status === 'ok')
        ? current
        : projects.find((candidate) => candidate.status === 'ok')?.name || '',
    );
    setProviderId((current) =>
      usableProviders.some((candidate) => candidate.id === current) ? current : usableProviders[0]?.id || '',
    );
  }, [person, projects, usableProviders, projectsQuery.isSuccess, providersQuery.isSuccess]);

  useEffect(() => {
    if (provider && modelId && !provider.models.some((candidate) => candidate.id === modelId)) setModelId('');
  }, [provider, modelId]);

  const begin = async () => {
    if (!person || !bridge || !provider || !project || !task.trim() || busy) return;
    if (needsAcknowledgement && !acknowledgeUnenforcedPolicy) return;
    setBusy(true);
    setError(null);
    try {
      let threadId = savedThreadId;
      if (!threadId) {
        const created = await bridge.createThread({
          cwd: project.target,
          projectName: project.name,
          personId: person.id,
          provider: provider.id,
          model: model?.id ?? null,
          permissionMode,
          title: `${person.name}: ${task.trim()}`.slice(0, 120),
        });
        if (!created.ok) throw new Error(created.error);
        threadId = created.value.id;
        setSavedThreadId(threadId);
      }
      const sent = await bridge.send(threadId, prompt ?? task.trim());
      if (!sent.ok) {
        setError(sent.error);
        return;
      }
      onClose();
      navigate(href('/focus', { thread: threadId }));
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not start the Focus session.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog
      open={person !== null}
      onClose={onClose}
      title={person ? `Start ${person.name} in Focus` : 'Start in Focus'}
      description={
        previousSession
          ? 'Starts a new Focus conversation with the previous project and provider prefilled. Older terminal history is preserved, but is not imported or resumed.'
          : 'Starts a real provider conversation in Focus. The saved Person stays unchanged; its role, goal and notes are included with this task.'
      }
      size="wide"
      footer={
        <div className={styles.startFooter}>
          {needsAcknowledgement ? (
            <label className={styles.policyAcknowledgement}>
              <input
                type="checkbox"
                checked={acknowledgeUnenforcedPolicy}
                onChange={(event) => setAcknowledgeUnenforcedPolicy(event.target.checked)}
              />
              <span>
                I understand this run does not enforce {acknowledgementReasons.join(', ')}. The provider can change
                files in the selected project folder.
              </span>
            </label>
          ) : null}
          <ButtonRow>
            <Button onClick={onClose}>Cancel</Button>
            <Button
              variant="primary"
              busy={busy}
              busyLabel="Starting…"
              disabled={
                !bridge ||
                !project ||
                !provider ||
                !task.trim() ||
                busy ||
                (needsAcknowledgement && !acknowledgeUnenforcedPolicy)
              }
              onClick={() => void begin()}
            >
              {savedThreadId ? 'Retry in Focus' : 'Start in Focus'}
            </Button>
          </ButtonRow>
        </div>
      }
    >
      {person ? (
        <div className={styles.form}>
          {previousSession ? (
            <p className={styles.recoveryNote} role="note">
              Previous terminal session: {previousSession.project_id} with {previousSession.provider}
              {previousSession.model ? ` · ${previousSession.model}` : ''}. Its history remains in People; this creates
              a separate Focus conversation.
            </p>
          ) : null}
          {savedThreadId ? (
            <p className={styles.recoveryNote} role="note">
              A Focus thread was saved as {savedThreadId}. Retry keeps its project, provider, model and permission
              settings; you can edit the task before retrying.
            </p>
          ) : null}
          {providersQuery.isError ? (
            <ErrorState title="Could not discover Focus providers" error={providersQuery.error} />
          ) : null}
          {providersQuery.isSuccess && usableProviders.length === 0 ? (
            <p role="status" className={styles.recoveryNote}>
              No installed and signed-in provider supports Focus sessions yet. Sign in to Claude Code, Codex, or
              OpenCode, then refresh providers in Focus.
            </p>
          ) : null}
          {projectsQuery.isError ? <ErrorState title="Could not load projects" error={projectsQuery.error} /> : null}
          {projectsQuery.isSuccess && !projects.some((candidate) => candidate.status === 'ok') ? (
            <p role="status" className={styles.recoveryNote}>
              No healthy project is linked. Link a folder from World or Workspace before starting this Person.
            </p>
          ) : null}
          <div className={styles.formGrid}>
            <Field label="Project and working folder">
              {(control) => (
                <Select
                  {...control}
                  value={projectName}
                  disabled={Boolean(savedThreadId)}
                  onChange={(event) => setProjectName(event.target.value)}
                >
                  <option value="">Choose a project</option>
                  {projects
                    .filter((candidate) => candidate.status === 'ok')
                    .map((candidate) => (
                      <option key={candidate.name} value={candidate.name}>
                        {candidate.name} · {candidate.target}
                      </option>
                    ))}
                </Select>
              )}
            </Field>
            <Field label="Provider">
              {(control) => (
                <Select
                  {...control}
                  value={providerId}
                  disabled={Boolean(savedThreadId)}
                  onChange={(event) => {
                    setProviderId(event.target.value);
                    setModelId('');
                  }}
                >
                  <option value="">Choose a ready provider</option>
                  {providers.map((candidate) => {
                    const blocker = providerBlocker(candidate);
                    return (
                      <option key={candidate.id} value={candidate.id} disabled={blocker !== null}>
                        {candidate.label}
                        {blocker ? ` · ${blocker}` : ''}
                      </option>
                    );
                  })}
                </Select>
              )}
            </Field>
            <Field label="Model" hint="Optional. Only models offered by this Focus provider are listed.">
              {(control) => (
                <Select
                  {...control}
                  value={modelId}
                  disabled={Boolean(savedThreadId)}
                  onChange={(event) => setModelId(event.target.value)}
                >
                  <option value="">Provider default</option>
                  {modelId && !provider?.models.some((candidate) => candidate.id === modelId) ? (
                    <option value={modelId} disabled>
                      {modelId} · not offered by this provider
                    </option>
                  ) : null}
                  {(provider?.models ?? []).map((candidate) => (
                    <option key={candidate.id} value={candidate.id}>
                      {candidate.label}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
            <Field label="Permission mode" hint={MODE_OPTIONS.find((option) => option.id === permissionMode)?.hint}>
              {(control) => (
                <Select
                  {...control}
                  value={permissionMode}
                  disabled={Boolean(savedThreadId)}
                  onChange={(event) => {
                    setPermissionMode(event.target.value as FocusPermissionMode);
                    setAcknowledgeUnenforcedPolicy(false);
                  }}
                >
                  {MODE_OPTIONS.map((option) => (
                    <option key={option.id} value={option.id}>
                      {option.label}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
          </div>
          <Field
            label="Task for this session"
            hint="Prefilled from this Person’s goal. Edit it for this run only; the saved Person stays unchanged."
          >
            {(control) => (
              <textarea
                {...control}
                className={styles.textarea}
                maxLength={4096}
                rows={4}
                value={task}
                onChange={(event) => setTask(event.target.value)}
              />
            )}
          </Field>
          <Panel title="Start preview" meta={person.role}>
            <p>
              <strong>Goal:</strong> {person.goal}
            </p>
            <p>
              <strong>Provider:</strong> {provider?.label || 'Choose a ready provider'}
              {model ? ` · ${model.label}` : ''}
            </p>
            <p>
              <strong>Permission:</strong> {MODE_OPTIONS.find((option) => option.id === permissionMode)?.label}
            </p>
            {prompt ? <pre className={styles.promptPreview}>{prompt}</pre> : null}
            <p>
              <strong>Session:</strong> A new Focus thread keeps conversation, tool events, approvals, terminal and Git
              changes together.
            </p>
            <p>
              <strong>Working folder:</strong> <code>{project?.target || 'Choose a project'}</code>
            </p>
            <p>
              <strong>Person preferences:</strong> Skills, MCP, capabilities and isolation remain saved metadata; Focus
              does not apply them automatically.
            </p>
            {person.budget ? (
              <p>
                <strong>Usage limits:</strong> Person token, cost and runtime limits are not enforced in Focus.
              </p>
            ) : null}
          </Panel>
          {error ? (
            <p role="alert" className={styles.error}>
              {error}
            </p>
          ) : null}
        </div>
      ) : null}
    </Dialog>
  );
}
