import { useEffect, useRef, useState } from 'react';
import { useTerminalSessions } from '../../data/terminal';
import { useSessionContext } from '../../shell/useSessionContext';
import { Button, Dialog, Field, TextInput } from '../../ui';
import styles from './terminal.module.css';

export function NewSessionDialog() {
  const { creating, setCreating, create } = useTerminalSessions();
  const { context } = useSessionContext();
  const [form, setForm] = useState({
    agent: context.agent || 'shell',
    cmd: '/bin/bash',
    args: '',
    cwd: context.workspace,
  });
  const cmdRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!creating) return;
    setForm({
      agent: context.agent || 'shell',
      cmd: '/bin/bash',
      args: '',
      cwd: context.workspace,
    });
  }, [creating, context.agent, context.workspace]);

  const submit = () => {
    if (!form.cmd.trim()) return;
    void create(
      {
        agent: form.agent.trim() || 'shell',
        cmd: form.cmd.trim(),
        args: form.args.split(/\s+/).filter(Boolean),
        cwd: form.cwd.trim() || undefined,
      },
      { run: context.run },
    );
    setCreating(false);
  };

  return (
    <Dialog
      open={creating}
      onClose={() => setCreating(false)}
      title="New terminal session"
      description="Starts a process in a pseudo-terminal on this machine."
      initialFocus={cmdRef}
      footer={
        <>
          <Button variant="ghost" onClick={() => setCreating(false)}>
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
        <Field label="Working folder" hint="Optional. Defaults to the current workspace.">
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
        <button type="submit" hidden />
      </form>
    </Dialog>
  );
}
