import { useRef, useState } from 'react';
import type { PtyCreateOptions } from '../../types/electron';
import { Button, Dialog, Field, TextInput } from '../../ui';
import styles from './terminal.module.css';

export interface SessionDefaults {
  agent: string | null;
  cwd: string | null;
  run: string | null;
}

const DEFAULT_SHELL = '/bin/bash';

/** Opens a PTY session; defaults come from the shell context (agent, workspace, run). */
export function NewSessionDialog({
  open,
  defaults,
  onClose,
  onCreate,
}: {
  open: boolean;
  defaults: SessionDefaults;
  onClose: () => void;
  onCreate: (options: PtyCreateOptions) => void;
}) {
  const initial = () => ({
    agent: defaults.agent ?? 'shell',
    cmd: DEFAULT_SHELL,
    args: '',
    cwd: defaults.cwd ?? '',
    run: defaults.run ?? '',
  });
  const [form, setForm] = useState(initial);
  const [wasOpen, setWasOpen] = useState(open);
  const cmdRef = useRef<HTMLInputElement>(null);

  // Reset to the current defaults each time the dialog opens.
  if (open !== wasOpen) {
    setWasOpen(open);
    if (open) setForm(initial());
  }

  const submit = () => {
    if (!form.cmd.trim()) return;
    onCreate({
      agent: form.agent.trim() || 'shell',
      run: form.run.trim() || undefined,
      cmd: form.cmd.trim(),
      args: form.args.split(/\s+/).filter(Boolean),
      cwd: form.cwd.trim() || undefined,
    });
    onClose();
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="New terminal session"
      description="Starts a process in a pseudo-terminal on this machine."
      initialFocus={cmdRef}
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="primary" onClick={submit} disabled={form.cmd.trim() === ''}>
            Open session
          </Button>
        </>
      }
    >
      <form
        className={styles.form}
        onSubmit={(event) => {
          event.preventDefault();
          submit();
        }}
      >
        <Field label="Command">
          {(control) => (
            <TextInput
              ref={cmdRef}
              mono
              value={form.cmd}
              onChange={(event) => setForm({ ...form, cmd: event.target.value })}
              required
              {...control}
            />
          )}
        </Field>
        <Field label="Arguments" hint="Separated by spaces. Optional.">
          {(control) => (
            <TextInput
              mono
              value={form.args}
              onChange={(event) => setForm({ ...form, args: event.target.value })}
              {...control}
            />
          )}
        </Field>
        <Field label="Working folder" hint="Optional. Defaults to the Desktop's working folder.">
          {(control) => (
            <TextInput
              mono
              value={form.cwd}
              onChange={(event) => setForm({ ...form, cwd: event.target.value })}
              {...control}
            />
          )}
        </Field>
        <Field label="Label" hint="Shown on the tab, for example the agent this session runs.">
          {(control) => (
            <TextInput
              value={form.agent}
              onChange={(event) => setForm({ ...form, agent: event.target.value })}
              {...control}
            />
          )}
        </Field>
        <Field label="Run" hint="Optional job id this session belongs to. Shown on the tab.">
          {(control) => (
            <TextInput
              mono
              value={form.run}
              onChange={(event) => setForm({ ...form, run: event.target.value })}
              {...control}
            />
          )}
        </Field>
        <button type="submit" hidden />
      </form>
    </Dialog>
  );
}
