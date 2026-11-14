import { FitAddon } from '@xterm/addon-fit';
import { Terminal } from '@xterm/xterm';
import '@xterm/xterm/css/xterm.css';
import { useCallback, useEffect, useRef, useState } from 'react';
import { TERMINAL_OPTIONS } from '../../design/terminalTheme';
import type { PtyExitEvent } from '../../types/electron';
import { Button, Dialog } from '../../ui';
import styles from './focus.module.css';
import type { ProviderSignInSession } from './useProviderSignIn';

export function ProviderSignInDialog({
  session,
  onClose,
}: {
  session: ProviderSignInSession | null;
  onClose: (session: ProviderSignInSession | null) => void | Promise<void>;
}) {
  const bridge = window.atk;
  const containerRef = useRef<HTMLDivElement>(null);
  const [exit, setExit] = useState<PtyExitEvent | null>(null);
  const [closing, setClosing] = useState(false);
  const closingRef = useRef(false);

  const sessionId = session?.sessionId;

  useEffect(() => {
    if (!sessionId) return;
    return () => {
      // Covers route changes and renderer-side unmounts even if no dialog
      // button could run its close path.
      void bridge?.providerSignInFinish(sessionId);
    };
  }, [bridge, sessionId]);
  const dismiss = useCallback(() => {
    if (closingRef.current) return;
    closingRef.current = true;
    setClosing(true);
    void Promise.resolve(onClose(session)).finally(() => {
      closingRef.current = false;
      setClosing(false);
      setExit(null);
    });
  }, [onClose, session]);

  useEffect(() => {
    if (!session || !bridge || !containerRef.current) return;
    const terminal = new Terminal({ ...TERMINAL_OPTIONS, screenReaderMode: true });
    const fit = new FitAddon();
    terminal.loadAddon(fit);
    terminal.open(containerRef.current);
    fit.fit();
    terminal.focus();
    let caughtUp = false;
    const pending: string[] = [];
    const offData = bridge.onPtyData((event) => {
      if (event.id !== session.sessionId) return;
      if (caughtUp) terminal.write(event.chunk);
      else pending.push(event.chunk);
    });
    const offExit = bridge.onPtyExit((event) => {
      if (event.id === session.sessionId) setExit(event);
    });
    const input = terminal.onData((data) => void bridge.ptyWrite(session.sessionId, data));
    const resize = terminal.onResize(({ cols, rows }) => void bridge.ptyResize(session.sessionId, cols, rows));
    const observer = new ResizeObserver(() => {
      try {
        fit.fit();
      } catch {
        // Dialog is closing while the viewport changes size.
      }
    });
    observer.observe(containerRef.current);
    void bridge.ptyTail(session.sessionId).then((tail) => {
      if (tail) terminal.write(tail);
      pending.forEach((chunk) => terminal.write(chunk));
      pending.length = 0;
      caughtUp = true;
    });
    return () => {
      observer.disconnect();
      offData();
      offExit();
      input.dispose();
      resize.dispose();
      terminal.dispose();
    };
  }, [bridge, session]);

  return (
    <Dialog
      open={session !== null}
      onClose={dismiss}
      title={session ? `Sign in to ${session.provider === 'claude' ? 'Claude Code' : 'Codex'}` : 'Provider sign-in'}
      description="Closing stops sign-in. Terminal output stays in memory while this dialog is open, then is discarded instead of being saved to session history."
      size="wide"
      closeDisabled={closing}
      footer={
        <Button variant="primary" busy={closing} onClick={dismiss}>
          {exit ? 'Close and check connection' : 'Done'}
        </Button>
      }
    >
      <div className={styles.signInTerminal} ref={containerRef} aria-label="Temporary provider sign-in terminal" />
      {exit ? (
        <p className={styles.startHint} role="status">
          Sign-in command exited with code {exit.exitCode}. Choose “Close and check connection” to verify provider
          status.
        </p>
      ) : null}
    </Dialog>
  );
}
