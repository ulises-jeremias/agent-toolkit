import type { Person, PersonSession, SwarmRunInfo } from '../../lib/api';

/** A live swarm worker projected into the World at its run's project. */
export interface SwarmWorldPersonEntry {
  id: string;
  personId: string;
  name: string;
  role: string;
  cwd: string;
  projectId: string;
  provider: string;
  model: string;
  origin: 'swarm';
  runId: string;
  swarmRole: string;
}

const LIVE_SWARM_STATUSES = new Set(['launching', 'running']);

/**
 * Project canonical swarm PersonSession records into World characters.
 * A record earns a character only while its own runtime session is live
 * (launching/running), its Person still exists, and its swarm run names
 * a project the World knows. Bindings, queued roles, terminal records,
 * and Desktop PTY sessions never produce a character here: presence in
 * the World must mean a real worker is running, and the character links
 * to the Operations run inspector rather than pretending a PTY exists.
 */
export function swarmPersonWorldEntries(input: {
  sessions: readonly PersonSession[];
  runs: readonly SwarmRunInfo[];
  people: readonly Person[];
  projectNames: readonly string[];
}): SwarmWorldPersonEntry[] {
  const peopleById = new Map(input.people.map((person) => [person.id, person]));
  const runsById = new Map(input.runs.map((run) => [run.run_id, run]));
  const knownProjects = new Set(input.projectNames);
  const entries: SwarmWorldPersonEntry[] = [];
  for (const session of input.sessions) {
    if (session.source !== 'swarm' || !LIVE_SWARM_STATUSES.has(session.status)) continue;
    if (!session.swarm_run_id) continue;
    const person = peopleById.get(session.person_id);
    const run = runsById.get(session.swarm_run_id);
    if (!person || !run || !run.project_id || !knownProjects.has(run.project_id)) continue;
    entries.push({
      id: session.id,
      personId: person.id,
      name: person.name,
      role: session.swarm_role || session.role || person.role,
      cwd: session.cwd,
      projectId: run.project_id,
      provider: session.provider,
      model: session.model,
      origin: 'swarm',
      runId: run.run_id,
      swarmRole: session.swarm_role || session.role,
    });
  }
  return entries;
}
