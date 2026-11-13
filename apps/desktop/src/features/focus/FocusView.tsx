import { useQueryClient } from '@tanstack/react-query';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router';
import { useBackend } from '../../data/backend';
import { useFocusBridge, useFocusProviders, useFocusThreads, useFocusTimeline } from '../../data/focus';
import { useProjects } from '../../data/projects';
import { useTerminalSessions } from '../../data/terminal';
import { OPEN_TERMINAL_DOCK_EVENT } from '../../shell/events';
import type { FocusPermissionMode, FocusThread } from '../../types/focus';
import { Button, ConfirmAction, PixelIcon } from '../../ui';
import { FilesPanel } from '../workspace/FilesPanel';
import { ProjectChangesPanel } from '../workspace/ProjectChangesPanel';
import { Conversation } from './Conversation';
import { MODE_OPTIONS, relativeTime, STATUS_LABEL, threadTitle } from './labels';
import { NewSession } from './NewSession';
import styles from './focus.module.css';

const WIDE_WINDOW = '(min-width: 78.0625rem)';

function ThreadList({
  threads,
  activeId,
  onSelect,
  onNew,
}: {
  threads: readonly FocusThread[];
  activeId: string | null;
  onSelect: (id: string) => void;
  onNew: () => void;
}) {
  const groups = useMemo(() => {
    const byProject = new Map<string, FocusThread[]>();
    for (const thread of threads) {
      const key = thread.projectName ?? 'Other folders';
      const list = byProject.get(key) ?? [];
      list.push(thread);
      byProject.set(key, list);
    }
    return [...byProject.entries()];
  }, [threads]);
  return (
    <nav className={styles.threads} aria-label="Sessions">
      <Button variant="secondary" onClick={onNew} aria-current={activeId === null ? 'page' : undefined}>
        <PixelIcon name="plus" size={12} />
        New session
      </Button>
      {groups.length === 0 ? (
        <p className={styles.quiet}>Sessions you start appear here and stay after a restart.</p>
      ) : null}
      {groups.map(([project, list]) => (
        <section key={project} aria-label={project}>
          <h2 className={styles.threadGroup}>{project}</h2>
          <ul>
            {list.map((thread) => (
              <li key={thread.id}>
                <button
                  type="button"
                  className={styles.thread}
                  data-status={thread.status}
                  aria-current={thread.id === activeId ? 'page' : undefined}
                  onClick={() => onSelect(thread.id)}
                >
                  <span className={styles.threadLamp} aria-hidden="true" />
                  <span className={styles.threadTitle}>{threadTitle(thread)}</span>
                  <span className={styles.threadMeta}>
                    {thread.status === 'idle' ? relativeTime(thread.updatedAt) : STATUS_LABEL[thread.status]}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </section>
      ))}
    </nav>
  );
}

function Header({
  thread,
  models,
  inspectorOpen,
  onToggleInspector,
  onOpenTerminal,
  onError,
  onDeleted,
}: {
  thread: FocusThread;
  models: ReadonlyArray<{ id: string; label: string }>;
  inspectorOpen: boolean;
  onToggleInspector: () => void;
  onOpenTerminal: () => void;
  onError: (message: string) => void;
  onDeleted: () => void;
}) {
  const bridge = useFocusBridge();
  const [renaming, setRenaming] = useState(false);
  const [title, setTitle] = useState(thread.title);
  const busy = thread.status === 'running' || thread.status === 'awaiting-approval';

  useEffect(() => {
    setTitle(thread.title);
    setRenaming(false);
  }, [thread.id, thread.title]);

  const patch = async (change: { title?: string; model?: string | null; permissionMode?: FocusPermissionMode }) => {
    const result = await bridge?.updateThread(thread.id, change);
    if (result && !result.ok) onError(result.error);
  };

  return (
    <header className={styles.header}>
      <div className={styles.headerMain}>
        {renaming ? (
          <input
            className={styles.titleInput}
            aria-label="Session name"
            value={title}
            ref={(element) => element?.focus()}
            onChange={(event) => setTitle(event.target.value)}
            onBlur={() => {
              setRenaming(false);
              if (title.trim() && title !== thread.title) void patch({ title });
            }}
            onKeyDown={(event) => {
              if (event.key === 'Enter') event.currentTarget.blur();
              if (event.key === 'Escape') {
                setTitle(thread.title);
                setRenaming(false);
              }
            }}
          />
        ) : (
          <h1 className={styles.title}>
            <button type="button" onClick={() => setRenaming(true)} title="Rename this session">
              {threadTitle(thread)}
            </button>
          </h1>
        )}
        <p className={styles.headerPath} title={thread.cwd}>
          {thread.projectName ?? thread.cwd}
        </p>
      </div>
      <div className={styles.headerControls}>
        <label className={styles.inlineSelect}>
          <span className={styles.srOnly}>Permissions</span>
          <select
            value={thread.permissionMode}
            disabled={busy}
            title={busy ? 'Stop the running turn to change this' : undefined}
            onChange={(event) => void patch({ permissionMode: event.target.value as FocusPermissionMode })}
          >
            {MODE_OPTIONS.map((option) => (
              <option key={option.id} value={option.id}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        {models.length > 0 ? (
          <label className={styles.inlineSelect}>
            <span className={styles.srOnly}>Model</span>
            <select
              value={thread.model ?? ''}
              disabled={busy}
              title={busy ? 'Stop the running turn to change this' : undefined}
              onChange={(event) => void patch({ model: event.target.value || null })}
            >
              <option value="">Default model</option>
              {models
                .filter((model) => model.id !== 'default')
                .map((model) => (
                  <option key={model.id} value={model.id}>
                    {model.label}
                  </option>
                ))}
            </select>
          </label>
        ) : null}
        <Button variant="ghost" size="sm" onClick={onOpenTerminal} title="Open a terminal in this project">
          <PixelIcon name="terminal" size={12} />
          Terminal
        </Button>
        <Button
          variant="ghost"
          size="sm"
          onClick={onToggleInspector}
          aria-pressed={inspectorOpen}
          title="Show changes and files"
        >
          <PixelIcon name="branch" size={12} />
          Changes
        </Button>
        <ConfirmAction
          label="Delete"
          size="sm"
          triggerVariant="ghost"
          title="Delete this session?"
          description="Its history is removed from this workspace. Files the agent changed stay as they are."
          confirmLabel="Delete session"
          disabled={busy}
          onConfirm={() => {
            void bridge?.deleteThread(thread.id).then((result) => {
              if (result.ok) onDeleted();
              else onError(result.error);
            });
          }}
        />
      </div>
    </header>
  );
}

function Inspector({ thread, workspace, onClose }: { thread: FocusThread; workspace: string; onClose: () => void }) {
  const [tab, setTab] = useState<'changes' | 'files'>('changes');
  const queryClient = useQueryClient();
  const timeline = useFocusTimeline(thread.id);
  const lastSeq = timeline.events.at(-1)?.seq ?? 0;
  const lastType = timeline.events.at(-1)?.type;

  // The working tree changes when a tool finishes or a turn ends: re-read Git then, not on a timer.
  useEffect(() => {
    if (lastType !== 'tool.finished' && lastType !== 'turn.finished') return;
    void queryClient.invalidateQueries({
      predicate: (query) => query.queryKey[0] === 'projects' && String(query.queryKey[1]).startsWith('git'),
    });
    void queryClient.invalidateQueries({ queryKey: ['files'] });
  }, [queryClient, lastSeq, lastType]);

  if (!thread.projectName) {
    return (
      <aside className={styles.inspector} aria-label="Changes and files">
        <p className={styles.quiet}>
          This session runs in a folder that is not a linked project, so changes cannot be reviewed here.
        </p>
      </aside>
    );
  }
  return (
    <aside className={styles.inspector} aria-label="Changes and files">
      <div className={styles.tabs} role="tablist" aria-label="Project view">
        <button type="button" role="tab" aria-selected={tab === 'changes'} onClick={() => setTab('changes')}>
          Changes
        </button>
        <button type="button" role="tab" aria-selected={tab === 'files'} onClick={() => setTab('files')}>
          Files
        </button>
        <span className={styles.tabsClose}>
          <Button variant="ghost" size="sm" onClick={onClose} aria-label="Close changes and files">
            <PixelIcon name="cross" size={12} />
          </Button>
        </span>
      </div>
      <div className={styles.inspectorBody} role="tabpanel">
        {tab === 'changes' ? (
          <ProjectChangesPanel workspace={workspace} projects={[{ name: thread.projectName, status: 'ok' }]} />
        ) : (
          <FilesPanel project={thread.projectName} />
        )}
      </div>
    </aside>
  );
}

/**
 * Focus: one real coding session at a time. The conversation, tool activity
 * and approvals come from the session journal; the project's working tree
 * and files sit beside it; a real terminal opens in the same folder.
 */
export default function FocusView() {
  const { backend } = useBackend();
  const workspace = backend?.harness?.path ?? '';
  const [params, setParams] = useSearchParams();
  const { threads, loaded } = useFocusThreads();
  const providers = useFocusProviders();
  const projects = useProjects(workspace);
  const terminals = useTerminalSessions();
  const bridge = useFocusBridge();
  const [error, setError] = useState<string | null>(null);
  // Beside the conversation on a wide window; an overlay you open on demand on a compact one.
  const [inspectorOpen, setInspectorOpen] = useState(() => window.matchMedia(WIDE_WINDOW).matches);
  useEffect(() => {
    const query = window.matchMedia(WIDE_WINDOW);
    const onChange = (event: MediaQueryListEvent) => setInspectorOpen(event.matches);
    query.addEventListener('change', onChange);
    return () => query.removeEventListener('change', onChange);
  }, []);
  const errorTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const requested = params.get('thread');
  const active = threads.find((thread) => thread.id === requested) ?? null;

  const select = useCallback(
    (id: string | null) => {
      setParams(
        (current) => {
          const next = new URLSearchParams(current);
          if (id) next.set('thread', id);
          else next.delete('thread');
          next.delete('project');
          return next;
        },
        { replace: false },
      );
    },
    [setParams],
  );

  const showError = useCallback((message: string) => {
    setError(message);
    if (errorTimer.current) clearTimeout(errorTimer.current);
    errorTimer.current = setTimeout(() => setError(null), 12_000);
  }, []);
  useEffect(() => () => void (errorTimer.current && clearTimeout(errorTimer.current)), []);

  const openTerminal = async (thread: FocusThread) => {
    const session = await terminals
      .create({ agent: 'shell', cmd: '@shell', cwd: thread.cwd, projectId: thread.projectName ?? undefined })
      .catch(() => null);
    if (!session) {
      showError('The terminal could not be opened in this folder.');
      return;
    }
    window.dispatchEvent(new Event(OPEN_TERMINAL_DOCK_EVENT));
  };

  const provider = providers.data?.find((entry) => entry.id === active?.provider);

  return (
    <div className={styles.focus} data-inspector={active && inspectorOpen ? 'open' : 'closed'}>
      <ThreadList threads={threads} activeId={active?.id ?? null} onSelect={select} onNew={() => select(null)} />
      <div className={styles.stage}>
        {error ? (
          <p className={styles.banner} role="alert">
            {error}
            <button type="button" className={styles.linkButton} onClick={() => setError(null)}>
              Dismiss
            </button>
          </p>
        ) : null}
        {!bridge ? (
          <p className={styles.quiet}>
            Sessions run inside the Agent Toolkit Desktop app. This preview has no session runtime.
          </p>
        ) : active ? (
          <>
            <Header
              thread={active}
              models={provider?.models ?? []}
              inspectorOpen={inspectorOpen}
              onToggleInspector={() => setInspectorOpen((open) => !open)}
              onOpenTerminal={() => void openTerminal(active)}
              onError={showError}
              onDeleted={() => select(null)}
            />
            <Conversation thread={active} provider={provider} onError={showError} />
          </>
        ) : requested && !loaded ? (
          <p className={styles.quiet}>Loading sessions…</p>
        ) : (
          <NewSession
            workspace={workspace}
            projects={projects.data?.projects ?? []}
            projectsLoading={projects.isLoading}
            providers={providers.data ?? []}
            providersLoading={providers.isLoading}
            onRefreshProviders={() => {
              void bridge.providers({ refresh: true }).then(() => providers.refetch());
            }}
            defaults={{ project: params.get('project') ?? undefined }}
            onStarted={select}
          />
        )}
      </div>
      {active && inspectorOpen ? (
        <Inspector thread={active} workspace={workspace} onClose={() => setInspectorOpen(false)} />
      ) : null}
    </div>
  );
}
