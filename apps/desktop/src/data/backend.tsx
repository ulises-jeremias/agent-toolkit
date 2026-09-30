import { QueryClientProvider, useQuery, useQueryClient } from '@tanstack/react-query';
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { ApiClient, ApiError } from '../lib/api';
import { createQueryClient, resolveBackendUrl } from '../lib/query/client';
import { qk } from '../lib/query/keys';
import type { BackendState } from '../types/electron';

interface BackendContextValue {
  client: ApiClient | null;
  /** Supervisor state from the Electron main process; null in plain-browser dev. */
  backend: BackendState | null;
  backendUrl: string | null;
  restartBackend: () => Promise<void>;
}

const BackendContext = createContext<BackendContextValue>({
  client: null,
  backend: null,
  backendUrl: null,
  restartBackend: async () => {},
});

export function useBackend(): BackendContextValue {
  return useContext(BackendContext);
}

/** The API client, or a typed network error for query functions to throw. */
export function requireClient(client: ApiClient | null): ApiClient {
  if (!client) throw new ApiError('network', 0, 'The backend is not connected yet.');
  return client;
}

export const HEALTH_POLL_MS = 10_000;

/** Liveness of the HTTP backend; the shell's offline indicator reads this. */
export function useHealth() {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.backend.health(),
    queryFn: () => requireClient(client).health(),
    enabled: client !== null,
    refetchInterval: HEALTH_POLL_MS,
    retry: false,
  });
}

export function useSelfcheck() {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.backend.selfcheck(),
    queryFn: () => requireClient(client).selfcheck(),
    enabled: client !== null,
  });
}

export function useHelp(options: { enabled?: boolean } = {}) {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.backend.help(),
    queryFn: () => requireClient(client).help(),
    enabled: client !== null && (options.enabled ?? true),
    staleTime: Infinity,
  });
}

function useSupervisedBackend() {
  const [backend, setBackend] = useState<BackendState | null>(null);
  const [backendUrl, setBackendUrl] = useState<string | null>(null);
  const [ticket, setTicket] = useState(0);
  const refresh = useCallback(() => setTicket((t) => t + 1), []);

  useEffect(() => {
    const bridge = window.atk;
    if (!bridge) {
      void resolveBackendUrl().then(setBackendUrl);
      return;
    }
    let cancelled = false;
    void bridge.backendStatus().then((state) => {
      if (cancelled || !state) return;
      setBackend(state);
      if (state.url) setBackendUrl(state.url);
    });
    const unsubscribe = bridge.onBackendState((state) => {
      setBackend(state);
      if (state.url) setBackendUrl(state.url);
    });
    return () => {
      cancelled = true;
      unsubscribe();
    };
  }, [ticket]);

  const client = useMemo(() => (backendUrl ? new ApiClient(backendUrl) : null), [backendUrl]);
  return { client, backend, backendUrl, refresh };
}

export function BackendProvider({ children }: { children: ReactNode }) {
  const [queryClient] = useState(createQueryClient);
  return (
    <QueryClientProvider client={queryClient}>
      <BackendInner>{children}</BackendInner>
    </QueryClientProvider>
  );
}

function BackendInner({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient();
  const { client, backend, backendUrl, refresh } = useSupervisedBackend();

  // A restarted backend listens on a new port: every cached answer came from
  // the previous process, and errors against the old port must not linger.
  const previousUrl = useRef<string | null>(null);
  useEffect(() => {
    if (previousUrl.current !== null && backendUrl !== previousUrl.current) {
      void queryClient.invalidateQueries();
    }
    previousUrl.current = backendUrl;
  }, [backendUrl, queryClient]);

  const value = useMemo<BackendContextValue>(
    () => ({
      client,
      backend,
      backendUrl,
      restartBackend: async () => {
        if (window.atk) await window.atk.backendRestart();
        refresh();
      },
    }),
    [client, backend, backendUrl, refresh],
  );

  return <BackendContext.Provider value={value}>{children}</BackendContext.Provider>;
}
