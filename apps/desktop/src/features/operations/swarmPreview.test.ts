import { describe, expect, it } from 'vitest';
import { hasProjectBoundSwarmPreview, hopLabel, needsYouHandoffs } from './swarmPreview';

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
