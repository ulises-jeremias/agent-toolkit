/** A successful legacy preview can ignore `project_id`; require explicit backend evidence. */
export function hasProjectBoundSwarmPreview(data: Record<string, string> | undefined, projectId: string): boolean {
  return data?.['project_id'] === projectId && Boolean(data['project_path']?.trim());
}

export interface HandoffLike {
  state: string;
  act: string;
  hops: number;
  max_hops: number;
}

/** Handoffs the engine routed to a human (ADR-039): they wait in Needs-you until resolved. */
export function needsYouHandoffs<T extends HandoffLike>(handoffs: readonly T[]): T[] {
  return handoffs.filter((handoff) => handoff.state === 'awaiting_human');
}

export interface IssueLike {
  number: number;
  title: string;
  labels: string[];
  author: string;
}

/** Canonical swarm --issue ref for a picked issue, e.g. "o/r#42". */
export function issueRefFor(repo: string, issue: IssueLike): string {
  return repo ? `${repo}#${issue.number}` : `#${issue.number}`;
}

/** Task text the engine derives from an issue ref; the dialog mirrors it so the preview is truthful. */
export function issueTaskFor(repo: string, issue: IssueLike): string {
  return `Implement issue ${issueRefFor(repo, issue)}`;
}

/** Picker label, e.g. "#42 Fix the thing · bug · @octocat". */
export function issueOptionLabel(issue: IssueLike): string {
  const labels = issue.labels.length > 0 ? ` · ${issue.labels.join(', ')}` : '';
  const author = issue.author ? ` · @${issue.author}` : '';
  return `#${issue.number} ${issue.title}${labels}${author}`;
}

export interface SwarmPersonSessionLike {
  source: string;
  swarm_run_id: string;
  swarm_role: string;
}

/**
 * Canonical PersonSession records a swarm run really launched (source=swarm).
 * A Person binding alone never appears here: the engine records a session
 * only after that role's runner started, and closes it with the run.
 */
export function swarmPersonSessionsForRun<T extends SwarmPersonSessionLike>(
  sessions: readonly T[],
  runId: string,
): T[] {
  if (!runId) return [];
  return sessions.filter((session) => session.source === 'swarm' && session.swarm_run_id === runId);
}

/** Chain position label, e.g. "hop 7 of 6" once a chain passed its budget. */
export function hopLabel(handoff: HandoffLike): string {
  return handoff.max_hops > 0 ? `hop ${handoff.hops} of ${handoff.max_hops}` : `hop ${handoff.hops}`;
}
