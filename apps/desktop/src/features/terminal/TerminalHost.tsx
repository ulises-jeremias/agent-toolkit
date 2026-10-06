import { useState } from 'react';
import { useTerminalSessions } from '../../data/terminal';
import { errorMessage } from '../../lib/api';
import { basename } from '../../shell/sessionContext';
import { TerminalPane } from './TerminalPane';
import { sessionState } from './sessionState';
import styles from './terminal.module.css';

/**
 * Persistent host for every xterm instance. Panes stay mounted; only the
 * active one is shown. The dock and the Terminal destination share this.
 */
export function TerminalHost() {
  const { sessions, extras, activeId, close, restart } = useTerminalSessions();
  const [restartError, setRestartError] = useState<string | null>(null);
  if (sessions.length === 0 && !restartError) return null;
  return (
    <div className={styles.host}>
      {restartError ? (
        <p role="alert" className={styles.sessionError}>
          Could not restart session: {restartError}
        </p>
      ) : null}
      {sessions.map((session) => (
        <div
          key={session.id}
          className={styles.hostPane}
          data-active={session.id === activeId}
          aria-hidden={session.id !== activeId}
        >
          <TerminalPane
            session={session}
            run={extras[session.id]?.run}
            onClose={() => void close(session.id)}
            onRestart={() =>
              void restart(session)
                .then(() => setRestartError(null))
                .catch((error: unknown) => setRestartError(errorMessage(error)))
            }
          />
        </div>
      ))}
    </div>
  );
}

export function TerminalTabs() {
  const { sessions, extras, activeId, focusSession } = useTerminalSessions();
  if (sessions.length === 0) return null;
  return (
    <div className={styles.tabs} role="tablist" aria-label="Sessions">
      {sessions.map((session) => {
        const state = sessionState(session.exitCode, session.exitReason);
        const run = extras[session.id]?.run;
        return (
          <button
            key={session.id}
            type="button"
            role="tab"
            aria-selected={session.id === activeId}
            className={styles.tab}
            onClick={() => focusSession(session.id)}
            data-session-id={session.id}
            aria-label={`${session.agent}${run ? ` · ${run}` : ''} · ${basename(session.cwd)} · ${state.label}`}
            title={`${session.agent}${run ? ` · ${run}` : ''} · ${session.cwd} · ${state.label}`}
          >
            <span className={styles.tabAgent}>{session.agent}</span>
            {run ? <span className={styles.tabRun}>{run}</span> : null}
            <span className={styles.tabCwd}>{basename(session.cwd)}</span>
            <span className={styles.tabState} data-tone={state.tone}>
              {state.label}
            </span>
          </button>
        );
      })}
    </div>
  );
}
