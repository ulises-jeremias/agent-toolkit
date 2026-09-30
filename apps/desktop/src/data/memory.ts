import { useQuery } from '@tanstack/react-query';
import type { MemoryListResponse, MemoryReadResponse, MemorySearchResponse } from '../lib/api';
import { qk } from '../lib/query/keys';
import { requireClient, useBackend } from './backend';

/** Typed memory list. Failures (including 404) surface as query errors — world omits the place. */
export function useMemoryList(options: { enabled?: boolean } = {}) {
  const { client } = useBackend();
  return useQuery<MemoryListResponse>({
    queryKey: qk.memory.list(),
    queryFn: () => requireClient(client).listMemory(),
    enabled: client !== null && (options.enabled ?? true),
    staleTime: 15_000,
  });
}

/** Case-insensitive line hits (`GET /api/v1/memory/hits`). Empty q is rejected by the server. */
export function useMemorySearch(q: string, options: { enabled?: boolean } = {}) {
  const { client } = useBackend();
  const trimmed = q.trim();
  return useQuery<MemorySearchResponse>({
    queryKey: qk.memory.hits(trimmed),
    queryFn: () => requireClient(client).searchMemory(trimmed),
    enabled: client !== null && trimmed.length > 0 && (options.enabled ?? true),
    staleTime: 15_000,
  });
}

/** Read one memory file with body populated. */
export function useMemoryFile(path: string, options: { enabled?: boolean } = {}) {
  const { client } = useBackend();
  const trimmed = path.trim();
  return useQuery<MemoryReadResponse>({
    queryKey: qk.memory.file(trimmed),
    queryFn: () => requireClient(client).readMemoryFile(trimmed),
    enabled: client !== null && trimmed.length > 0 && (options.enabled ?? true),
    staleTime: 15_000,
  });
}
