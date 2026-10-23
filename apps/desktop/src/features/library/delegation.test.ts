import { describe, expect, it } from 'vitest';
import type { AgentInfo } from '../../lib/api';
import { delegationEdges, delegationNodes } from './delegation';

const agent = (id: string, delegates: string[] = []): AgentInfo => ({
  id,
  name: id,
  kind: 'holistic',
  description: '',
  source_file: `agents/${id}/AGENT.md`,
  delegates,
  compatibility: [],
});

describe('delegationEdges', () => {
  it('keeps only edges between known definitions', () => {
    const agents = [agent('assistant', ['architect', 'ghost']), agent('architect'), agent('worker', ['worker'])];
    expect(delegationEdges(agents)).toEqual([{ from: 'assistant', to: 'architect' }]);
  });

  it('returns no edges when nobody delegates', () => {
    expect(delegationEdges([agent('a'), agent('b')])).toEqual([]);
  });
});

describe('delegationNodes', () => {
  it('lists involved ids in catalog order', () => {
    const agents = [agent('b', ['a']), agent('a'), agent('lonely')];
    const edges = delegationEdges(agents);
    expect(delegationNodes(agents, edges)).toEqual(['b', 'a']);
  });
});
