import type { ReactNode } from 'react';
import { ErrorBoundary as ReactErrorBoundary } from 'react-error-boundary';
import { useLocation } from 'react-router';
import { errorMessage } from '../lib/api';
import { Button, Report } from './primitives';
import styles from './ui.module.css';

function Fallback({ name, error, reset }: { name: string; error: unknown; reset: () => void }) {
  return (
    <div className={styles.state} data-tone="err" role="alert">
      <p className={styles.stateTitle}>{name} stopped working</p>
      <p>The rest of the app still works. Other destinations and the terminal are unaffected.</p>
      <Report text={errorMessage(error)} label="Error detail" />
      <Button size="sm" onClick={reset}>
        Reload {name}
      </Button>
    </div>
  );
}

/** Contains a render failure to one destination; navigating away and back resets it. */
export function DestinationBoundary({ name, children }: { name: string; children: ReactNode }) {
  const location = useLocation();
  return (
    <ReactErrorBoundary
      resetKeys={[location.pathname]}
      fallbackRender={({ error, resetErrorBoundary }) => (
        <Fallback name={name} error={error} reset={resetErrorBoundary} />
      )}
    >
      {children}
    </ReactErrorBoundary>
  );
}

/** Last-resort boundary around the whole shell. */
export function AppErrorBoundary({ children }: { children: ReactNode }) {
  return (
    <ReactErrorBoundary
      fallbackRender={({ error, resetErrorBoundary }) => (
        <Fallback name="Agent Toolkit" error={error} reset={resetErrorBoundary} />
      )}
    >
      {children}
    </ReactErrorBoundary>
  );
}
