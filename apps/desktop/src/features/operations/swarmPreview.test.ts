import { describe, expect, it } from 'vitest';
import {
  hasProjectBoundSwarmPreview,
  hopLabel,
  issueOptionLabel,
  issueRefFor,
  issueTaskFor,
  needsYouHandoffs,
  swarmPersonSessionsForRun,
} from './swarmPreview';

describe('hasProjectBoundSwarmPreview', () => {
  it('accepts only a preview that confirms both the selected project and its repository path', () => {
    expect(
      hasProjectBoundSwarmPreview(
        { project_id: 'agent-toolkit', project_path: '/repos/agent-toolkit' },
        'agent-toolkit',
      ),
    ).toBe(true);
    expect(hasProjectBoundSwarmPreview({ project_path: '/workspace' }, 'agent-toolkit')).toBe(false);
    expect(
      hasProjectBoundSwarmPreview(
        { project_id: 'other-project', project_path: '/repos/other-project' },
        'agent-toolkit',
      ),
    ).toBe(false);
    expect(hasProjectBoundSwarmPreview({ project_id: 'agent-toolkit', project_path: ' ' }, 'agent-toolkit')).toBe(
      false,
    );
  });
});

describe('needs-you handoffs (ADR-039)', () => {
  const handoffs = [
    { id: 'a', state: 'queued', act: 'propose', hops: 0, max_hops: 6 },
    { id: 'b', state: 'awaiting_human', act: 'request_decision', hops: 7, max_hops: 6 },
    { id: 'c', state: 'completed', act: 'approve', hops: 1, max_hops: 6 },
    { id: 'd', state: 'awaiting_human', act: 'request_decision', hops: 3, max_hops: 2 },
  ];

  it('selects only handoffs routed to a human', () => {
    expect(needsYouHandoffs(handoffs).map((handoff) => handoff.id)).toEqual(['b', 'd']);
    expect(needsYouHandoffs([])).toEqual([]);
  });

  it('labels the chain position against its budget', () => {
    expect(hopLabel(handoffs[1]!)).toBe('hop 7 of 6');
    expect(hopLabel({ state: 'queued', act: '', hops: 2, max_hops: 0 })).toBe('hop 2');
  });
});

describe('swarm Person sessions', () => {
  const sessions = [
    { id: 'a', source: 'swarm', swarm_run_id: 'run-1', swarm_role: 'reviewer' },
    { id: 'b', source: '', swarm_run_id: '', swarm_role: '' },
    { id: 'c', source: 'swarm', swarm_run_id: 'run-2', swarm_role: 'implementer' },
  ];

  it('returns only sessions this run really launched', () => {
    expect(swarmPersonSessionsForRun(sessions, 'run-1').map((session) => session.id)).toEqual(['a']);
    expect(swarmPersonSessionsForRun(sessions, 'missing')).toEqual([]);
    expect(swarmPersonSessionsForRun(sessions, '')).toEqual([]);
  });
});

describe('github issue picker helpers', () => {
  const issue = { number: 42, title: 'Fix the thing', labels: ['bug', 'p1'], author: 'octocat' };

  it('builds the canonical issue ref and derived task', () => {
    expect(issueRefFor('o/r', issue)).toBe('o/r#42');
    expect(issueRefFor('', issue)).toBe('#42');
    expect(issueTaskFor('o/r', issue)).toBe('Implement issue o/r#42');
  });

  it('labels picker options with labels and author', () => {
    expect(issueOptionLabel(issue)).toBe('#42 Fix the thing · bug, p1 · @octocat');
    expect(issueOptionLabel({ number: 7, title: 'Docs', labels: [], author: '' })).toBe('#7 Docs');
  });
});
