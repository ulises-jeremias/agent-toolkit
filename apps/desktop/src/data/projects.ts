import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import type { ApiClient, ProjectGitDiffResponse, ProjectGitStatusResponse, ProjectListResponse } from '../lib/api';
import { qk } from '../lib/query/keys';
import { requireClient, useBackend } from './backend';

/** Registered project links from the canonical typed V project operation. */
export function useProjects(workspace: string, options: { enabled?: boolean } = {}) {
  const { client } = useBackend();
  return useQuery<ProjectListResponse>({
    queryKey: qk.projects.list(workspace),
    queryFn: () => requireClient(client).projects(workspace),
    enabled: client !== null && workspace.trim().length > 0 && (options.enabled ?? true),
    staleTime: 0,
    refetchOnMount: 'always',
  });
}

/** Working-tree state for one registered project repository. */
export function useProjectGitStatus(workspace: string, project: string) {
  const { client } = useBackend();
  return useQuery<ProjectGitStatusResponse>({
    queryKey: qk.projects.gitStatus(workspace, project),
    queryFn: () => requireClient(client).projectGitStatus(workspace, project),
    enabled: client !== null && workspace.trim().length > 0 && project.length > 0,
    staleTime: 0,
    refetchOnMount: 'always',
  });
}

/** Unified diff for one changed file; staged=false reads working tree vs index. */
export function useProjectGitDiff(workspace: string, project: string, path: string, staged: boolean) {
  const { client } = useBackend();
  return useQuery<ProjectGitDiffResponse>({
    queryKey: qk.projects.gitDiff(workspace, project, path, staged),
    queryFn: () => requireClient(client).projectGitDiff(workspace, project, path, staged),
    enabled: client !== null && workspace.trim().length > 0 && project.length > 0 && path.length > 0,
    staleTime: 0,
  });
}

function useProjectGitMutation<I>(
  workspace: string,
  project: string,
  fn: (client: ApiClient, input: I) => Promise<ProjectGitStatusResponse>,
) {
  const { client } = useBackend();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: I) => fn(requireClient(client), input),
    onSettled: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: qk.projects.gitStatus(workspace, project) }),
        queryClient.invalidateQueries({ queryKey: ['projects', 'git-diff', workspace, project] }),
      ]),
  });
}

export function useProjectGitStage(workspace: string, project: string) {
  return useProjectGitMutation(workspace, project, (client, paths: string[]) =>
    client.projectGitStage(workspace, project, paths),
  );
}

export function useProjectGitUnstage(workspace: string, project: string) {
  return useProjectGitMutation(workspace, project, (client, paths: string[]) =>
    client.projectGitUnstage(workspace, project, paths),
  );
}

/** Recent commits of one registered project repository. */
export function useProjectGitLog(workspace: string, project: string) {
  const { client } = useBackend();
  return useQuery({
    queryKey: ['projects', 'git-log', workspace, project],
    queryFn: () => requireClient(client).projectGitLog(workspace, project),
    enabled: client !== null && workspace.trim().length > 0 && project.length > 0,
    staleTime: 0,
    refetchOnMount: 'always' as const,
  });
}

/** Full diff of one commit in the project repository. */
export function useProjectGitShow(workspace: string, project: string, hash: string) {
  const { client } = useBackend();
  return useQuery({
    queryKey: ['projects', 'git-show', workspace, project, hash],
    queryFn: () => requireClient(client).projectGitShow(workspace, project, hash),
    enabled: client !== null && workspace.trim().length > 0 && project.length > 0 && hash.length > 0,
    staleTime: 0,
  });
}

export interface GitHunkSelection {
  path: string;
  staged: boolean;
  hunk: number;
}

export function useProjectGitStageHunk(workspace: string, project: string) {
  return useProjectGitMutation(workspace, project, (client, input: GitHunkSelection) =>
    client.projectGitStageHunk(workspace, project, input.path, input.staged, input.hunk),
  );
}

export function useProjectGitCommit(workspace: string, project: string) {
  return useProjectGitMutation(workspace, project, (client, message: string) =>
    client.projectGitCommit(workspace, project, message),
  );
}
