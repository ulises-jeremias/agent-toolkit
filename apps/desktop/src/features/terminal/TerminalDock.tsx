import { useEffect, useRef, type KeyboardEvent } from 'react';
import { useTerminals } from '../../data/terminals';
import { ariaKeyShortcuts, IS_MAC, shortcutKeys } from '../../lib/shortcuts';
import { useShellContext } from '../../shell/context';
import { Button, EmptyState, Kbd, LoadingState } from '../../ui';
import { NewSessionDialog } from './NewSessionDialog';
import { basename, sessionState, TerminalPane } from './TerminalPane';
import styles from './terminal.module.css';

/**
 * Persistent host for every terminal session. It lives in the shell, outside
 * the routes, so navigating never unmounts an xterm. On /terminal it fills
 * the page; elsewhere it is a dock toggled with Mod+`.
 */
export function TerminalDock({ full }: { full: boolean }) {
  const terminals = useTerminals();
  const context = useShellContext();
  const tabRefs = useRef(new Map<string, HTMLButtonElement>());
  const sectionRef = useRef<HTMLElement>(null);
  const visible = full || terminals.dockOpen;

  // Hiding the dock with focus inside must not strand focus on a hidden node.
  useEffect(() => {
    const section = sectionRef.current;
    if (!visible && section?.contains(document.activeElement)) {
      document.getElementById('main')?.focus();
    }
  }, [visible]);

  if (!terminals.available) return null;

  const { sessions, activeId } = terminals;

  const onTabKeyDown = (event: KeyboardEvent<HTMLButtonElement>, index: number) => {
    const last = sessions.length - 1;
    const target =
      event.key === 'ArrowRight'
        ? index === last
          ? 0
          : index + 1
        : event.key === 'ArrowLeft'
          ? index === 0
            ? last
            : index - 1
          : event.key === 'Home'
            ? 0
            : event.key === 'End'
              ? last
              : null;
    if (target === null) return;
    event.preventDefault();
    const session = sessions[target];
    if (!session) return;
    terminals.setActive(session.id);
    tabRefs.current.get(session.id)?.focus();
  };

  return (
    <>
      <section
        ref={sectionRef}
        className={styles.dock}
        data-mode={full ? 'full' : 'docked'}
        data-open={visible}
        aria-label="Terminal dock"
        inert={!visible || undefined}
      >
        <div className={styles.dockBar}>
          {!full ? <p className={styles.dockTitle}>Terminal</p> : null}
          {sessions.length > 0 ? (
            <div className={styles.tabs} role="tablist" aria-label="Terminal sessions">
              {sessions.map((session, index) => {
                const state = sessionState(session.exitCode);
                const selected = session.id === activeId;
                return (
                  <button
                    key={session.id}
                    ref={(node) => {
                      if (node) tabRefs.current.set(session.id, node);
                      else tabRefs.current.delete(session.id);
                    }}
                    id={`terminal-tab-${session.id}`}
                    type="button"
                    role="tab"
                    aria-selected={selected}
                    aria-controls={`terminal-panel-${session.id}`}
                    tabIndex={selected ? 0 : -1}
                    className={styles.tab}
                    title={`${session.agent}${session.run ? ` · run ${session.run}` : ''} · ${session.cwd} · ${state.label}`}
                    onClick={() => terminals.setActive(session.id)}
                    onKeyDown={(event) => onTabKeyDown(event, index)}
                  >
                    <span className={styles.tabAgent}>{session.agent}</span>
                    {session.run ? <span className={styles.tabMeta}>{session.run}</span> : null}
                    <span className={styles.tabMeta}>{basename(session.cwd)}</span>
                    <span className={styles.tabState} data-tone={state.tone}>
                      {state.label}
                    </span>
                  </button>
                );
              })}
            </div>
          ) : null}
          {!full ? (
            <div className={styles.dockActions}>
              <Button size="sm" variant="ghost" onClick={() => terminals.setNewSessionOpen(true)}>
                New session
              </Button>
              <Button
                size="sm"
                variant="ghost"
                onClick={() => terminals.setDockOpen(false)}
                aria-keyshortcuts={ariaKeyShortcuts(shortcutKeys('toggleDock'), IS_MAC)}
              >
                Hide <Kbd keys={shortcutKeys('toggleDock')} />
              </Button>
            </div>
          ) : null}
        </div>

        <div className={styles.panes}>
          {terminals.loading ? (
            <LoadingState label="Listing sessions" />
          ) : sessions.length === 0 ? (
            <div className={styles.dockEmpty}>
              <EmptyState title="No terminal is open.">
                Open a session to run a shell or an agent CLI with full interactive input.
              </EmptyState>
              <Button variant="primary" onClick={() => terminals.setNewSessionOpen(true)}>
                New session
              </Button>
            </div>
          ) : (
            sessions.map((session) => (
              <TerminalPane
                key={session.id}
                session={session}
                tabId={`terminal-tab-${session.id}`}
                panelId={`terminal-panel-${session.id}`}
                active={session.id === activeId}
                visible={visible}
                onClose={() => void terminals.close(session.id)}
                onRestart={() => void terminals.restart(session)}
              />
            ))
          )}
        </div>
      </section>
      {/* Outside the section: an inert ancestor would make the modal inert too. */}
      <NewSessionDialog
        open={terminals.newSessionOpen}
        defaults={{ agent: context.agent, cwd: context.ws, run: context.run }}
        onClose={() => terminals.setNewSessionOpen(false)}
        onCreate={(options) => {
          terminals.setDockOpen(true);
          void terminals.create(options);
        }}
      />
    </>
  );
}
