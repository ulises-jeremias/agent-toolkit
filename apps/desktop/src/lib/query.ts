import { QueryClient } from '@tanstack/react-query';
import { ApiClient, ApiError } from './api';

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
          // Retry idempotent GETs on network failures only: every ApiError
          // sets name to 'ApiError', so dispatch on kind instead.
          if (error instanceof ApiError) return error.kind === 'network' && failureCount < 2;
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
  return normalizeLoopback(fromEnv ?? 'http://127.0.0.1:3847');
}

/**
 * Normalize `localhost` to `127.0.0.1`: the CSP allowlists the IP literal,
 * the server binds it, and `localhost` may resolve to ::1 and fail.
 */
export function normalizeLoopback(url: string): string {
  try {
    const parsed = new URL(url);
    if (parsed.hostname === 'localhost') {
      parsed.hostname = '127.0.0.1';
      return parsed.toString().replace(/\/$/, '');
    }
    return url;
  } catch {
    return url;
  }
}

export async function createApiClient(): Promise<ApiClient> {
  return new ApiClient(await resolveBackendUrl());
}
