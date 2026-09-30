import { useState, type FormEvent, type KeyboardEvent } from 'react';
import { Link } from 'react-router';
import { useBackend } from '../data/backend';
import { Kbd, Mono } from '../ui';
import { openCommandPalette } from './CommandPalette';
import { basename } from './sessionContext';
import { useSessionContext } from './useSessionContext';
import styles from './shell.module.css';

function Field({
  label,
  value,
  placeholder,
  mono,
  title,
  onCommit,
}: {
  label: string;
  value: string;
  placeholder: string;
  mono?: boolean;
  title?: string;
  onCommit: (next: string) => void;
}) {
  const [draft, setDraft] = useState<string | null>(null);
  const shown = draft ?? value;
  const commit = () => {
    if (draft === null) return;
    onCommit(draft);
    setDraft(null);
  };
  return (
    <label className={styles.contextField} title={(title ?? value) || undefined}>
      <span className={styles.contextLabel}>{label}</span>
      <input
        className={styles.contextInput}
        data-mono={mono || undefined}
        value={shown}
        placeholder={placeholder}
        spellCheck={false}
        onFocus={() => setDraft(value)}
        onChange={(event) => setDraft(event.target.value)}
        onBlur={commit}
        onKeyDown={(event: KeyboardEvent<HTMLInputElement>) => {
          if (event.key === 'Enter') {
            event.preventDefault();
            commit();
            event.currentTarget.blur();
          }
          if (event.key === 'Escape') {
            setDraft(null);
            event.currentTarget.blur();
          }
        }}
      />
    </label>
  );
}

/** Persistent workspace / agent / run bar. Values are URL search params. */
export function ContextBar() {
  const { backend } = useBackend();
  const { context, setContext, href } = useSessionContext();
  const harness = backend?.harness ?? null;

  const onWorkspace = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
  };

  return (
    <form className={styles.contextBar} aria-label="Session context" onSubmit={onWorkspace}>
      <Field
        label="Workspace"
        value={context.workspace}
        placeholder={harness?.path || 'No workspace'}
        mono
        title={
          harness
            ? `${context.workspace || harness.path} (${harness.source}${harness.overrideVar ? ` via ${harness.overrideVar}` : ''})`
            : context.workspace || undefined
        }
        onCommit={(workspace) => setContext({ workspace })}
      />
      {harness ? (
        <span className={styles.contextMeta} data-tone={harness.notice ? 'warn' : undefined}>
          <Mono>{basename(harness.path)}</Mono>
          <span>{harness.source}</span>
          {harness.notice ? (
            <Link to={href('/settings')} title={harness.notice}>
              notice
            </Link>
          ) : null}
        </span>
      ) : null}
      <Field label="Agent" value={context.agent} placeholder="Any agent" onCommit={(agent) => setContext({ agent })} />
      <Field label="Run" value={context.run} placeholder="No run" mono onCommit={(run) => setContext({ run })} />
      <button type="button" className={styles.contextHint} onClick={openCommandPalette} aria-haspopup="dialog">
        <Kbd keys={['Ctrl', 'K']} />
        <span>Commands</span>
      </button>
    </form>
  );
}
