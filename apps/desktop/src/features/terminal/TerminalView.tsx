import { FitAddon } from '@xterm/addon-fit';
import { SearchAddon } from '@xterm/addon-search';
import { WebLinksAddon } from '@xterm/addon-web-links';
import { Terminal } from 'xterm';
import { useEffect, useRef, useState } from 'react';
import type { PtySessionInfo } from '../../types/electron';
import { Empty, Loading, Panel, StatusDot } from '../../components/ui';
import styles from './terminal.module.css';
import uiStyles from '../../components/ui.module.css';

/**
 * Terminal — first-class interactive surface over node-pty in Electron main.
 * Real PTY sessions: streaming output/input, resize, search, multiple tabs,
 * run identity, exit state, restart, signals, lifecycle cleanup.
 */
export default function TerminalView() {
  const bridge = typeof window !== 'undefined' ? window.atk : undefined;
  const [sessions, setSessions] = useState<PtySessionInfo[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [form, setForm] = useState({ agent: 'shell', cmd: '/bin/bash', args: '', cwd: '' });
  const [search, setSearch] = useState('');

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
    // Output reaches xterm via each TerminalPane's own onPtyData subscription
    // below; no view-level listener is needed here.
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
        <h1>Terminal</h1>
        <Panel title="Unavailable">
          <Empty message="Interactive terminals require the Electron shell (window.atk bridge). Run pnpm dev:electron instead of plain vite dev." />
        </Panel>
      </>
    );
  }

  const active = sessions.find((session) => session.id === activeId) ?? null;

  const create = async (): Promise<void> => {
    const created = await bridge.ptyCreate({
      agent: form.agent.trim() || 'shell',
      cmd: form.cmd.trim(),
      args: form.args.split(/\s+/).filter(Boolean),
      cwd: form.cwd.trim() || undefined,
      cols: 120,
      rows: 30,
    });
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
    const created = await bridge.ptyCreate({
      agent: session.agent,
      cmd: session.cmd,
      args: session.args,
      cwd: session.cwd,
      cols: session.cols,
      rows: session.rows,
    });
    if (created) {
      setSessions((list) => [...list, created]);
      setActiveId(created.id);
    }
  };

  return (
    <>
      <h1>Terminal</h1>
      <Panel title="New session">
        <form
          className={styles.form}
          onSubmit={(event) => {
            event.preventDefault();
            void create();
          }}
        >
          <label className={uiStyles.field}>
            <span>Run / agent identity</span>
            <input
              className={uiStyles.input}
              value={form.agent}
              onChange={(event) => setForm({ ...form, agent: event.target.value })}
              aria-label="Agent identity"
            />
          </label>
          <label className={uiStyles.field}>
            <span>Command</span>
            <input
              className={uiStyles.input}
              value={form.cmd}
              onChange={(event) => setForm({ ...form, cmd: event.target.value })}
              required
              aria-label="Command"
            />
          </label>
          <label className={uiStyles.field}>
            <span>Arguments (optional)</span>
            <input
              className={uiStyles.input}
              value={form.args}
              onChange={(event) => setForm({ ...form, args: event.target.value })}
              aria-label="Arguments"
            />
          </label>
          <label className={uiStyles.field}>
            <span>Working directory (optional)</span>
            <input
              className={uiStyles.input}
              value={form.cwd}
              onChange={(event) => setForm({ ...form, cwd: event.target.value })}
              aria-label="Working directory"
            />
          </label>
          <button type="submit" className={uiStyles.button}>
            Open terminal
          </button>
        </form>
      </Panel>
      {loading ? (
        <Loading label="Listing sessions" />
      ) : sessions.length === 0 ? (
        <Panel title="Sessions">
          <Empty message="No terminal sessions. Open one above — agent CLIs run interactively with full input." />
        </Panel>
      ) : (
        <section aria-label="Terminal sessions">
          <div className={styles.tabs} role="tablist" aria-label="Sessions">
            {sessions.map((session) => (
              <button
                key={session.id}
                type="button"
                role="tab"
                aria-selected={session.id === activeId}
                className={session.id === activeId ? styles.tabActive : styles.tab}
                onClick={() => setActiveId(session.id)}
              >
                <StatusDot status={session.exitCode === null ? 'ok' : session.exitCode === 0 ? 'idle' : 'err'} />{' '}
                {session.agent}
              </button>
            ))}
          </div>
          {active && (
            <TerminalPane
              key={active.id}
              session={active}
              search={search}
              onSearchChange={setSearch}
              onClose={() => void close(active.id)}
              onRestart={() => void restart(active)}
            />
          )}
        </section>
      )}
    </>
  );
}

