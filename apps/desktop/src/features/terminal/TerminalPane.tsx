import { FitAddon } from '@xterm/addon-fit';
import { SearchAddon } from '@xterm/addon-search';
import { WebLinksAddon } from '@xterm/addon-web-links';
import { Terminal } from '@xterm/xterm';
import '@xterm/xterm/css/xterm.css';
import { useEffect, useRef, useState } from 'react';
import { TERMINAL_OPTIONS } from '../../design/terminalTheme';
import type { PtyExitEvent, PtySessionInfo } from '../../types/electron';
import { Button, ConfirmAction, StatusBadge } from '../../ui';
import { sessionState } from './sessionState';
import styles from './terminal.module.css';

/**
 * One xterm instance. The parent keeps this mounted for the life of the
 * session so destination changes never dispose the PTY view.
 */
export function TerminalPane({
  session,
  run,
  onClose,
  onRestart,
}: {
  session: PtySessionInfo;
  run?: string;
  onClose: () => void;
  onRestart: () => void;
}) {
  const bridge = window.atk;
  const containerRef = useRef<HTMLDivElement>(null);
  const searchAddonRef = useRef<SearchAddon | null>(null);
  const [exitCode, setExitCode] = useState<number | null>(session.exitCode);
  const [exitReason, setExitReason] = useState<PtyExitEvent['exitReason']>(session.exitReason);
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
      if (event.id === session.id) {
        setExitCode(event.exitCode);
        setExitReason(event.exitReason);
      }
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
  const state = sessionState(exitCode, exitReason);
  const commandLine = [session.cmd, ...session.args].join(' ');

  return (
    <div className={styles.chrome} role="tabpanel" aria-label={session.agent}>
      <div className={styles.chromeBar}>
        <div className={styles.identity}>
          <StatusBadge tone={state.tone} label={state.label} />
          <span className={styles.chromeTitle} title={`${commandLine} in ${session.cwd}`}>
            <span className={styles.chromeCmd}>
              {session.agent}
              {run ? ` · ${run}` : ''}
              {` · ${commandLine}`}
            </span>
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
          {exitReason === 'time-budget'
            ? `The configured ${session.maxSeconds}s time limit ended this process.`
            : `The process ended with exit code ${exitCode}.`}{' '}
          Output is kept until you close or restart the session.
        </p>
      ) : null}
      <div ref={containerRef} className={styles.viewport} aria-label={`Terminal for ${session.agent}`} />
    </div>
  );
}
