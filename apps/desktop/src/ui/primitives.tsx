import {
  forwardRef,
  useId,
  type ButtonHTMLAttributes,
  type InputHTMLAttributes,
  type ReactNode,
  type SelectHTMLAttributes,
} from 'react';
import { errorMessage, recoveryHint } from '../lib/api';
import styles from './ui.module.css';

export type Tone = 'ok' | 'warn' | 'err' | 'info' | 'idle';

// ---------- Button ----------

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger';

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: 'sm' | 'md';
  /** Shows the pending label and disables the button while an action runs. */
  busy?: boolean;
  busyLabel?: string;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'secondary', size = 'md', busy = false, busyLabel, disabled, children, type = 'button', ...rest },
  ref,
) {
  return (
    <button
      ref={ref}
      type={type}
      className={styles.button}
      data-variant={variant}
      data-size={size}
      disabled={disabled || busy}
      aria-busy={busy || undefined}
      {...rest}
    >
      {busy && busyLabel ? busyLabel : children}
    </button>
  );
});

export function ButtonRow({ children }: { children: ReactNode }) {
  return <div className={styles.buttonRow}>{children}</div>;
}

// ---------- Page structure ----------

export function PageHeader({
  eyebrow,
  title,
  lede,
  actions,
  surface = 'canvas',
}: {
  eyebrow?: string;
  title: string;
  lede?: ReactNode;
  actions?: ReactNode;
  /** Text contrast ramp matching the surface behind this header. */
  surface?: 'canvas' | 'panel';
}) {
  return (
    <header className={styles.pageHeader} data-surface={surface}>
      <div>
        {eyebrow ? <p className={styles.eyebrow}>{eyebrow}</p> : null}
        <h1 className={styles.pageTitle}>{title}</h1>
        {lede ? <p className={styles.lede}>{lede}</p> : null}
      </div>
      {actions ? <div className={styles.buttonRow}>{actions}</div> : null}
    </header>
  );
}

/**
 * A titled section. `paper` is the default reading surface; `manila` is a
 * filed folder for the one area on a page that holds work to act on.
 */
export function Panel({
  title,
  meta,
  actions,
  tone = 'menu',
  headingLevel = 2,
  children,
}: {
  title: string;
  meta?: ReactNode;
  actions?: ReactNode;
  tone?: 'menu' | 'notice';
  headingLevel?: 2 | 3;
  children: ReactNode;
}) {
  const headingId = useId();
  const Heading = headingLevel === 2 ? 'h2' : 'h3';
  return (
    <section className={styles.panel} data-tone={tone} aria-labelledby={headingId}>
      <header className={styles.panelHeader}>
        <div>
          <Heading id={headingId} className={styles.panelTitle}>
            {title}
          </Heading>
          {meta ? <p className={styles.panelMeta}>{meta}</p> : null}
        </div>
        {actions ? <div className={styles.buttonRow}>{actions}</div> : null}
      </header>
      <div className={styles.panelBody}>{children}</div>
    </section>
  );
}

export function Stack({ children }: { children: ReactNode }) {
  return <div className={styles.stack}>{children}</div>;
}

export function Grid({ children }: { children: ReactNode }) {
  return <div className={styles.grid}>{children}</div>;
}

// ---------- Data display ----------

/** Editorial table: hairline rules, caps headers, tabular numbers. Callers write thead/tbody. */
export function Table({ caption, children }: { caption?: string; children: ReactNode }) {
  return (
    <div className={styles.tableWrap}>
      <table className={styles.table}>
        {caption ? <caption>{caption}</caption> : null}
        {children}
      </table>
    </div>
  );
}

export function KeyValue({ items }: { items: ReadonlyArray<{ label: string; value: ReactNode; mono?: boolean }> }) {
  return (
    <dl className={styles.keyValue}>
      {items.map((item) => (
        <div key={item.label} style={{ display: 'contents' }}>
          <dt>{item.label}</dt>
          <dd className={item.mono ? styles.mono : undefined}>{item.value}</dd>
        </div>
      ))}
    </dl>
  );
}

