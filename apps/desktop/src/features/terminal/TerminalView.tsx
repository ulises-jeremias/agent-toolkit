import { FitAddon } from '@xterm/addon-fit';
import { SearchAddon } from '@xterm/addon-search';
import { WebLinksAddon } from '@xterm/addon-web-links';
import { Terminal } from '@xterm/xterm';
import '@xterm/xterm/css/xterm.css';
import { useEffect, useRef, useState } from 'react';
import { TERMINAL_OPTIONS } from '../../design/terminalTheme';
import type { PtySessionInfo } from '../../types/electron';
import {
  Button,
  ConfirmAction,
  Dialog,
  EmptyState,
  Field,
  LoadingState,
  PageHeader,
  Panel,
  StatusBadge,
  TextInput,
  type Tone,
} from '../../ui';
import styles from './terminal.module.css';

function sessionState(exitCode: number | null): { tone: Tone; label: string } {
  if (exitCode === null) return { tone: 'ok', label: 'running' };
  return exitCode === 0 ? { tone: 'idle', label: 'exited 0' } : { tone: 'err', label: `exited ${exitCode}` };
}

/**
 * Terminal: interactive PTY sessions over node-pty in the Electron main
 * process. Streaming output and input, resize, search, tabs, exit state,
 * restart and signals.
 */
