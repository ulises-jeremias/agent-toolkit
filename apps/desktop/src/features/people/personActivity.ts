import type { PersonSession } from '../../lib/api';

export interface PersonActivitySummary {
  total: number;
  running: number;
  completed: number;
  failed: number;
  /** Latest started_at/ended_at across the Person's sessions, '' when none. */
  lastActiveAt: string;
  /** Distinct non-empty project ids the Person actually ran in, sorted. */
  projects: string[];
  /** Distinct swarm runs the Person really launched a role in. */
  swarmRuns: number;
}

/**
 * Activity roll-up over the canonical PersonSession records of one Person.
 * Every number comes from recorded sessions only: a configured Person with
 * no launches reports zeros, never inferred activity.
 */
export function personActivitySummary(sessions: readonly PersonSession[], personId: string): PersonActivitySummary {
  const own = sessions.filter((session) => session.person_id === personId);
  const projects = new Set<string>();
  const swarmRunIds = new Set<string>();
  let running = 0;
  let completed = 0;
  let failed = 0;
  let lastActiveAt = '';
  for (const session of own) {
    if (session.status === 'running' || session.status === 'launching') running += 1;
    else if (session.status === 'completed') completed += 1;
    else if (session.status === 'failed' || session.status === 'timed_out') failed += 1;
    if (session.project_id) projects.add(session.project_id);
    if (session.source === 'swarm' && session.swarm_run_id) swarmRunIds.add(session.swarm_run_id);
    const latest = session.ended_at > session.started_at ? session.ended_at : session.started_at;
    if (latest > lastActiveAt) lastActiveAt = latest;
  }
  return {
    total: own.length,
    running,
    completed,
    failed,
    lastActiveAt,
    projects: [...projects].sort(),
    swarmRuns: swarmRunIds.size,
  };
}

/** One-line rendering of the summary for the Person detail panel. */
export function personActivityLine(summary: PersonActivitySummary): string {
  if (summary.total === 0) return 'No recorded sessions yet.';
  const parts = [
    `${summary.total} session${summary.total === 1 ? '' : 's'}`,
    `${summary.completed} completed`,
    `${summary.failed} failed`,
  ];
  if (summary.running > 0) parts.push(`${summary.running} running`);
  if (summary.swarmRuns > 0) parts.push(`${summary.swarmRuns} swarm run${summary.swarmRuns === 1 ? '' : 's'}`);
  if (summary.projects.length > 0) parts.push(`projects: ${summary.projects.join(', ')}`);
  if (summary.lastActiveAt) parts.push(`last active ${summary.lastActiveAt.slice(0, 10)}`);
  return parts.join(' · ');
}
