import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import type { PtyCreateOptions, PtySessionInfo } from '../types/electron';

export interface TerminalsValue {
  /** False outside Electron: there is no PTY transport in a browser. */
  available: boolean;
  loading: boolean;
  sessions: PtySessionInfo[];
  activeId: string | null;
  setActive: (id: string) => void;
  create: (options: PtyCreateOptions) => Promise<PtySessionInfo | null>;
  close: (id: string) => Promise<void>;
  restart: (session: PtySessionInfo) => Promise<void>;
  dockOpen: boolean;
  setDockOpen: (open: boolean) => void;
  /** Whether the "New terminal session" dialog is requested. */
  newSessionOpen: boolean;
  setNewSessionOpen: (open: boolean) => void;
}

const TerminalsContext = createContext<TerminalsValue | null>(null);

/**
 * Owns the list of PTY sessions from the Electron main process. Sessions
 * live in main, not here: this mirrors them so the dock can stay mounted
 * across navigation and reattach after a reload.
 */
export function TerminalsProvider({ children }: { children: ReactNode }) {
  const bridge = typeof window !== 'undefined' ? window.atk : undefined;
  const [sessions, setSessions] = useState<PtySessionInfo[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [loading, setLoading] = useState(Boolean(bridge));
  const [dockOpen, setDockOpen] = useState(false);
  const [newSessionOpen, setNewSessionOpen] = useState(false);

  useEffect(() => {
    if (!bridge) return;
    let cancelled = false;
    void bridge.ptyList().then((list) => {
      if (cancelled) return;
      setSessions(list);
      setActiveId((current) => current ?? list[0]?.id ?? null);
      setLoading(false);
    });
    const offExit = bridge.onPtyExit((event) => {
      setSessions((list) =>
        list.map((session) => (session.id === event.id ? { ...session, exitCode: event.exitCode } : session)),
      );
    });
    return () => {
      cancelled = true;
      offExit();
    };
  }, [bridge]);

  const create = useCallback(
    async (options: PtyCreateOptions): Promise<PtySessionInfo | null> => {
      if (!bridge) return null;
      const created = await bridge.ptyCreate({ cols: 120, rows: 30, ...options });
      if (created) {
        setSessions((list) => [...list, created]);
        setActiveId(created.id);
      }
      return created;
    },
    [bridge],
  );

  const close = useCallback(
    async (id: string): Promise<void> => {
      if (!bridge) return;
      await bridge.ptyClose(id);
      setSessions((list) => {
        const rest = list.filter((session) => session.id !== id);
        setActiveId((current) => (current === id ? (rest[0]?.id ?? null) : current));
        return rest;
      });
    },
    [bridge],
  );

  const restart = useCallback(
    async (session: PtySessionInfo): Promise<void> => {
      await close(session.id);
      await create({
        agent: session.agent,
        run: session.run ?? undefined,
        cmd: session.cmd,
        args: session.args,
        cwd: session.cwd,
      });
    },
    [close, create],
  );

  const value = useMemo<TerminalsValue>(
    () => ({
      available: Boolean(bridge),
      loading,
      sessions,
      activeId,
      setActive: setActiveId,
      create,
      close,
      restart,
      dockOpen,
      setDockOpen,
      newSessionOpen,
      setNewSessionOpen,
    }),
    [bridge, loading, sessions, activeId, create, close, restart, dockOpen, newSessionOpen],
  );

  return <TerminalsContext.Provider value={value}>{children}</TerminalsContext.Provider>;
}

export function useTerminals(): TerminalsValue {
  const value = useContext(TerminalsContext);
  if (!value) throw new Error('useTerminals must be used inside <TerminalsProvider>');
  return value;
}