export default function TerminalView() {
  const bridge = typeof window !== 'undefined' ? window.atk : undefined;
  const [sessions, setSessions] = useState<PtySessionInfo[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [creating, setCreating] = useState(false);

  useEffect(() => {
    if (!bridge) {
      setLoading(false);
      return;
    }
    let cancelled = false;
    void bridge.ptyList().then((list) => {
      if (cancelled) return;
      setSessions(list);
      setActiveId((current) => current ?? list[0]?.id ?? null);
      setLoading(false);
    });
    const offExit = bridge.onPtyExit(() => {
      void bridge.ptyList().then((list) => {
        if (!cancelled) setSessions(list);
      });
    });
    return () => {
      cancelled = true;
      offExit();
    };
  }, [bridge]);

  if (!bridge) {
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

  const active = sessions.find((session) => session.id === activeId) ?? null;

  const create = async (options: { agent: string; cmd: string; args: string[]; cwd?: string }): Promise<void> => {
    const created = await bridge.ptyCreate({ ...options, cols: 120, rows: 30 });
    if (created) {
      setSessions((list) => [...list, created]);
      setActiveId(created.id);
    }
  };

  const close = async (id: string): Promise<void> => {
    await bridge.ptyClose(id);
    setSessions((list) => {
      const rest = list.filter((session) => session.id !== id);
      setActiveId((current) => (current === id ? (rest[0]?.id ?? null) : current));
      return rest;
    });
  };

  const restart = async (session: PtySessionInfo): Promise<void> => {
    await bridge.ptyClose(session.id);
    setSessions((list) => list.filter((item) => item.id !== session.id));
    await create({ agent: session.agent, cmd: session.cmd, args: session.args, cwd: session.cwd });
  };

  return (
    <div className={styles.page}>
      <PageHeader
        eyebrow="Terminal"
        title="Sessions"
        actions={
          <Button variant="primary" onClick={() => setCreating(true)}>
            New session
          </Button>
        }
      />
      <NewSessionDialog open={creating} onClose={() => setCreating(false)} onCreate={create} />
      {loading ? (
        <LoadingState label="Listing sessions" />
      ) : sessions.length === 0 ? (
        <Panel title="No sessions">
          <EmptyState title="No terminal is open.">
            Open a session to run a shell or an agent CLI with full interactive input.
          </EmptyState>
        </Panel>
      ) : (
        <section className={styles.sessions} aria-label="Terminal sessions">
          <div className={styles.tabs} role="tablist" aria-label="Sessions">
            {sessions.map((session) => {
              const state = sessionState(session.exitCode);
              return (
                <button
                  key={session.id}
                  type="button"
                  role="tab"
                  aria-selected={session.id === activeId}
                  className={styles.tab}
                  onClick={() => setActiveId(session.id)}
                >
                  <span className={styles.tabAgent}>{session.agent}</span>
                  <span className={styles.tabState} data-tone={state.tone}>
                    {state.label}
                  </span>
                </button>
              );
            })}
          </div>
          {active ? (
            <TerminalPane
              key={active.id}
              session={active}
              onClose={() => void close(active.id)}
              onRestart={() => void restart(active)}
            />
          ) : null}
        </section>
      )}
    </div>
  );
}

function NewSessionDialog({
  open,
  onClose,
  onCreate,
}: {
  open: boolean;
  onClose: () => void;
  onCreate: (options: { agent: string; cmd: string; args: string[]; cwd?: string }) => Promise<void>;
}) {
  const [form, setForm] = useState({ agent: 'shell', cmd: '/bin/bash', args: '', cwd: '' });
  const cmdRef = useRef<HTMLInputElement>(null);
  const submit = () => {
    if (!form.cmd.trim()) return;
    void onCreate({
      agent: form.agent.trim() || 'shell',
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
        <button type="submit" hidden />
      </form>
    </Dialog>
  );
}

function TerminalPane({
  session,
  onClose,
  onRestart,
}: {
  session: PtySessionInfo;
  onClose: () => void;
  onRestart: () => void;
}) {
  const bridge = window.atk;
  const containerRef = useRef<HTMLDivElement>(null);
  const searchAddonRef = useRef<SearchAddon | null>(null);
  const [exitCode, setExitCode] = useState<number | null>(session.exitCode);
  const [search, setSearch] = useState('');

  useEffect(() => {
    const container = containerRef.current;
    if (!bridge || !container) return;
    const term = new Terminal(TERMINAL_OPTIONS);
    const fit = new FitAddon();
    const searchAddon = new SearchAddon();
    term.loadAddon(fit);
    term.loadAddon(searchAddon);
    term.loadAddon(new WebLinksAddon());
    term.open(container);
    fit.fit();
    term.focus();
    searchAddonRef.current = searchAddon;

    // Subscribe before fetching the tail so nothing emitted meanwhile is lost.
    let caughtUp = false;
    const pending: string[] = [];
    const offData = bridge.onPtyData((event) => {
      if (event.id !== session.id) return;
      if (caughtUp) term.write(event.chunk);
      else pending.push(event.chunk);
    });
    void bridge
      .ptyTail(session.id)
      .then((tail) => {
        if (tail) term.write(tail);
        for (const chunk of pending) term.write(chunk);
        pending.length = 0;
        caughtUp = true;
      })
      .catch(() => {
        caughtUp = true;
      });
    const offExit = bridge.onPtyExit((event) => {
      if (event.id === session.id) setExitCode(event.exitCode);
    });
    const onData = term.onData((data) => {
      void bridge.ptyWrite(session.id, data);
    });
    const onResize = term.onResize(({ cols, rows }) => {
      void bridge.ptyResize(session.id, cols, rows);
    });
    const observer = new ResizeObserver(() => {
      try {
        fit.fit();
      } catch {
        // terminal disposed mid-resize
      }
    });
    observer.observe(container);

    return () => {
      observer.disconnect();
      offData();
      offExit();
      onData.dispose();
      onResize.dispose();
      term.dispose();
    };
  }, [bridge, session.id]);

  useEffect(() => {
    if (search) searchAddonRef.current?.findNext(search);
  }, [search]);

  const exited = exitCode !== null;
  const state = sessionState(exitCode);
  const commandLine = [session.cmd, ...session.args].join(' ');

  return (
    <div className={styles.chrome} role="tabpanel" aria-label={session.agent}>
      <div className={styles.chromeBar}>
        <div className={styles.identity}>
          <StatusBadge tone={state.tone} label={state.label} />
          <span className={styles.chromeTitle} title={`${commandLine} in ${session.cwd}`}>
            <span className={styles.chromeCmd}>{commandLine}</span>
            <span className={styles.chromeCwd}>{session.cwd}</span>
          </span>
        </div>
        <div className={styles.controls}>
          <label className={styles.search}>
            <span className={styles.searchLabel}>Find</span>
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              aria-label="Find in terminal output"
            />
          </label>
          {exited ? (
            <Button size="sm" onClick={onRestart}>
              Restart
            </Button>
          ) : (
            <>
              <Button
                size="sm"
                variant="ghost"
                onClick={() => void bridge?.ptySignal(session.id, 'int')}
                title="Send SIGINT"
              >
                Interrupt
              </Button>
              <Button
                size="sm"
                variant="ghost"
                onClick={() => void bridge?.ptySignal(session.id, 'term')}
                title="Send SIGTERM"
              >
                Terminate
              </Button>
            </>
          )}
          <ConfirmAction
            label="Close"
            title="Close this session?"
            description={
              exited
                ? 'The session and its scrollback are discarded.'
                : 'The process is killed and its scrollback is discarded.'
            }
            confirmLabel={exited ? 'Close session' : 'Kill and close'}
            triggerVariant="ghost"
            onConfirm={onClose}
          />
        </div>
      </div>
      {exited ? (
        <p className={styles.exitNotice} role="status">
          The process ended with exit code {exitCode}. Output is kept until you close or restart the session.
        </p>
      ) : null}
      <div ref={containerRef} className={styles.viewport} aria-label={`Terminal for ${session.agent}`} />
    </div>
  );
}
