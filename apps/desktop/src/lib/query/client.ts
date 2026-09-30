import { QueryClient } from '@tanstack/react-query';
import { ApiClient, ApiError } from '../api';

export function createQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        // Retry idempotent reads only on transport failures; a 4xx is an answer.
        retry: (failureCount, error) =>
          error instanceof ApiError ? error.kind === 'network' && failureCount < 2 : failureCount < 2,
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
 * supervised `agent-toolkit serve`; in plain-browser dev the URL comes from
 * VITE_ATK_BACKEND_URL (default 127.0.0.1:3847).
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
