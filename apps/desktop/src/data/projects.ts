import { useQuery } from '@tanstack/react-query';
import type { ProjectListResponse } from '../lib/api';
import { qk } from '../lib/query/keys';
import { requireClient, useBackend } from './backend';

/** Registered project links from the canonical typed V project operation. */
export function useProjects(workspace: string, options: { enabled?: boolean } = {}) {
  const { client } = useBackend();
  return useQuery<ProjectListResponse>({
    queryKey: qk.projects.list(workspace),
    queryFn: () => requireClient(client).projects(workspace),
    enabled: client !== null && workspace.trim().length > 0 && (options.enabled ?? true),
    staleTime: 15_000,
  });
}
