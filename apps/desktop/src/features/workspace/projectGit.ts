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

/** One hunk of a unified diff: header line plus its body lines. */
export interface DiffHunk {
  header: string;
  lines: string[];
}

/**
 * Splits a unified diff into hunks for display and per-hunk staging.
 * The hunk index matches the backend's split of the same diff text.
 */
export function splitDiffHunks(diff: string): DiffHunk[] {
  const hunks: DiffHunk[] = [];
  let current: DiffHunk | null = null;
  for (const line of diff.split('\n')) {
    if (line.startsWith('@@')) {
      current = { header: line, lines: [] };
      hunks.push(current);
    } else if (current) {
      current.lines.push(line);
    }
  }
  return hunks;
}

/** One rendered diff line with its old/new line numbers (gutter). */
export interface DiffLine {
  text: string;
  oldNo: number | null;
  newNo: number | null;
}

/** Parses a hunk header `@@ -oldStart,oldCount +newStart,newCount @@`. */
export function hunkStarts(header: string): { oldStart: number; newStart: number } {
  const match = /@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(header);
  return { oldStart: match ? Number(match[1]) : 0, newStart: match ? Number(match[2]) : 0 };
}

/** Annotates hunk body lines with gutter line numbers. */
export function annotateHunk(hunk: DiffHunk): DiffLine[] {
  let { oldStart: oldNo, newStart: newNo } = hunkStarts(hunk.header);
  return hunk.lines.map((text) => {
    if (text.startsWith('-')) return { text, oldNo: oldNo++, newNo: null };
    if (text.startsWith('+')) return { text, oldNo: null, newNo: newNo++ };
    if (text.startsWith('\\')) return { text, oldNo: null, newNo: null };
    return { text, oldNo: oldNo++, newNo: newNo++ };
  });
}
