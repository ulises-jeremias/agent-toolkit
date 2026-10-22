import { describe, expect, it } from 'vitest';
import type { WorkspacePackSummary } from '../../lib/api';
import { filterContextBundles } from './contextBundles';

function pack(overrides: Partial<WorkspacePackSummary>): WorkspacePackSummary {
  return {
    path: 'packs/agent-toolkit.yaml',
    name: 'Agent Toolkit',
    description: 'Context for the toolkit repos',
    projects: ['agent-toolkit', 'agentic-harness'],
    notes: '',
    revision: '1',
    validation_errors: [],
    active: false,
    extra_fields: [],
    ...overrides,
  };
}

describe('filterContextBundles', () => {
  it('returns every bundle when the search is empty', () => {
    const packs = [pack({}), pack({ name: 'Client work', path: 'packs/client.yaml' })];
    expect(filterContextBundles(packs, '')).toEqual(packs);
    expect(filterContextBundles(packs, '   ')).toEqual(packs);
  });

  it('matches name, description, and related projects case-insensitively', () => {
    const packs = [
      pack({}),
      pack({ name: 'Client work', path: 'packs/client.yaml', description: 'Billing', projects: ['ledger'] }),
    ];
    expect(filterContextBundles(packs, 'AGENT TOOLKIT').map((item) => item.name)).toEqual(['Agent Toolkit']);
    expect(filterContextBundles(packs, 'billing').map((item) => item.name)).toEqual(['Client work']);
    expect(filterContextBundles(packs, 'agentic-harness').map((item) => item.name)).toEqual(['Agent Toolkit']);
    expect(filterContextBundles(packs, 'ledger').map((item) => item.name)).toEqual(['Client work']);
  });

  it('returns no bundles when nothing matches', () => {
    expect(filterContextBundles([pack({})], 'nonexistent')).toEqual([]);
  });
});
