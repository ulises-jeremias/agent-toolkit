import { useQuery } from '@tanstack/react-query';
import { qk } from '../lib/query/keys';
import { requireClient, useBackend } from './backend';

/** Typed catalog GETs (`/agents`, `/tools`, `/providers`, `/models`). Not subcommand envelopes. */
/** GET /api/v1/tools probes `--version` per CLI; cache instead of refetching on every render. */
export const TOOLS_STALE_MS = 60_000;

export function useAgents() {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.catalog.agents(),
    queryFn: () => requireClient(client).agents(),
    enabled: client !== null,
  });
}

export function useLibrarySkills() {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.catalog.librarySkills(),
    queryFn: () => requireClient(client).librarySkills(),
    enabled: client !== null,
    staleTime: 5 * 60_000,
  });
}

export function useTools() {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.catalog.tools(),
    queryFn: () => requireClient(client).tools(),
    enabled: client !== null,
    staleTime: TOOLS_STALE_MS,
  });
}

export function useProviders() {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.catalog.providers(),
    queryFn: () => requireClient(client).providers(),
    enabled: client !== null,
  });
}

export function useModels() {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.catalog.models(),
    queryFn: () => requireClient(client).models(),
    enabled: client !== null,
  });
}

export function useMcpProviders(options: { enabled?: boolean; staleTime?: number } = {}) {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.catalog.mcp(),
    queryFn: () => requireClient(client).mcpProviders(),
    enabled: client !== null && (options.enabled ?? true),
    staleTime: options.staleTime,
  });
}

export function useInstallReceipts() {
  const { client } = useBackend();
  return useQuery({
    queryKey: qk.catalog.installReceipts(),
    queryFn: () => requireClient(client).installReceipts(),
    enabled: client !== null,
  });
}
