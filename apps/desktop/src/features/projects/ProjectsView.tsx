import { useEffect, useMemo, useState } from 'react';
import { Link, useSearchParams } from 'react-router';
import { useBackend } from '../../data/backend';
import { useFocusThreads } from '../../data/focus';
import { useLinkProject, useProjectGitStatus, useProjects } from '../../data/projects';
import { useTerminalSessions } from '../../data/terminal';
import type { ProjectListEntry } from '../../lib/api';
import { errorMessage, recoveryHint } from '../../lib/api';
import { OPEN_TERMINAL_DOCK_EVENT } from '../../shell/events';
import { useSessionContext } from '../../shell/useSessionContext';
import type { FocusThread } from '../../types/focus';
import { Button, PixelIcon, useReceipts } from '../../ui';
import { relativeTime, STATUS_LABEL, threadTitle } from '../focus/labels';
import { FilesPanel } from '../workspace/FilesPanel';
import { ProjectChangesPanel } from '../workspace/ProjectChangesPanel';
import styles from './projects.module.css';

type Tab = 'changes' | 'files' | 'sessions';

function changeSummary(counts: { staged: number; unstaged: number; untracked: number }): string {
  const total = counts.staged + counts.unstaged + counts.untracked;
  if (total === 0) return 'No changes';
  return total === 1 ? '1 changed file' : `${total} changed files`;
}

function ProjectRow({
  workspace,
  project,
  threads,
  selected,
  onSelect,
}: {
  workspace: string;
  project: ProjectListEntry;
  threads: readonly FocusThread[];
  selected: boolean;
  onSelect: () => void;
}) {
  const linked = project.status === 'ok';
  const git = useProjectGitStatus(workspace, linked ? project.name : '');
  const working = threads.filter((thread) => thread.status === 'running').length;
  const waiting = threads.filter((thread) => thread.status === 'awaiting-approval').length;
  const state = waiting > 0 ? 'waiting' : working > 0 ? 'working' : undefined;
  let detail = 'Reading repository…';
  if (!linked) detail = 'The linked folder is missing';
  else if (git.isError) detail = 'Could not read the repository';
  else if (git.data && !git.data.ok) detail = git.data.detail || 'Not a Git repository';
  else if (git.data) {
    detail = `${git.data.branch || 'no branch'}, ${changeSummary({
      staged: git.data.staged.length,
      unstaged: git.data.unstaged.length,
      untracked: git.data.untracked.length,
    }).toLowerCase()}`;
  }
  return (
    <li>
      <button
        type="button"
        className={styles.row}
        data-state={state}
        data-broken={!linked || undefined}
        aria-current={selected ? 'true' : undefined}
        onClick={onSelect}
      >
        <span className={styles.rowLamp} aria-hidden="true" />
        <span className={styles.rowName}>{project.name}</span>
        <span className={styles.rowDetail}>{detail}</span>
        {waiting > 0 ? <span className={styles.rowFlag}>Needs your answer</span> : null}
        {waiting === 0 && working > 0 ? <span className={styles.rowFlag}>Working</span> : null}
      </button>
    </li>
  );
}

function Sessions({ threads, project }: { threads: readonly FocusThread[]; project: string }) {
  const { href } = useSessionContext();
  if (threads.length === 0) {
    return (
      <div className={styles.empty}>
        <p>No sessions in {project} yet.</p>
        <Link className={styles.action} to={href('/focus', { project })}>
          Start a session
        </Link>
      </div>
    );
  }
  return (
    <ul className={styles.sessions} aria-label={`Sessions in ${project}`}>
      {threads.map((thread) => (
        <li key={thread.id}>
          <Link to={href('/focus', { thread: thread.id })} className={styles.session} data-status={thread.status}>
            <span className={styles.sessionTitle}>{threadTitle(thread)}</span>
            <span className={styles.sessionMeta}>
              {thread.status === 'idle' ? relativeTime(thread.updatedAt) : STATUS_LABEL[thread.status]}
            </span>
          </Link>
        </li>
      ))}
    </ul>
  );
}

/**
 * Projects: the repositories this workspace knows, what state each is in,
 * and the three things you do with one: talk to an agent about it, review
 * what changed, or open a terminal in it.
 */