/** Status is always a word; tone adds colour and a distinct shape, never replaces the word. */
export function StatusBadge({ tone, label, live = false }: { tone: Tone; label: string; live?: boolean }) {
  return (
    <span className={styles.badge} data-tone={tone} data-live={live || undefined}>
      {label}
    </span>
  );
}

export function Mono({ children }: { children: ReactNode }) {
  return <span className={styles.mono}>{children}</span>;
}

/**
 * Multi-line command output, shown verbatim until the route has a typed
 * schema. Chromium makes overflowing scrollers keyboard-focusable itself.
 */
export function Report({ text, label }: { text: string; label?: string }) {
  return (
    <pre className={styles.report} aria-label={label}>
      {text}
    </pre>
  );
}

// ---------- Keyboard ----------

export function Kbd({ keys }: { keys: readonly string[] }) {
  return (
    <span className={styles.kbdGroup}>
      {keys.map((key) => (
        <kbd key={key} className={styles.kbd}>
          {key}
        </kbd>
      ))}
    </span>
  );
}

// ---------- Fields ----------

export interface FieldControlProps {
  id: string;
  'aria-describedby': string | undefined;
  'aria-invalid': boolean | undefined;
}

/** Label, hint and error wired to one control through ids. */
export function Field({
  label,
  hint,
  error,
  children,
}: {
  label: string;
  hint?: ReactNode;
  error?: string | null;
  children: (control: FieldControlProps) => ReactNode;
}) {
  const id = useId();
  const hintId = `${id}-hint`;
  const errorId = `${id}-error`;
  const describedBy = [hint ? hintId : null, error ? errorId : null].filter(Boolean).join(' ') || undefined;
  return (
    <div className={styles.field}>
      <label className={styles.fieldLabel} htmlFor={id}>
        {label}
      </label>
      {children({ id, 'aria-describedby': describedBy, 'aria-invalid': error ? true : undefined })}
      {hint ? (
        <p id={hintId} className={styles.fieldHint}>
          {hint}
        </p>
      ) : null}
      {error ? (
        <p id={errorId} className={styles.fieldError}>
          {error}
        </p>
      ) : null}
    </div>
  );
}

export const TextInput = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement> & { mono?: boolean }>(
  function TextInput({ mono = false, className, ...rest }, ref) {
    return (
      <input
        ref={ref}
        className={[styles.input, mono ? styles.inputMono : '', className ?? ''].filter(Boolean).join(' ')}
        {...rest}
      />
    );
  },
);

export function Select(props: SelectHTMLAttributes<HTMLSelectElement>) {
  return <select className={styles.input} {...props} />;
}

export function FormRow({ children }: { children: ReactNode }) {
  return <div className={styles.formRow}>{children}</div>;
}

// ---------- States ----------

export function LoadingState({ label }: { label: string }) {
  return (
    <p className={styles.muted} role="status" aria-live="polite">
      {label}…
    </p>
  );
}

export function EmptyState({ title, children }: { title: string; children?: ReactNode }) {
  return (
    <div className={styles.state}>
      <p className={styles.stateTitle}>{title}</p>
      {children ? <div className={styles.stateHint}>{children}</div> : null}
    </div>
  );
}

/** A failed read: what failed, the server's words, and the next action. */
export function ErrorState({
  title = 'Could not load this',
  error,
  onRetry,
  guidance,
  retryLabel = 'Try again',
}: {
  title?: string;
  error: unknown;
  onRetry?: () => void;
  guidance?: string;
  retryLabel?: string;
}) {
  const message = errorMessage(error);
  return (
    <div className={styles.state} data-tone="err" role="alert">
      <p className={styles.stateTitle}>{title}</p>
      {message.includes('\n') ? <Report text={message} label="Error output" /> : <p>{message}</p>}
      <p className={styles.stateHint}>{guidance ?? recoveryHint(error)}</p>
      {onRetry ? (
        <Button size="sm" onClick={onRetry}>
          {retryLabel}
        </Button>
      ) : null}
    </div>
  );
}

export function VisuallyHidden({ children }: { children: ReactNode }) {
  return <span className={styles.srOnly}>{children}</span>;
}
