import { useQuery } from '@tanstack/react-query';
import type { WorkspaceFileListResponse, WorkspaceFileReadResponse, WorkspaceFileSearchResponse } from '../lib/api';
import { qk } from '../lib/query/keys';
import { requireClient, useBackend } from './backend';

/** Workspace-contained tree (`GET /api/v1/files`). Never invents nodes. */
export function useWorkspaceFiles(
  options: { path?: string; depth?: number; project?: string; enabled?: boolean } = {},
) {
  const { client } = useBackend();
  const rel = options.path?.trim() || '';
  const depth = options.depth !== undefined ? String(options.depth) : '';
  const project = options.project?.trim() || '';
  return useQuery<WorkspaceFileListResponse>({
    queryKey: qk.files.list(rel, depth, project),
    queryFn: () =>
      requireClient(client).listFiles({
        path: rel || undefined,
        depth: depth || undefined,
        project: project || undefined,
      }),
    enabled: client !== null && (options.enabled ?? true),
    staleTime: 15_000,
  });
}

/** Filename and line hits (`GET /api/v1/files/hits`). Empty q is rejected by the server. */
export function useWorkspaceFileSearch(q: string, options: { project?: string; enabled?: boolean } = {}) {
  const { client } = useBackend();
  const trimmed = q.trim();
  const project = options.project?.trim() || '';
  return useQuery<WorkspaceFileSearchResponse>({
    queryKey: qk.files.hits(trimmed, project),
    queryFn: () => requireClient(client).searchFiles(trimmed, { project: project || undefined }),
    enabled: client !== null && trimmed.length > 0 && (options.enabled ?? true),
    staleTime: 15_000,
  });
}

/** Read one workspace file (`GET /api/v1/files/content`). */
export function useWorkspaceFile(path: string, options: { project?: string; enabled?: boolean } = {}) {
  const { client } = useBackend();
  const trimmed = path.trim();
  const project = options.project?.trim() || '';
  return useQuery<WorkspaceFileReadResponse>({
    queryKey: qk.files.content(trimmed, project),
    queryFn: () => requireClient(client).readFile(trimmed, { project: project || undefined }),
    enabled: client !== null && trimmed.length > 0 && (options.enabled ?? true),
    staleTime: 15_000,
  });
}