export default function ProjectsView() {
  const { backend } = useBackend();
  const workspace = backend?.harness?.path ?? '';
  const { href } = useSessionContext();
  const [params, setParams] = useSearchParams();
  const projects = useProjects(workspace);
  const link = useLinkProject(workspace);
  const { threads } = useFocusThreads();
  const terminals = useTerminalSessions();
  const { push } = useReceipts();
  const list = useMemo(() => projects.data?.projects ?? [], [projects.data]);
  const requested = params.get('project');
  const selected = list.find((project) => project.name === requested) ?? list[0] ?? null;
  const tabParam = params.get('tab');
  const tab: Tab = tabParam === 'files' || tabParam === 'sessions' ? tabParam : 'changes';
  const [terminalError, setTerminalError] = useState<string | null>(null);

  const update = (next: { project?: string; tab?: Tab }) =>
    setParams(
      (current) => {
        const merged = new URLSearchParams(current);
        if (next.project) merged.set('project', next.project);
        if (next.tab) merged.set('tab', next.tab);
        return merged;
      },
      { replace: true },
    );

  useEffect(() => setTerminalError(null), [selected?.name]);

  const byProject = useMemo(() => {
    const map = new Map<string, FocusThread[]>();
    for (const thread of threads) {
      if (!thread.projectName) continue;
      map.set(thread.projectName, [...(map.get(thread.projectName) ?? []), thread]);
    }
    return map;
  }, [threads]);

  const linkRepository = () =>
    link.mutate(undefined, {
      onSuccess: (linked) => {
        if (!linked) return;
        push({ tone: 'ok', title: `Linked ${linked.name}`, detail: linked.path });
        update({ project: linked.name });
      },
    });

  const openTerminal = async (project: ProjectListEntry) => {
    setTerminalError(null);
    const session = await terminals
      .create({ agent: 'shell', cmd: '@shell', cwd: project.target, projectId: project.name })
      .catch(() => null);
    if (!session) {
      setTerminalError('The terminal could not be opened in this folder.');
      return;
    }
    window.dispatchEvent(new Event(OPEN_TERMINAL_DOCK_EVENT));
  };

  return (
    <div className={styles.page}>
      <header className={styles.head}>
        <div>
          <h1 className={styles.title}>Projects</h1>
          <p className={styles.lede}>
            Repositories linked to this workspace. They stay where they are on disk; linking only tells Agent Toolkit
            where to find them.
          </p>
        </div>
        <Button variant="primary" onClick={linkRepository} busy={link.isPending} busyLabel="Linking…">
          <PixelIcon name="plus" size={12} />
          Link a repository
        </Button>
      </header>

      {link.error ? (
        <p className={styles.error} role="alert">
          {link.error.message}
        </p>
      ) : null}
      {projects.isError ? (
        <p className={styles.error} role="alert">
          Could not list projects: {errorMessage(projects.error)} {recoveryHint(projects.error)}
        </p>
      ) : null}
      {projects.isPending && workspace ? <p role="status">Reading projects…</p> : null}

      {projects.isSuccess && list.length === 0 ? (
        <div className={styles.empty}>
          <p>
            <strong>No repository linked yet.</strong>
          </p>
          <p>Choose the folder of a repository you already have to start working on it here.</p>
        </div>
      ) : null}

      {selected ? (
        <div className={styles.split}>
          <ul className={styles.list} aria-label="Linked projects">
            {list.map((project) => (
              <ProjectRow
                key={project.name}
                workspace={workspace}
                project={project}
                threads={byProject.get(project.name) ?? []}
                selected={project.name === selected.name}
                onSelect={() => update({ project: project.name })}
              />
            ))}
          </ul>

          <section className={styles.detail} aria-label={selected.name}>
            <header className={styles.detailHead}>
              <div className={styles.detailIdentity}>
                <h2 className={styles.detailTitle}>{selected.name}</h2>
                <p className={styles.path} title={selected.target}>
                  {selected.target}
                </p>
              </div>
              <div className={styles.detailActions}>
                <Link className={styles.action} data-primary to={href('/focus', { project: selected.name })}>
                  <PixelIcon name="focus" size={12} />
                  New session
                </Link>
                <Button variant="ghost" onClick={() => void openTerminal(selected)} disabled={selected.status !== 'ok'}>
                  <PixelIcon name="terminal" size={12} />
                  Terminal
                </Button>
                <Link className={styles.action} to={href('/world', { project: selected.name })}>
                  <PixelIcon name="world" size={12} />
                  Show in World
                </Link>
              </div>
            </header>
            {terminalError ? (
              <p className={styles.error} role="alert">
                {terminalError}
              </p>
            ) : null}
            {selected.status !== 'ok' ? (
              <p className={styles.error} role="alert">
                The folder this project points to no longer exists. Link the repository again from its new location.
              </p>
            ) : (
              <>
                <div className={styles.tabs} role="tablist" aria-label={`${selected.name} views`}>
                  {(
                    [
                      ['changes', 'Changes'],
                      ['files', 'Files'],
                      ['sessions', `Sessions (${(byProject.get(selected.name) ?? []).length})`],
                    ] as const
                  ).map(([id, label]) => (
                    <button
                      key={id}
                      type="button"
                      role="tab"
                      aria-selected={tab === id}
                      onClick={() => update({ tab: id })}
                    >
                      {label}
                    </button>
                  ))}
                </div>
                <div className={styles.tabPanel} role="tabpanel">
                  {tab === 'changes' ? (
                    <ProjectChangesPanel
                      key={selected.name}
                      workspace={workspace}
                      projects={[{ name: selected.name, status: 'ok' }]}
                    />
                  ) : null}
                  {tab === 'files' ? <FilesPanel key={selected.name} project={selected.name} /> : null}
                  {tab === 'sessions' ? (
                    <Sessions threads={byProject.get(selected.name) ?? []} project={selected.name} />
                  ) : null}
                </div>
              </>
            )}
          </section>
        </div>
      ) : null}
    </div>
  );
}
