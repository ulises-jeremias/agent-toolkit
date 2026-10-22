import { describe, expect, it } from 'vitest';
import type { PersonSession } from '../../lib/api';
import { personActivityLine, personActivitySummary } from './personActivity';

function session(overrides: Partial<PersonSession>): PersonSession {
  return {
    id: 's1',
    person_id: 'mara',
    person: 'Mara',
    role: 'implementer',
    project_id: '',
    cwd: '/repo',
    provider: 'skeleton',
    model: 'auto',
    status: 'completed',
    started_at: '2026-10-21T10:00:00.000Z',
    ended_at: '2026-10-21T10:05:00.000Z',
    exit_code: 0,
    provider_session_id: '',
    source: '',
    swarm_run_id: '',
    swarm_role: '',
    ...overrides,
  };
}

describe('personActivitySummary', () => {
  it('reports zeros for a configured Person with no recorded sessions', () => {
    const summary = personActivitySummary([], 'mara');
    expect(summary).toEqual({
      total: 0,
      running: 0,
      completed: 0,
      failed: 0,
      lastActiveAt: '',
      projects: [],
      swarmRuns: 0,
    });
    expect(personActivityLine(summary)).toBe('No recorded sessions yet.');
  });

  it('counts only the requested Person and buckets terminal states', () => {
    const summary = personActivitySummary(
      [
        session({ id: 'a', status: 'completed' }),
        session({ id: 'b', status: 'failed' }),
        session({ id: 'c', status: 'timed_out' }),
        session({ id: 'd', status: 'running', ended_at: '' }),
        session({ id: 'e', status: 'stopped' }),
        session({ id: 'f', person_id: 'other', status: 'failed' }),
      ],
      'mara',
    );
    expect(summary.total).toBe(5);
    expect(summary.completed).toBe(1);
    expect(summary.failed).toBe(2);
    expect(summary.running).toBe(1);
  });

  it('derives projects, distinct swarm runs and last activity from records', () => {
    const summary = personActivitySummary(
      [
        session({ id: 'a', project_id: 'demo', started_at: '2026-10-20T09:00:00.000Z', ended_at: '' }),
        session({
          id: 'b',
          project_id: 'demo',
          source: 'swarm',
          swarm_run_id: 's20261021T100000Z',
          swarm_role: 'implementer',
        }),
        session({
          id: 'c',
          project_id: 'api',
          source: 'swarm',
          swarm_run_id: 's20261021T100000Z',
          swarm_role: 'reviewer',
          started_at: '2026-10-21T12:00:00.000Z',
          ended_at: '2026-10-21T12:30:00.000Z',
        }),
      ],
      'mara',
    );
    expect(summary.projects).toEqual(['api', 'demo']);
    expect(summary.swarmRuns).toBe(1);
    expect(summary.lastActiveAt).toBe('2026-10-21T12:30:00.000Z');
    expect(personActivityLine(summary)).toContain('1 swarm run');
    expect(personActivityLine(summary)).toContain('projects: api, demo');
    expect(personActivityLine(summary)).toContain('last active 2026-10-21');
  });
});
