import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { useSearchParams } from 'react-router';
import { useQueryClient } from '@tanstack/react-query';
import { matchWorkstationSession } from '../lib/workstation';
import type { PtyCreateOptions, PtyExitEvent, PtySessionInfo } from '../types/electron';
import { requireClient, useBackend } from './backend';
import { personSessionEndStatus } from './personSessionStatus';
import { useSessionContext } from '../shell/useSessionContext';

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
  /** Request a graceful process stop; the session remains visible until its exit event arrives. */
  stop: (id: string) => Promise<boolean>;
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
  const { client } = useBackend();
  const { context } = useSessionContext();
  const queryClient = useQueryClient();
  const [params, setParams] = useSearchParams();
  const [sessions, setSessions] = useState<PtySessionInfo[]>([]);
  const sessionMetadataRef = useRef(new Map<string, PtySessionInfo>());
  const reconciledWorkspaceRef = useRef<string | null>(null);
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
      sessionMetadataRef.current = new Map(list.map((session) => [session.id, session]));
      setSessions(list);
      setLoading(false);
    });
    const offExit = bridge.onPtyExit((exit: PtyExitEvent) => {
      const exitedSession = sessionMetadataRef.current.get(exit.id);
      sessionMetadataRef.current.delete(exit.id);
      void bridge.ptyList().then((list) => {
        if (cancelled) return;
        for (const session of list) sessionMetadataRef.current.set(session.id, session);
        setSessions(list);
        const session = exitedSession;
        if (session?.agentSessionId && session.sessionWorkspace && client) {
          const status = personSessionEndStatus(exit.exitCode, exit.exitReason);
          void client
            .updatePersonSession(session.sessionWorkspace, session.agentSessionId, status, exit.exitCode)
            .then(() => queryClient.invalidateQueries({ queryKey: ['person-sessions', session.sessionWorkspace] }))
            .catch(() => {});
        }
      });
    });
    return () => {
      cancelled = true;
      offExit();
    };
  }, [bridge, client, queryClient]);

  // A backend restart must not interrupt PTYs still owned by Electron main.
  // On Desktop startup, however, a persisted active record with no matching
  // local PTY is truthful evidence that the process did not survive app exit.
  useEffect(() => {
    const workspace = context.workspace;
    if (!bridge || !client || loading || !workspace || reconciledWorkspaceRef.current === workspace) return;
    reconciledWorkspaceRef.current = workspace;
    void client
      .personSessions(workspace)
      .then(async (result) => {
        const localSessions = await bridge.ptyList();
        const activeStatuses = new Set(['launching', 'running']);
        const updates = result.sessions.flatMap((record) => {
          if (!activeStatuses.has(record.status)) return [];
          const terminal = localSessions.find((candidate) => candidate.agentSessionId === record.id);
          if (!terminal) return [{ id: record.id, status: 'interrupted' as const, exitCode: -1 }];
          if (terminal.exitCode === null) return [];
          const status = personSessionEndStatus(terminal.exitCode, terminal.exitReason);
          return [{ id: record.id, status, exitCode: terminal.exitCode }];
        });
        await Promise.all(
          updates.map((update) =>
            client.updatePersonSession(workspace, update.id, update.status, update.exitCode).catch(() => null),
          ),
        );
        await queryClient.invalidateQueries({ queryKey: ['person-sessions', workspace] });
      })
      .catch(() => {
        reconciledWorkspaceRef.current = null;
      });
  }, [bridge, client, context.workspace, loading, queryClient, sessions]);

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
      sessionMetadataRef.current.set(created.id, created);
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

  const stop = useCallback(
    async (id: string): Promise<boolean> => (bridge ? bridge.ptySignal(id, 'term') : false),
    [bridge],
  );

  const restart = useCallback(
    async (session: PtySessionInfo): Promise<void> => {
      const extra = extras[session.id];
      if (session.personId) {
        if (!client || !session.projectId || !session.provider || !session.sessionWorkspace) {
          throw new Error(
            'This Person session needs the backend to create a new durable session record before restart.',
          );
        }
        const api = requireClient(client);
        const record = await api.createPersonSession({
          workspace: session.sessionWorkspace,
          person_id: session.personId,
          project_id: session.projectId,
          provider: session.provider,
          model: session.model ?? '',
        });
        await close(session.id);
        const restarted = await create(
          {
            agent: session.agent,
            personId: session.personId,
            agentSessionId: record.session.id,
            sessionWorkspace: session.sessionWorkspace,
            projectId: session.projectId,
            provider: session.provider,
            model: session.model,
            cmd: session.cmd,
            args: session.args,
            cwd: record.session.cwd,
            maxSeconds: session.maxSeconds,
          },
          extra,
        );
        if (!restarted) {
          await api.updatePersonSession(session.sessionWorkspace, record.session.id, 'failed').catch(() => null);
          throw new Error('Desktop could not reopen the Person PTY. The previous process has been stopped.');
        }
        try {
          await api.updatePersonSession(session.sessionWorkspace, record.session.id, 'running');
        } catch (error) {
          const current = await api.personSessions(session.sessionWorkspace).catch(() => null);
          const saved = current?.sessions.find((candidate) => candidate.id === record.session.id);
          if (!saved || !['completed', 'failed', 'stopped', 'timed_out', 'interrupted'].includes(saved.status)) {
            await close(restarted.id);
            await api.updatePersonSession(session.sessionWorkspace, record.session.id, 'failed').catch(() => null);
            throw error;
          }
        }
        void queryClient.invalidateQueries({ queryKey: ['person-sessions', session.sessionWorkspace] });
        return;
      }
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
          maxSeconds: session.maxSeconds,
        },
        extra,
      );
    },
    [client, close, create, extras, queryClient],
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
      stop,
      close,
      restart,
    }),
    [bridge, loading, sessions, extras, activeId, creating, focusSession, create, stop, close, restart],
  );

  return <TerminalContext.Provider value={value}>{children}</TerminalContext.Provider>;
}
