import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import type { EffectiveContextResponse, WorkspacePacksResponse } from '../lib/api';
import { qk } from '../lib/query/keys';
import { requireClient, useBackend } from './backend';

export function useWorkspacePacks(workspace: string) {
  const { client } = useBackend();
  return useQuery<WorkspacePacksResponse>({
    queryKey: qk.workspacePacks.list(workspace),
    queryFn: () => requireClient(client).workspacePacks(workspace),
    enabled: client !== null && workspace.trim().length > 0,
    staleTime: 15_000,
    refetchOnMount: 'always',
  });
}

export function useEffectiveContext(workspace: string) {
  const { client } = useBackend();
  return useQuery<EffectiveContextResponse>({
    queryKey: qk.workspacePacks.effectiveContext(workspace),
    queryFn: () => requireClient(client).effectiveContext(workspace),
    enabled: client !== null && workspace.trim().length > 0,
    staleTime: 15_000,
    refetchOnMount: 'always',
  });
}

export function useActivateWorkspacePack(workspace: string) {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (packPath: string) => requireClient(client).activateWorkspacePack(workspace, packPath),
    onSettled: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: qk.workspacePacks.list(workspace) }),
        queryClient.invalidateQueries({ queryKey: qk.workspacePacks.effectiveContext(workspace) }),
        queryClient.invalidateQueries({ queryKey: qk.domain('workspace') }),
      ]),
  });
}

export function useSaveWorkspacePack(workspace: string) {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: {
      pack_path: string;
      revision: string;
      name: string;
      description: string;
      projects: string[];
      notes: string;
    }) => requireClient(client).saveWorkspacePack({ ...input, workspace }),
    onSettled: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: qk.workspacePacks.list(workspace) }),
        queryClient.invalidateQueries({ queryKey: qk.workspacePacks.effectiveContext(workspace) }),
        queryClient.invalidateQueries({ queryKey: qk.domain('workspace') }),
      ]),
  });
}
