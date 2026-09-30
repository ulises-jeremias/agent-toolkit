import { useRef, useState } from 'react';
import { Link } from 'react-router';
import { useSubQuery } from '../data/commands';
import { useJob } from '../data/jobs';
import { hasContext, type ShellContextValue } from '../lib/context';
import { jobCommandLine } from '../lib/format';
import { Button, Dialog, Field, StatusBadge, TextInput, jobTone } from '../ui';
import { useShellContext } from './context';
import styles from './shell.module.css';

function WorkspaceValue({ ws }: { ws: string | null }) {
  const budget = useSubQuery('workspace', 'budget', ws ? { workspace: ws } : undefined);
  const resolved = budget.data?.data['workspace'];
  if (budget.isError) {
    return (
      <>
        {ws ? <span className={styles.contextPath}>{ws}</span> : null}
        <StatusBadge tone="err" label="Unavailable" />
      </>
    );
  }
  const path = resolved ?? ws;
  if (!path) return <span className={styles.contextMuted}>{budget.isPending ? 'Resolving…' : 'Backend default'}</span>;
  return (
    <span className={styles.contextPath} title={path}>
      {path}
    </span>
  );
}

function RunValue({ run }: { run: string }) {
  const { linkTo } = useShellContext();
  const job = useJob(run);
  return (
    <Link to={linkTo('/operations')} title={`Open job ${run} in Operations`}>
      {job ? (
        <>
          <span className={styles.contextPath}>{jobCommandLine(job)}</span>{' '}
          <StatusBadge tone={jobTone(job.status)} label={job.status} />
        </>
      ) : (
        <span className={styles.contextPath}>{run}</span>
      )}
    </Link>
  );
}

/**
 * The window's working context, read from the URL (`ws`, `agent`, `run`) so
 * it survives navigation, reload and copied links. Destinations read the same
 * params; this bar only shows and edits them.
 */
export function ContextBar({ onEdit }: { onEdit: () => void }) {
  const context = useShellContext();
  return (
    <section className={styles.contextBar} aria-label="Context">
      <dl className={styles.contextList}>
        <div className={styles.contextItem}>
          <dt className={styles.contextLabel}>Workspace</dt>
          <dd className={styles.contextValue}>
            <WorkspaceValue ws={context.ws} />
          </dd>
        </div>
        <div className={styles.contextItem}>
          <dt className={styles.contextLabel}>Agent</dt>
          <dd className={styles.contextValue}>{context.agent ?? <span className={styles.contextMuted}>Any</span>}</dd>
        </div>
        <div className={styles.contextItem}>
          <dt className={styles.contextLabel}>Run</dt>
          <dd className={styles.contextValue}>
            {context.run ? <RunValue run={context.run} /> : <span className={styles.contextMuted}>None</span>}
          </dd>
        </div>
      </dl>
      <div className={styles.contextActions}>
        <Button size="sm" variant="ghost" onClick={onEdit}>
          Edit context
        </Button>
        {hasContext(context) ? (
          <Button size="sm" variant="ghost" onClick={() => context.setContext({ ws: null, agent: null, run: null })}>
            Clear
          </Button>
        ) : null}
      </div>
    </section>
  );
}

export function ContextDialog({ open, onClose }: { open: boolean; onClose: () => void }) {
  const context = useShellContext();
  const [draft, setDraft] = useState<ShellContextValue>(context);
  const [wasOpen, setWasOpen] = useState(open);
  const firstRef = useRef<HTMLInputElement>(null);

  if (open !== wasOpen) {
    setWasOpen(open);
    if (open) setDraft({ ws: context.ws, agent: context.agent, run: context.run });
  }

  const field = (key: keyof ShellContextValue) => ({
    value: draft[key] ?? '',
    onChange: (event: { target: { value: string } }) =>
      setDraft((current) => ({ ...current, [key]: event.target.value })),
  });

  const apply = () => {
    context.setContext(draft);
    onClose();
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Context"
      description="Every destination and new terminal session uses this context. It lives in the address, so it survives reloads."
      initialFocus={firstRef}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="primary" type="submit" form="context-form">
            Apply
          </Button>
        </>
      }
    >
      <form
        id="context-form"
        onSubmit={(event) => {
          event.preventDefault();
          apply();
        }}
      >
        <Field label="Workspace folder" hint="Absolute path. Leave empty for the backend's own workspace.">
          {(control) => <TextInput ref={firstRef} mono {...control} {...field('ws')} placeholder="~/.ai-workspace" />}
        </Field>
        <Field label="Agent" hint="A label such as claude or reviewer; new terminal sessions take it.">
          {(control) => <TextInput {...control} {...field('agent')} />}
        </Field>
        <Field label="Run" hint="A job id from Operations.">
          {(control) => <TextInput mono {...control} {...field('run')} />}
        </Field>
      </form>
    </Dialog>
  );
}
