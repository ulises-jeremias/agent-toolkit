import { useQuery } from '@tanstack/react-query';
import type { WorkspaceFileListResponse, WorkspaceFileReadResponse, WorkspaceFileSearchResponse } from '../lib/api';
import { qk } from '../lib/query/keys';
import { requireClient, useBackend } from './backend';

/** Workspace-contained tree (`GET /api/v1/files`). Never invents nodes. */
export function useWorkspaceFiles(options: { path?: string; depth?: number; enabled?: boolean } = {}) {
  const { client } = useBackend();
  const rel = options.path?.trim() || '';
  const depth = options.depth !== undefined ? String(options.depth) : '';
  return useQuery<WorkspaceFileListResponse>({
    queryKey: qk.files.list(rel, depth),
    queryFn: () =>
      requireClient(client).listFiles({
        path: rel || undefined,
        depth: depth || undefined,
      }),
    enabled: client !== null && (options.enabled ?? true),
    staleTime: 15_000,
  });
}

/** Filename and line hits (`GET /api/v1/files/hits`). Empty q is rejected by the server. */
export function useWorkspaceFileSearch(q: string, options: { enabled?: boolean } = {}) {
  const { client } = useBackend();
  const trimmed = q.trim();
  return useQuery<WorkspaceFileSearchResponse>({
    queryKey: qk.files.hits(trimmed),
    queryFn: () => requireClient(client).searchFiles(trimmed),
    enabled: client !== null && trimmed.length > 0 && (options.enabled ?? true),
    staleTime: 15_000,
  });
}

/** Read one workspace file (`GET /api/v1/files/content`). */
export function useWorkspaceFile(path: string, options: { enabled?: boolean } = {}) {
  const { client } = useBackend();
  const trimmed = path.trim();
  return useQuery<WorkspaceFileReadResponse>({
    queryKey: qk.files.content(trimmed),
    queryFn: () => requireClient(client).readFile(trimmed),
    enabled: client !== null && trimmed.length > 0 && (options.enabled ?? true),
    staleTime: 15_000,
  });
}