function TerminalPane({
  session,
  search,
  onSearchChange,
  onClose,
  onRestart,
}: {
  session: PtySessionInfo;
  search: string;
  onSearchChange: (value: string) => void;
  onClose: () => void;
  onRestart: () => void;
}) {
  const bridge = window.atk;
  const containerRef = useRef<HTMLDivElement>(null);
  const termRef = useRef<Terminal | null>(null);
  const searchAddonRef = useRef<SearchAddon | null>(null);
  const [exitCode, setExitCode] = useState<number | null>(session.exitCode);

  useEffect(() => {
    if (!bridge || !containerRef.current) return;
    const term = new Terminal({
      theme: {
        background: '#1d1a12',
        foreground: '#ecdfc0',
        cursor: '#d9a83f',
        selectionBackground: 'rgba(217, 168, 63, 0.35)',
        black: '#1d1a12',
        red: '#c0563f',
        green: '#7d9b52',
        yellow: '#d9a83f',
        blue: '#6f9ab5',
        magenta: '#a87fa8',
        cyan: '#6fa89b',
        white: '#ecdfc0',
        brightBlack: '#5c5138',
        brightWhite: '#faf5e6',
      },
      fontFamily: "'Berkeley Mono', 'JetBrains Mono', ui-monospace, Menlo, monospace",
      fontSize: 13,
      allowProposedApi: true,
    });
    const fit = new FitAddon();
    const searchAddon = new SearchAddon();
    term.loadAddon(fit);
    term.loadAddon(searchAddon);
    term.loadAddon(new WebLinksAddon());
    term.open(containerRef.current);
    fit.fit();
    term.focus();
    termRef.current = term;
    searchAddonRef.current = searchAddon;

    // Catch up on output buffered before this pane mounted (prompt, early
    // output) or while another tab was active. Subscribe first so nothing
    // emitted during the tail fetch is lost; chunks racing the fetch may
    // duplicate one boundary line under heavy output — accepted over loss.
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
    const onWindowResize = (): void => {
      try {
        fit.fit();
      } catch {
        // terminal closed mid-resize
      }
    };
    window.addEventListener('resize', onWindowResize);

    return () => {
      window.removeEventListener('resize', onWindowResize);
      offData();
      offExit();
      onData.dispose();
      onResize.dispose();
      term.dispose();
      termRef.current = null;
    };
  }, [bridge, session.id]);

  useEffect(() => {
    if (search) searchAddonRef.current?.findNext(search);
  }, [search]);

  const exited = exitCode !== null;
  const commandLine = [session.cmd, ...session.args].join(' ');

  return (
    <div className={styles.chrome}>
      <div className={styles.chromeBar}>
        <span className={styles.chromeTitle} title={commandLine}>
          {session.agent} · {commandLine} · {session.cwd}
        </span>
        {exited && (
          <span role="status">
            exited {exitCode}{' '}
            <button type="button" className={uiStyles.button} onClick={onRestart}>
              Restart
            </button>
          </span>
        )}
        <label className={styles.search}>
          <span>Search</span>
          <input value={search} onChange={(event) => onSearchChange(event.target.value)} aria-label="Search terminal" />
        </label>
        <button
          type="button"
          className={uiStyles.button}
          disabled={exited}
          onClick={() => bridge && void bridge.ptySignal(session.id, 'int')}
          title="Send Ctrl-C (SIGINT)"
        >
          Ctrl-C
        </button>
        <button
          type="button"
          className={uiStyles.button}
          disabled={exited}
          onClick={() => bridge && void bridge.ptySignal(session.id, 'term')}
          title="Terminate (SIGTERM)"
        >
          Terminate
        </button>
        <button type="button" className={uiStyles.buttonDanger} onClick={onClose} title="Kill and close session">
          Close
        </button>
      </div>
      <div
        ref={containerRef}
        className={styles.viewport}
        role="log"
        aria-label={`Terminal output for ${session.agent}`}
      />
    </div>
  );
}
