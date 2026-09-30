import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import type { PtyCreateOptions, PtySessionInfo } from '../types/electron';

export interface SessionExtras {
  run: string;
}

export interface TerminalSessionsValue {
  available: boolean;
  loading: boolean;
  sessions: PtySessionInfo[];
  extras: Record<string, SessionExtras>;
  activeId: string | null;
  creating: boolean;
  setCreating: (open: boolean) => void;
  setActiveId: (id: string | null) => void;
  create: (options: PtyCreateOptions, extras?: SessionExtras) => Promise<PtySessionInfo | null>;
  close: (id: string) => Promise<void>;
  restart: (session: PtySessionInfo) => Promise<void>;
}

const TerminalContext = createContext<TerminalSessionsValue | null>(null);

export function useTerminalSessions(): TerminalSessionsValue {
  const value = useContext(TerminalContext);
  if (!value) throw new Error('useTerminalSessions must be used inside <TerminalProvider>');
  return value;
}

/**
 * Session list for the persistent dock. xterm hosts stay mounted in the
 * shell; this provider only owns identity, create/close and the create dialog.
 */
export function TerminalProvider({ children }: { children: ReactNode }) {
  const bridge = typeof window !== 'undefined' ? window.atk : undefined;
  const [sessions, setSessions] = useState<PtySessionInfo[]>([]);
  const [extras, setExtras] = useState<Record<string, SessionExtras>>({});
  const [activeId, setActiveId] = useState<string | null>(null);
  const [loading, setLoading] = useState(Boolean(bridge));
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

  const create = useCallback(
    async (options: PtyCreateOptions, extra?: SessionExtras): Promise<PtySessionInfo | null> => {
      if (!bridge) return null;
      const created = await bridge.ptyCreate({ ...options, cols: options.cols ?? 120, rows: options.rows ?? 30 });
      if (!created) return null;
      setSessions((list) => [...list, created]);
      setActiveId(created.id);
      if (extra) setExtras((current) => ({ ...current, [created.id]: extra }));
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
      setExtras((current) => {
        if (!(id in current)) return current;
        const rest = { ...current };
        delete rest[id];
        return rest;
      });
    },
    [bridge],
  );

  const restart = useCallback(
    async (session: PtySessionInfo): Promise<void> => {
      const extra = extras[session.id];
      await close(session.id);
      await create({ agent: session.agent, cmd: session.cmd, args: session.args, cwd: session.cwd }, extra);
    },
    [close, create, extras],
  );

  const value = useMemo<TerminalSessionsValue>(
    () => ({
      available: Boolean(bridge),
      loading,
      sessions,
      extras,
      activeId,
      creating,
      setCreating,
      setActiveId,
      create,
      close,
      restart,
    }),
    [bridge, loading, sessions, extras, activeId, creating, create, close, restart],
  );

  return <TerminalContext.Provider value={value}>{children}</TerminalContext.Provider>;
}
