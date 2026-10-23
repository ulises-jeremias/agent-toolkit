import type { ProjectGitStatusResponse } from '../../lib/api';

/** Visual tone for one unified-diff line. Headers and context stay neutral. */
export function diffLineTone(line: string): 'add' | 'del' | 'meta' | 'context' {
  if (line.startsWith('+++') || line.startsWith('---') || line.startsWith('@@') || line.startsWith('diff ')) {
    return 'meta';
  }
  if (line.startsWith('+')) return 'add';
  if (line.startsWith('-')) return 'del';
  return 'context';
}

/** Total distinct change entries across the three status buckets. */
export function totalChanges(status: ProjectGitStatusResponse): number {
  return status.staged.length + status.unstaged.length + status.untracked.length;
}

/** True when the working tree has nothing staged, changed, or untracked. */
export function isClean(status: ProjectGitStatusResponse): boolean {
  return status.ok && totalChanges(status) === 0;
}
