import { useEffect, useMemo, useRef, useState, type FormEvent, type RefObject } from 'react';
import { useFocusBridge } from '../../data/focus';
import { useLinkProject } from '../../data/projects';
import type { ProjectListEntry } from '../../lib/api';
import type { FocusPermissionMode, FocusProviderId, FocusProviderStatus } from '../../types/focus';
import { Button, PixelIcon } from '../../ui';
import { MODE_OPTIONS, providerBlocker } from './labels';
import styles from './focus.module.css';

export interface NewSessionDefaults {
  project?: string;
}

/** Never silently substitute a different repository for an explicit project selection. */
export function selectStartProject(
  projects: readonly ProjectListEntry[],
  selected: string,
): ProjectListEntry | undefined {
  const usable = projects.filter((entry) => entry.status === 'ok');
  return selected ? usable.find((entry) => entry.name === selected) : usable[0];
}

/** The start of every session: where, with whom, how careful, and the task itself. */
export function NewSession({
  workspace,
  projects,
  projectsLoading,
  providers,
  providersLoading,
  onRefreshProviders,
  onShowSessions,
  sessionsOpen,
  sessionsToggleRef,
  defaults,
  onStarted,
}: {
  workspace: string;
  projects: readonly ProjectListEntry[];
  projectsLoading: boolean;
  providers: readonly FocusProviderStatus[];
  providersLoading: boolean;
  onRefreshProviders: () => void;
  onShowSessions: () => void;
  sessionsOpen: boolean;
  sessionsToggleRef: RefObject<HTMLButtonElement | null>;
  defaults?: NewSessionDefaults;
  onStarted: (threadId: string) => void;
}) {
  const bridge = useFocusBridge();
  const link = useLinkProject(workspace);
  const usable = useMemo(() => projects.filter((project) => project.status === 'ok'), [projects]);
  const ready = useMemo(() => providers.filter((provider) => providerBlocker(provider) === null), [providers]);
  const [project, setProject] = useState(defaults?.project ?? '');
  const [providerId, setProviderId] = useState<FocusProviderId | ''>('');
  const [model, setModel] = useState('');
  const [mode, setMode] = useState<FocusPermissionMode>('ask');
  const [task, setTask] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [starting, setStarting] = useState(false);
  const startingRef = useRef(false);

  const activeProject = selectStartProject(usable, project);
  const activeProvider = ready.find((entry) => entry.id === providerId) ?? ready[0];

  useEffect(() => {
    if (defaults?.project) setProject(defaults.project);
  }, [defaults?.project]);

  // The task is the reason this form exists: typing starts there.
  const taskRef = useRef<HTMLTextAreaElement>(null);
  useEffect(() => {
    taskRef.current?.focus();
  }, []);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    if (startingRef.current || !bridge || !activeProject || !activeProvider || !task.trim()) return;
    // State updates paint later. Keyboard and pointer submissions can land in
    // the same turn, so guard the async boundary synchronously as well.
    startingRef.current = true;
    setError(null);
    setStarting(true);
    try {
      const created = await bridge.createThread({
        cwd: activeProject.target,
        projectName: activeProject.name,
        provider: activeProvider.id,
        model: model || null,
        permissionMode: mode,
      });
      if (!created.ok) {
        setError(created.error);
        return;
      }
      const sent = await bridge.send(created.value.id, task.trim());
      if (!sent.ok) {
        setError(sent.error);
        return;
      }
      onStarted(created.value.id);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not start the session. Please try again.');
    } finally {
      startingRef.current = false;
      setStarting(false);
    }
  };

  const linkFolder = () =>
    link.mutate(undefined, {
      onSuccess: (linked) => {
        if (linked) setProject(linked.name);
      },
    });

  const canStart = Boolean(bridge && activeProject && activeProvider && task.trim()) && !starting;

  return (
    <form className={styles.start} onSubmit={(event) => void submit(event)} aria-labelledby="focus-start-title">
      <div className={styles.startHeading}>
        <h1 id="focus-start-title" className={styles.startTitle}>
          What should we work on?
        </h1>
        <button
          type="button"
          ref={sessionsToggleRef}
          className={styles.sessionsToggle}
          aria-controls="focus-sessions"
          aria-expanded={sessionsOpen}
          onClick={onShowSessions}
        >
          Sessions
        </button>
      </div>

      <label className={styles.srOnly} htmlFor="focus-start-task">
        Task
      </label>
      <textarea
        id="focus-start-task"
        className={styles.startTask}
        rows={3}
        value={task}
        ref={taskRef}
        placeholder="Fix the failing test in src/math.test.js"
        onChange={(event) => setTask(event.target.value)}
        onKeyDown={(event) => {
          if (event.key === 'Enter' && (event.metaKey || event.ctrlKey)) void submit(event);
        }}
      />

      <div className={styles.startRow}>
        <div className={styles.startField}>
          <label htmlFor="focus-start-project">Project</label>
          {usable.length > 0 ? (
            <select
              id="focus-start-project"
              value={activeProject?.name ?? ''}
              onChange={(event) => setProject(event.target.value)}
            >
              {usable.map((entry) => (
                <option key={entry.name} value={entry.name}>
                  {entry.name}
                </option>
              ))}
            </select>
          ) : (
            <p className={styles.startEmpty}>{projectsLoading ? 'Looking for projects…' : 'No project linked yet.'}</p>
          )}
          <Button
            variant={usable.length === 0 ? 'primary' : 'ghost'}
            size="sm"
            onClick={linkFolder}
            busy={link.isPending}
          >
            <PixelIcon name="projects" size={12} />
            {usable.length === 0 ? 'Choose a repository folder' : 'Link another folder'}
          </Button>
          {project && !activeProject ? (
            <p className={styles.startError} role="alert">
              The selected repository is unavailable. Choose an available project before starting.
            </p>
          ) : null}
          {activeProject ? <p className={styles.startPath}>{activeProject.target}</p> : null}
          {link.error ? (
            <p className={styles.startError} role="alert">
              {link.error.message}
            </p>
          ) : null}
        </div>

        <div className={styles.startField}>
          <label htmlFor="focus-start-mode">Permissions</label>
          <select
            id="focus-start-mode"
            value={mode}
            onChange={(event) => setMode(event.target.value as FocusPermissionMode)}
          >
            {MODE_OPTIONS.map((option) => (
              <option key={option.id} value={option.id}>
                {option.label}
              </option>
            ))}
          </select>
          <p className={styles.startHint} data-danger={mode === 'bypass' || undefined}>
            {MODE_OPTIONS.find((option) => option.id === mode)?.hint}
          </p>
        </div>
      </div>

      <fieldset className={styles.providers}>
        <legend>
          Agent
          <button type="button" className={styles.linkButton} onClick={onRefreshProviders}>
            Check again
          </button>
        </legend>
        {!providersLoading && ready.length === 0 && providers.length > 0 ? (
          <p className={styles.startProviderNotice} role="status" aria-live="polite">
            No coding agent is signed in. Run the login command shown beside an installed agent, then choose Check
            again.
          </p>
        ) : null}
        {providersLoading && providers.length === 0 ? (
          <p className={styles.startEmpty}>Checking installed agents…</p>
        ) : null}
        {providers.map((provider) => {
          const blocker = providerBlocker(provider);
          const selected = activeProvider?.id === provider.id;
          return (
            <label
              key={provider.id}
              className={styles.provider}
              data-selected={selected || undefined}
              data-blocked={blocker ? true : undefined}
            >
              <input
                type="radio"
                name="focus-provider"
                value={provider.id}
                checked={selected}
                disabled={blocker !== null}
                onChange={() => {
                  setProviderId(provider.id);
                  setModel('');
                }}
              />
              <span className={styles.providerName}>
                {provider.label}
                {provider.version ? <span className={styles.providerVersion}>{provider.version}</span> : null}
              </span>
              <span className={styles.providerState}>{blocker ?? provider.authDetail}</span>
            </label>
          );
        })}
      </fieldset>

      {activeProvider && activeProvider.models.length > 0 ? (
        <div className={styles.startField}>
          <label htmlFor="focus-start-model">Model</label>
          <select id="focus-start-model" value={model} onChange={(event) => setModel(event.target.value)}>
            <option value="">Provider default</option>
            {activeProvider.models
              .filter((option) => option.id !== 'default')
              .map((option) => (
                <option key={option.id} value={option.id}>
                  {option.description ? `${option.label} (${option.description})` : option.label}
                </option>
              ))}
          </select>
        </div>
      ) : null}

      {error ? (
        <p className={styles.startError} role="alert">
          {error}
        </p>
      ) : null}

      <div className={styles.startActions}>
        <Button
          type="submit"
          variant="primary"
          disabled={!canStart}
          busy={starting}
          busyLabel="Starting…"
          aria-describedby="focus-start-hint"
        >
          Start session
        </Button>
        <span
          id="focus-start-hint"
          className={styles.startHint}
          data-danger={(!activeProvider && !providersLoading) || undefined}
        >
          {providersLoading
            ? 'Checking agents…'
            : activeProvider
              ? 'Ctrl + Enter'
              : providers.length > 0
                ? 'Sign in to an agent to start'
                : 'Install a supported coding agent to start'}
        </span>
      </div>
    </form>
  );
}
