import { describe, expect, it } from 'vitest';
import type { Person, PersonSession, SwarmRunInfo } from '../../lib/api';
import { swarmPersonWorldEntries } from './swarmPersonWorld';

function person(overrides: Partial<Person>): Person {
  return {
    spec: 'agent-toolkit/person@1',
    id: 'mara',
    name: 'Mara',
    role: 'implementer',
    goal: 'Implement',
    archived: false,
    ...overrides,
  } as Person;
}

function session(overrides: Partial<PersonSession>): PersonSession {
  return {
    id: 'session-1',
    person_id: 'mara',
    person: 'Mara',
    role: 'implementer',
    project_id: '',
    cwd: '/ws/.agent-toolkit/swarm/runs/run-1/worktrees/implementer',
    provider: 'skeleton',
    model: 'auto',
    status: 'running',
    started_at: '2026-10-22T00:00:00Z',
    ended_at: '',
    exit_code: -1,
    provider_session_id: '',
    source: 'swarm',
    swarm_run_id: 'run-1',
    swarm_role: 'implementer',
    ...overrides,
  };
}

function run(overrides: Partial<SwarmRunInfo>): SwarmRunInfo {
  return {
    run_id: 'run-1',
    recipe: 'pair',
    backend: 'tmux',
    run_state: 'running',
    created_at: '2026-10-22T00:00:00Z',
    task: 'Do work',
    issue_ref: '',
    pr_url: '',
    project_id: 'demo',
    ...overrides,
  };
}

const people = [person({})];
const projects = ['demo', 'other'];

describe('swarmPersonWorldEntries', () => {
  it('projects a live swarm session onto its run project', () => {
    const entries = swarmPersonWorldEntries({
      sessions: [session({})],
      runs: [run({})],
      people,
      projectNames: projects,
    });
    expect(entries).toHaveLength(1);
    expect(entries[0]).toMatchObject({
      id: 'session-1',
      personId: 'mara',
      name: 'Mara',
      role: 'implementer',
      projectId: 'demo',
      origin: 'swarm',
      runId: 'run-1',
      swarmRole: 'implementer',
    });
  });

  it('includes launching sessions but never terminal, PTY, or unbound records', () => {
    const entries = swarmPersonWorldEntries({
      sessions: [
        session({ id: 'launching', status: 'launching' }),
        session({ id: 'stopped', status: 'stopped' }),
        session({ id: 'interrupted', status: 'interrupted' }),
        session({ id: 'pty', source: '', swarm_run_id: '', swarm_role: '' }),
        session({ id: 'no-run', swarm_run_id: 'missing-run' }),
        session({ id: 'no-person', person_id: 'ghost' }),
      ],
      runs: [run({})],
      people,
      projectNames: projects,
    });
    expect(entries.map((entry) => entry.id)).toEqual(['launching']);
  });

  it('requires the run to name a known project', () => {
    const entries = swarmPersonWorldEntries({
      sessions: [session({})],
      runs: [run({ project_id: 'not-a-project' })],
      people,
      projectNames: projects,
    });
    expect(entries).toEqual([]);
    const noProject = swarmPersonWorldEntries({
      sessions: [session({})],
      runs: [run({ project_id: '' })],
      people,
      projectNames: projects,
    });
    expect(noProject).toEqual([]);
  });
});
