import { QueryClient } from '@tanstack/react-query';
import { ApiClient } from './api';

/** Stable query keys — one namespace per backend resource. */
export const queryKeys = {
  health: ['backend', 'health'] as const,
  version: ['backend', 'version'] as const,
  selfcheck: ['backend', 'selfcheck'] as const,
  readApi: (path: string) => ['backend', 'read', path] as const,
  subApi: (resource: string, sub: string) => ['backend', 'sub', resource, sub] as const,
  jobs: ['backend', 'jobs'] as const,
  jobLog: (id: string) => ['backend', 'jobs', id, 'log'] as const,
};

export function createQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        retry: (failureCount, error) => {
          // Retry idempotent GETs on network failures only; never on 4xx.
          if (error instanceof Error && error.name === 'ApiError') return false;
          return failureCount < 2;
        },
        staleTime: 5_000,
        gcTime: 5 * 60_000,
        refetchOnWindowFocus: false,
      },
      mutations: {
        retry: false,
      },
    },
  });
}

/**
 * Resolve the backend base URL. Inside Electron the main process owns the
 * supervised `agent-toolkit serve` instance; in plain-browser dev the URL
 * comes from VITE_ATK_BACKEND_URL (default localhost:3847).
 */
export async function resolveBackendUrl(): Promise<string> {
  const bridge = window.atk;
  if (bridge) {
    const state = await bridge.backendStatus();
    if (state?.url) return state.url;
  }
  const fromEnv = import.meta.env.VITE_ATK_BACKEND_URL as string | undefined;
  return fromEnv ?? 'http://127.0.0.1:3847';
}

export async function createApiClient(): Promise<ApiClient> {
  return new ApiClient(await resolveBackendUrl());
}
