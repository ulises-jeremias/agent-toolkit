import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router';
import { useQueryClient } from '@tanstack/react-query';
import { useModels, useProviders } from '../../data/catalog';
import { requireClient, useBackend } from '../../data/backend';
import { useProjects } from '../../data/projects';
import { errorMessage, type Person, type PersonSession } from '../../lib/api';
import { useTerminalSessions } from '../../data/terminal';
import { useSessionContext } from '../../shell/useSessionContext';
import { Button, ButtonRow, Dialog, ErrorState, Field, Panel, Select } from '../../ui';
import { initialPromptMode, personInitialPrompt, personSessionOptions } from './personRunner';
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
  const { backend, client } = useBackend();
  const { context, href } = useSessionContext();
  const navigate = useNavigate();
  const terminals = useTerminalSessions();
  const queryClient = useQueryClient();
  const workspace = context.workspace || backend?.harness?.path || '';
  const [projectName, setProjectName] = useState('');
  const [providerId, setProviderId] = useState('');
  const [modelName, setModelName] = useState('');
  const [task, setTask] = useState('');
  const [taskCopied, setTaskCopied] = useState(false);
  const [taskCopyError, setTaskCopyError] = useState<string | null>(null);
  const [acknowledgeUnenforcedPolicy, setAcknowledgeUnenforcedPolicy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const projectsQuery = useProjects(workspace);
  const providersQuery = useProviders();
  const modelsQuery = useModels();

  const projects = useMemo(() => projectsQuery.data?.projects ?? [], [projectsQuery.data]);
  const providers = useMemo(() => providersQuery.data?.providers ?? [], [providersQuery.data]);
  const models = useMemo(() => modelsQuery.data?.models ?? [], [modelsQuery.data]);
  const matchingModels = useMemo(() => models.filter((model) => model.runner === providerId), [models, providerId]);
  const chosenProvider = providers.find((provider) => provider.id === providerId);
  const hasInstalledRunner = providers.some((provider) => provider.available && provider.id !== 'skeleton');
  const chosenModel = matchingModels.find((model) => model.model === modelName);
  const chosenProject = projects.find((project) => project.name === projectName);
  const initialPrompt = person ? personInitialPrompt(person, task) : null;
  const canSendInitialPrompt = chosenProvider ? initialPromptMode(chosenProvider.id) !== 'unsupported' : false;
  const unenforcedPersonPolicy = person
    ? [
        person.isolation && person.isolation !== 'inherited' ? `Isolation: ${person.isolation}` : null,
        person.budget?.max_tokens ? `Token limit: ${person.budget.max_tokens.toLocaleString()}` : null,
        person.budget?.max_cost_usd ? `Cost limit: $${person.budget.max_cost_usd.toFixed(2)}` : null,
      ].filter((item): item is string => item !== null)
    : [];
  const needsPolicyAcknowledgement = Boolean(chosenProvider && chosenProject && unenforcedPersonPolicy.length > 0);

  useEffect(() => {
    if (!person) return;
    setProjectName(previousSession?.project_id || '');
    setProviderId(previousSession?.provider || person.preferred_provider || '');
    setModelName(previousSession?.model || person.preferred_model || '');
    setTask(person.goal);
    setTaskCopied(false);
    setTaskCopyError(null);
    setAcknowledgeUnenforcedPolicy(false);
    setError(null);
  }, [person, previousSession]);

  useEffect(() => {
    if (!person || !projectsQuery.isSuccess || !providersQuery.isSuccess) return;
    setProjectName((current) =>
      projects.some((project) => project.name === current && project.status === 'ok')
        ? current
        : projects.find((project) => project.status === 'ok')?.name || '',
    );
    setProviderId((current) =>
      providers.some((provider) => provider.id === current && provider.available && provider.id !== 'skeleton')
        ? current
        : providers.find((provider) => provider.available && provider.id !== 'skeleton')?.id || '',
    );
  }, [person, projects, providers, projectsQuery.isSuccess, providersQuery.isSuccess]);

  const previousProjectAvailable = Boolean(
    previousSession &&
    projects.some((project) => project.name === previousSession.project_id && project.status === 'ok'),
  );
  const previousProviderAvailable = Boolean(
    previousSession && providers.some((provider) => provider.id === previousSession.provider && provider.available),
  );

  const begin = async () => {
    if (!person || !chosenProvider || !chosenProject || busy) return;
    if (unenforcedPersonPolicy.length > 0 && !acknowledgeUnenforcedPolicy) return;
    setError(null);
    const options = personSessionOptions(
      person,
      chosenProvider,
      chosenModel,
      chosenProject.target,
      chosenProject.name,
      task,
    );
    if (!options) {
      setError('This runner is not available for a local PTY session. Choose an installed runner and a valid project.');
      return;
    }
    setBusy(true);
    try {
      const api = requireClient(client);
      const record = await api.createPersonSession({
        workspace,
        person_id: person.id,
        project_id: chosenProject.name,
        provider: chosenProvider.id,
        model: chosenModel?.model ?? '',
      });
      let session = null;
      try {
        session = await terminals.create({
          ...options,
          cwd: record.session.cwd,
          agentSessionId: record.session.id,
          sessionWorkspace: workspace,
        });
        if (!session) throw new Error('Desktop could not start the local PTY process.');
        try {
          await api.updatePersonSession(workspace, record.session.id, 'running');
        } catch (updateError) {
          const current = await api.personSessions(workspace).catch(() => null);
          const saved = current?.sessions.find((candidate) => candidate.id === record.session.id);
          if (!saved || !['completed', 'failed', 'stopped', 'timed_out', 'interrupted'].includes(saved.status))
            throw updateError;
        }
      } catch (launchError) {
        if (session) await terminals.close(session.id);
        await api.updatePersonSession(workspace, record.session.id, 'failed').catch(() => null);
        throw launchError;
      }
      void queryClient.invalidateQueries({ queryKey: ['person-sessions', workspace] });
      onClose();
      navigate(href('/terminal', { pty: session.id }));
    } catch (startError) {
      setError(errorMessage(startError));
    } finally {
      setBusy(false);
    }
  };

  const copyPrompt = async () => {
    if (!initialPrompt) return;
    if (!navigator.clipboard?.writeText) {
      setTaskCopyError('Clipboard access is unavailable. Select the prompt above to copy it.');
      return;
    }
    try {
      await navigator.clipboard.writeText(initialPrompt);
      setTaskCopied(true);
      setTaskCopyError(null);
    } catch {
      setTaskCopied(false);
      setTaskCopyError('Could not copy the prompt. Select the text above and copy it manually.');
    }
  };

  return (
    <Dialog
      open={person !== null}
      onClose={onClose}
      title={person ? `Start ${person.name}${previousSession ? ' again' : ''}` : 'Start Person'}
      description={
        previousSession
          ? 'Starts a fresh PTY with the previous project and runner settings as a starting point. It does not restore a transcript or continue the prior conversation. Review every choice before starting.'
          : 'Reviews a real local runner session before it starts. The Person stays durable; this task belongs only to the new session. Max runtime is enforced; token/cost limits and worktree/session isolation are not supported by this interactive PTY yet.'
      }
      size="wide"
      footer={
        <div className={styles.startFooter}>
          {needsPolicyAcknowledgement ? (
            <label className={styles.policyAcknowledgement}>
              <input
                type="checkbox"
                checked={acknowledgeUnenforcedPolicy}
                onChange={(event) => setAcknowledgeUnenforcedPolicy(event.target.checked)}
              />
              <span>
                Start without enforcing {unenforcedPersonPolicy.join(', ')}. This session will use the selected project
                folder; its files may be changed by the runner.
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
                !chosenProject ||
                !chosenProvider ||
                busy ||
                (needsPolicyAcknowledgement && !acknowledgeUnenforcedPolicy)
              }
              onClick={() => void begin()}
            >
              Start and open terminal
            </Button>
          </ButtonRow>
        </div>
      }
    >
      {person ? (
        <div className={styles.form}>
          {previousSession ? (
            <p className={styles.recoveryNote} role="note">
              Previous setup: {previousSession.project_id} with {previousSession.provider}
              {previousSession.model ? ` · ${previousSession.model}` : ''}. This opens a fresh session; conversation
              state is not restored. Review the selected settings below.
            </p>
          ) : null}
          {previousSession && projectsQuery.isSuccess && !previousProjectAvailable ? (
            <p role="status" className={styles.recoveryNote}>
              The previous project is no longer linked or healthy. Choose another project before starting.
            </p>
          ) : null}
          {previousSession && providersQuery.isSuccess && !previousProviderAvailable ? (
            <p role="status" className={styles.recoveryNote}>
              The previous runner is unavailable. Choose an installed runner before starting.
            </p>
          ) : null}
          {providersQuery.isError ? (
            <ErrorState title="Could not discover runners" error={providersQuery.error} />
          ) : null}
          {providersQuery.isSuccess && !hasInstalledRunner ? (
            <p role="status" className={styles.recoveryNote}>
              No interactive runner is installed. Configure one in Library, then return here.
            </p>
          ) : null}
          {projectsQuery.isError ? <ErrorState title="Could not load projects" error={projectsQuery.error} /> : null}
          {projectsQuery.isSuccess && !projects.some((project) => project.status === 'ok') ? (
            <p role="status" className={styles.recoveryNote}>
              No healthy project is linked. Link a folder from World or Workspace before starting this Person.
            </p>
          ) : null}
          <div className={styles.formGrid}>
            <Field label="Project and working folder">
              {(control) => (
                <Select {...control} value={projectName} onChange={(event) => setProjectName(event.target.value)}>
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
                  value={providerId}
                  onChange={(event) => {
                    setProviderId(event.target.value);
                    setModelName('');
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
                <Select {...control} value={modelName} onChange={(event) => setModelName(event.target.value)}>
                  <option value="">Runner default</option>
                  {modelName && !matchingModels.some((model) => model.model === modelName) ? (
                    <option value={modelName} disabled>
                      {modelName} · not discovered
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
                onChange={(event) => {
                  setTask(event.target.value);
                  setTaskCopied(false);
                  setTaskCopyError(null);
                }}
              />
            )}
          </Field>
          <Panel title="Start preview" meta={person.role}>
            <p>
              <strong>Configured goal:</strong> {person.goal}
            </p>
            <p>
              <strong>Command:</strong>{' '}
              <code>
                {chosenProvider?.bin || 'Choose a runner'}
                {chosenModel ? ` --model ${chosenModel.model}` : ''}
              </code>
            </p>
            {modelName && !chosenModel ? (
              <p role="status">
                Model “{modelName}” is not in this runner&apos;s discovered catalog; the runner default will be used.
              </p>
            ) : null}
            <p>
              <strong>Initial task:</strong>{' '}
              {!chosenProvider
                ? 'Choose an installed runner to review how this task will be sent.'
                : canSendInitialPrompt
                  ? initialPrompt
                    ? 'Sent to the runner as the first interactive prompt.'
                    : 'None. The terminal opens ready for you to type.'
                  : initialPrompt
                    ? 'This runner has no verified initial-prompt option; copy it into the terminal after it opens.'
                    : 'None. The terminal opens ready for you to type.'}
            </p>
            {initialPrompt ? <pre className={styles.promptPreview}>{initialPrompt}</pre> : null}
            {chosenProvider && !canSendInitialPrompt && initialPrompt ? (
              <div className={styles.copyTaskRow}>
                <Button onClick={() => void copyPrompt()}>{taskCopied ? 'Copied task' : 'Copy task'}</Button>
                {taskCopied ? <span role="status">Task copied to clipboard.</span> : null}
                {taskCopyError ? <span role="alert">{taskCopyError}</span> : null}
              </div>
            ) : null}
            <p>
              <strong>Working folder:</strong> <code>{chosenProject?.target || 'Choose a project'}</code>
            </p>
            <p>
              <strong>Isolation:</strong> {person.isolation || 'inherited'} · this session uses the selected project
              folder
            </p>
            <p>
              <strong>Runtime cap:</strong>{' '}
              {person.budget?.max_seconds ? `${person.budget.max_seconds}s · enforced by Desktop` : 'None configured'}
            </p>
            {person.budget?.max_tokens || person.budget?.max_cost_usd ? (
              <p>
                <strong>Usage limits:</strong>{' '}
                {[
                  person.budget.max_tokens ? `${person.budget.max_tokens.toLocaleString()} tokens` : null,
                  person.budget.max_cost_usd ? `$${person.budget.max_cost_usd.toFixed(2)}` : null,
                ]
                  .filter(Boolean)
                  .join(' · ')}{' '}
                · not enforced for this interactive runner
              </p>
            ) : null}
            <p>Desktop leaves the runner’s normal permission prompts in place. No approval-bypass flags are added.</p>
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
