import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { useSearchParams } from 'react-router';
import { matchWorkstationSession } from '../lib/workstation';
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
  /** Select a real PTY and put it in the URL so the world can focus it. False if it does not exist. */
  focusSession: (id: string) => boolean;
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
  const [params, setParams] = useSearchParams();
  const [sessions, setSessions] = useState<PtySessionInfo[]>([]);
  const [extras, setExtras] = useState<Record<string, SessionExtras>>({});
  const [activeId, setActiveId] = useState<string | null>(null);
  const [loading, setLoading] = useState(Boolean(bridge));
  const [creating, setCreating] = useState(false);

  const writePty = useCallback(
    (id: string | null) => {
      setParams(
        (current) => {
          const next = new URLSearchParams(current);
          if (id) next.set('pty', id);
          else next.delete('pty');
          return next;
        },
        { replace: true },
      );
    },
    [setParams],
  );

  const focusSession = useCallback(
    (id: string): boolean => {
      if (!sessions.some((session) => session.id === id)) return false;
      setActiveId(id);
      writePty(id);
      return true;
    },
    [sessions, writePty],
  );

  useEffect(() => {
    if (!bridge) {
      setLoading(false);
      return;
    }
    let cancelled = false;
    void bridge.ptyList().then((list) => {
      if (cancelled) return;
      setSessions(list);
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

  useEffect(() => {
    if (loading) return;
    const pty = params.get('pty') ?? undefined;
    const matched = matchWorkstationSession(sessions, extras, {
      pty,
      agent: pty ? undefined : params.get('agent') || undefined,
      run: pty ? undefined : params.get('run') || undefined,
      cwd: pty ? undefined : params.get('workspace') || undefined,
    });
    if (matched) {
      setActiveId(matched.id);
      return;
    }
    if (pty) return;
    setActiveId((current) =>
      current && sessions.some((session) => session.id === current) ? current : (sessions[0]?.id ?? null),
    );
  }, [loading, params, sessions, extras]);

  const create = useCallback(
    async (options: PtyCreateOptions, extra?: SessionExtras): Promise<PtySessionInfo | null> => {
      if (!bridge) return null;
      const created = await bridge.ptyCreate({ ...options, cols: options.cols ?? 120, rows: options.rows ?? 30 });
      if (!created) return null;
      setSessions((list) => [...list, created]);
      setActiveId(created.id);
      writePty(created.id);
      if (extra) setExtras((current) => ({ ...current, [created.id]: extra }));
      return created;
    },
    [bridge, writePty],
  );

  const close = useCallback(
    async (id: string): Promise<void> => {
      if (!bridge) return;
      await bridge.ptyClose(id);
      setSessions((list) => {
        const rest = list.filter((session) => session.id !== id);
        const nextId = activeId === id ? (rest[0]?.id ?? null) : activeId;
        setActiveId(nextId);
        writePty(nextId);
        return rest;
      });
      setExtras((current) => {
        if (!(id in current)) return current;
        const rest = { ...current };
        delete rest[id];
        return rest;
      });
    },
    [bridge, activeId, writePty],
  );

  const restart = useCallback(
    async (session: PtySessionInfo): Promise<void> => {
      const extra = extras[session.id];
      await close(session.id);
      await create(
        {
          agent: session.agent,
          personId: session.personId,
          projectId: session.projectId,
          provider: session.provider,
          model: session.model,
          cmd: session.cmd,
          args: session.args,
          cwd: session.cwd,
        },
        extra,
      );
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
      focusSession,
      create,
      close,
      restart,
    }),
    [bridge, loading, sessions, extras, activeId, creating, focusSession, create, close, restart],
  );

  return <TerminalContext.Provider value={value}>{children}</TerminalContext.Provider>;
}
