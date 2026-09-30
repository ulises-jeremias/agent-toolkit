import { useLocation } from 'react-router';
import { useTerminalSessions } from '../data/terminal';
import { NewSessionDialog } from '../features/terminal/NewSessionDialog';
import { TerminalHost, TerminalTabs } from '../features/terminal/TerminalHost';
import { Button } from '../ui';
import styles from './shell.module.css';

type DockMode = 'hidden' | 'collapsed' | 'compact' | 'expanded';

function dockMode(pathname: string, available: boolean, sessionCount: number): DockMode {
  if (!available) return 'hidden';
  if (pathname === '/terminal') return sessionCount === 0 ? 'collapsed' : 'expanded';
  return sessionCount === 0 ? 'collapsed' : 'compact';
}

/**
 * Persistent terminal dock. xterm hosts live here so leaving Terminal never
 * tears a session down. The destination is chrome; the dock is the host.
 */
export function TerminalDock() {
  const location = useLocation();
  const { available, sessions, setCreating } = useTerminalSessions();
  const mode = dockMode(location.pathname, available, sessions.length);
  if (mode === 'hidden') return <NewSessionDialog />;

  return (
    <aside className={styles.dock} data-mode={mode} aria-label="Terminal dock">
      <div className={styles.dockBar}>
        <p className={styles.dockTitle}>Terminal</p>
        <div className={styles.dockTabs}>
          <TerminalTabs />
        </div>
        <Button size="sm" variant="ghost" onClick={() => setCreating(true)}>
          New session
        </Button>
      </div>
      {mode !== 'collapsed' ? <TerminalHost /> : null}
      <NewSessionDialog />
    </aside>
  );
}
