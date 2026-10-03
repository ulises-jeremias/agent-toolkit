import { useTerminalSessions } from '../../data/terminal';
import { basename } from '../../shell/sessionContext';
import { Button, EmptyState, LoadingState, Mono, PageHeader, Panel, StatusBadge, Table } from '../../ui';
import { sessionState } from './sessionState';
import styles from './terminal.module.css';

/**
 * Terminal destination: chrome and the session inventory. xterm hosts live
 * in the persistent dock — this view must not construct a second Terminal.
 */
export default function TerminalView() {
  const { available, loading, sessions, extras, activeId, focusSession, setCreating } = useTerminalSessions();

  if (!available) {
    return (
      <>
        <PageHeader eyebrow="Terminal" title="Terminal" />
        <Panel title="Unavailable in the browser">
          <EmptyState title="Interactive terminals need the Desktop app.">
            They run through node-pty in the Electron main process. Start Desktop with <code>pnpm dev:electron</code>.
          </EmptyState>
        </Panel>
      </>
    );
  }

  return (
    <div className={styles.page}>
      <PageHeader
        eyebrow="Terminal"
        title="Workstation"
        lede="A place in the world. The dock keeps the process; leaving does not tear it down."
        actions={
          <Button variant="primary" onClick={() => setCreating(true)}>
            New session
          </Button>
        }
      />
      {loading ? (
        <LoadingState label="Listing sessions" />
      ) : sessions.length === 0 ? (
        <Panel title="No sessions">
          <EmptyState title="No terminal is open.">
            Open a session to run a shell or an agent CLI with full interactive input.
          </EmptyState>
        </Panel>
      ) : (
        <Panel title="Open sessions" meta={`${sessions.length} in the dock`}>
          <Table caption="Open sessions">
            <thead>
              <tr>
                <th scope="col">Agent</th>
                <th scope="col">Run</th>
                <th scope="col">Working folder</th>
                <th scope="col">Process</th>
              </tr>
            </thead>
            <tbody>
              {sessions.map((session) => {
                const state = sessionState(session.exitCode, session.exitReason);
                const run = extras[session.id]?.run;
                return (
                  <tr
                    key={session.id}
                    className={styles.sessionRow}
                    data-active={session.id === activeId || undefined}
                    data-session-id={session.id}
                  >
                    <th scope="row">
                      <button
                        type="button"
                        className={styles.sessionSelect}
                        onClick={() => focusSession(session.id)}
                        aria-current={session.id === activeId ? 'true' : undefined}
                      >
                        {session.agent}
                      </button>
                    </th>
                    <td>{run ? <Mono>{run}</Mono> : '—'}</td>
                    <td title={session.cwd}>
                      <Mono>{basename(session.cwd)}</Mono>
                    </td>
                    <td>
                      <StatusBadge tone={state.tone} label={state.label} live={session.exitCode === null} />
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </Table>
        </Panel>
      )}
    </div>
  );
}
