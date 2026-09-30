import { FitAddon } from '@xterm/addon-fit';
import { SearchAddon } from '@xterm/addon-search';
import { WebLinksAddon } from '@xterm/addon-web-links';
import { Terminal } from '@xterm/xterm';
import '@xterm/xterm/css/xterm.css';
import { useEffect, useRef, useState } from 'react';
import { TERMINAL_OPTIONS } from '../../design/terminalTheme';
import { isReservedChord } from '../../lib/shortcuts';
import type { PtySessionInfo } from '../../types/electron';
import { Button, ConfirmAction, StatusBadge, type Tone } from '../../ui';
import styles from './terminal.module.css';

export function sessionState(exitCode: number | null): { tone: Tone; label: string } {
  if (exitCode === null) return { tone: 'ok', label: 'running' };
  return exitCode === 0 ? { tone: 'idle', label: 'exited 0' } : { tone: 'err', label: `exited ${exitCode}` };
}

export function basename(path: string): string {
  const trimmed = path.replace(/[/\\]+$/, '');
  return trimmed.split(/[/\\]/).pop() || trimmed || path;
}

/**
 * One xterm bound to one PTY session. Mounted once per session by the dock
 * and kept alive while hidden, so switching tabs or destinations never loses
 * scrollback or input state.
 */
export function TerminalPane({
  session,
  tabId,
  panelId,
  active,
  visible,
  onClose,
  onRestart,
}: {
  session: PtySessionInfo;
  tabId: string;
  panelId: string;
  /** Selected tab in the dock. */
  active: boolean;
  /** The dock itself is on screen. */
  visible: boolean;
  onClose: () => void;
  onRestart: () => void;
}) {
  const bridge = window.atk;
  const containerRef = useRef<HTMLDivElement>(null);
  const termRef = useRef<Terminal | null>(null);
  const searchAddonRef = useRef<SearchAddon | null>(null);
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
    // App-level chords (palette, dock, destinations) never reach the PTY.
    term.attachCustomKeyEventHandler((event) => !isReservedChord(event));
    term.open(container);
    termRef.current = term;
    searchAddonRef.current = searchAddon;

    // A collapsed dock has no height; fitting then would shrink the PTY to
    // one row and make full-screen programs redraw.
    const fitIfSized = () => {
      if (container.clientWidth === 0 || container.clientHeight === 0) return;
      try {
        fit.fit();
      } catch {
        // terminal disposed mid-resize
      }
    };
    fitIfSized();

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
    const onData = term.onData((data) => {
      void bridge.ptyWrite(session.id, data);
    });
    const onResize = term.onResize(({ cols, rows }) => {
      void bridge.ptyResize(session.id, cols, rows);
    });
    const observer = new ResizeObserver(fitIfSized);
    observer.observe(container);

    return () => {
      observer.disconnect();
      offData();
      onData.dispose();
      onResize.dispose();
      term.dispose();
      termRef.current = null;
    };
  }, [bridge, session.id]);

  useEffect(() => {
    if (active && visible) termRef.current?.focus();
  }, [active, visible]);

  useEffect(() => {
    if (search) searchAddonRef.current?.findNext(search);
  }, [search]);

  const exited = session.exitCode !== null;
  const state = sessionState(session.exitCode);
  const commandLine = [session.cmd, ...session.args].join(' ');

  return (
    <div
      id={panelId}
      className={styles.chrome}
      role="tabpanel"
      aria-labelledby={tabId}
      data-active={active}
      inert={!active || undefined}
    >
      <div className={styles.chromeBar}>
        <div className={styles.identity}>
          <StatusBadge tone={state.tone} label={state.label} />
          <span className={styles.chromeTitle} title={`${commandLine} in ${session.cwd}`}>
            <span className={styles.chromeCmd}>{commandLine}</span>
            <span className={styles.chromeCwd}>
              {session.cwd}
              {session.run ? ` · run ${session.run}` : ''}
            </span>
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
          The process ended with exit code {session.exitCode}. Output is kept until you close or restart the session.
        </p>
      ) : null}
      <div ref={containerRef} className={styles.viewport} aria-label={`Terminal for ${session.agent}`} />
    </div>
  );
}
