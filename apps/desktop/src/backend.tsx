import { QueryClientProvider, useQuery } from '@tanstack/react-query';
import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import type { BackendState } from './types/electron';
import { ApiClient } from './lib/api';
import { createQueryClient, queryKeys, resolveBackendUrl } from './lib/query';

interface BackendContextValue {
  client: ApiClient | null;
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

function useSupervisedBackend(): {
  client: ApiClient | null;
  backend: BackendState | null;
  backendUrl: string | null;
  refresh: () => void;
} {
  const [backend, setBackend] = useState<BackendState | null>(null);
  const [backendUrl, setBackendUrl] = useState<string | null>(null);
  const [ticket, setTicket] = useState(0);

  useEffect(() => {
    const bridge = window.atk;
    if (!bridge) {
      void resolveBackendUrl().then(setBackendUrl);
      return;
    }
    let cancelled = false;
    void bridge.backendStatus().then((state) => {
      if (cancelled) return;
      setBackend(state);
      if (state?.url) setBackendUrl(state.url);
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

  // Keep the health query as the liveness signal; backend crashes surface here.
  useQuery({
    queryKey: queryKeys.health,
    queryFn: () => client?.health() ?? Promise.reject(new Error('no backend')),
    enabled: client !== null,
    refetchInterval: 10_000,
    retry: false,
  });

  return { client, backend, backendUrl, refresh: () => setTicket((t) => t + 1) };
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
  const { client, backend, backendUrl, refresh } = useSupervisedBackend();

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
