import { ErrorBoundary as ReactErrorBoundary } from 'react-error-boundary';
import { useState, type ReactNode } from 'react';
import styles from './ui.module.css';

/** Two-step destructive button: first click arms, second click fires. */
export function ConfirmButton({
  label,
  confirmLabel,
  onConfirm,
  disabled,
}: {
  label: string;
  confirmLabel: string;
  onConfirm: () => void;
  disabled?: boolean;
}) {
  const [armed, setArmed] = useState(false);
  if (!armed) {
    return (
      <button type="button" className={styles.buttonDanger} disabled={disabled} onClick={() => setArmed(true)}>
        {label}
      </button>
    );
  }
  return (
    <>
      <button
        type="button"
        className={styles.buttonDanger}
        disabled={disabled}
        onClick={() => {
          setArmed(false);
          onConfirm();
        }}
      >
        {confirmLabel}
      </button>
      <button type="button" className={styles.button} onClick={() => setArmed(false)}>
        Cancel
      </button>
    </>
  );
}

export function Panel({ title, actions, children }: { title: string; actions?: ReactNode; children: ReactNode }) {
  return (
    <section className={styles.panel} aria-label={title}>
      <header className={styles.panelHeader}>
        <h2 className={styles.panelTitle}>{title}</h2>
        {actions ? <div className={styles.panelActions}>{actions}</div> : null}
      </header>
      <div className={styles.panelBody}>{children}</div>
    </section>
  );
}

export function Loading({ label }: { label: string }) {
  return (
    <p className={styles.muted} role="status" aria-live="polite">
      {label}…
    </p>
  );
}

export function LoadError({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className={styles.error} role="alert">
      <p>{message}</p>
      {onRetry ? (
        <button type="button" className={styles.button} onClick={onRetry}>
          Retry
        </button>
      ) : null}
    </div>
  );
}

export function Empty({ message }: { message: string }) {
  return <p className={styles.muted}>{message}</p>;
}

export function StatusDot({ status }: { status: 'ok' | 'warn' | 'err' | 'idle' }) {
  return <span className={styles.dot} data-status={status} aria-label={`status ${status}`} role="img" />;
}

export function AppErrorFallback({ error, resetErrorBoundary }: { error: unknown; resetErrorBoundary: () => void }) {
  const message = error instanceof Error ? error.message : String(error);
  return (
    <div className={styles.error} role="alert">
      <h2>Something went wrong</h2>
      <p className={styles.muted}>{message}</p>
      <button type="button" className={styles.button} onClick={resetErrorBoundary}>
        Try again
      </button>
    </div>
  );
}

export function AppErrorBoundary({ children }: { children: ReactNode }) {
  return <ReactErrorBoundary FallbackComponent={AppErrorFallback}>{children}</ReactErrorBoundary>;
}
