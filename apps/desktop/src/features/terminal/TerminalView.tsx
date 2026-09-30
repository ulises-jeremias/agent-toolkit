import { useTerminalSessions } from '../../data/terminal';
import { Button, EmptyState, LoadingState, PageHeader, Panel } from '../../ui';
import styles from './terminal.module.css';

/**
 * Terminal destination: chrome and empty states. Sessions live in the
 * persistent dock so leaving this page never disposes xterm.
 */
export default function TerminalView() {
  const { available, loading, sessions, setCreating } = useTerminalSessions();

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
        title="Sessions"
        lede="The dock keeps every session mounted. Navigating away does not tear them down."
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
        <p className={styles.pageHint}>
          {sessions.length} {sessions.length === 1 ? 'session' : 'sessions'} in the dock. Each tab shows the agent, run,
          working folder and process state.
        </p>
      )}
    </div>
  );
}
