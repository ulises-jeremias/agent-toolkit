import { useQuery } from '@tanstack/react-query';
import type { MemoryListResponse } from '../lib/api';
import { qk } from '../lib/query/keys';
import { requireClient, useBackend } from './backend';

/** Typed memory list. Failures surface as query errors (world treats as unavailable). */
export function useMemoryList(options: { enabled?: boolean } = {}) {
  const { client } = useBackend();
  return useQuery<MemoryListResponse>({
    queryKey: qk.memory.list(),
    queryFn: () => requireClient(client).listMemory(),
    enabled: client !== null && (options.enabled ?? true),
    staleTime: 15_000,
  });
}
