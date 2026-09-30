import { describe, expect, it } from 'vitest';
import { PROJECT_FACADES, projectFacade } from './facades';

describe('projectFacade', () => {
  it('is stable for the same project name', () => {
    expect(projectFacade('alpha')).toBe(projectFacade('alpha'));
    expect(projectFacade('agent-toolkit')).toBe(projectFacade('agent-toolkit'));
  });

  it('spreads names across the cottage family', () => {
    const seen = new Set(PROJECT_FACADES.map(() => '') as string[]);
    seen.clear();
    for (const name of ['alpha', 'beta', 'gamma', 'delta', 'epsilon', 'zeta', 'eta', 'theta']) {
      seen.add(projectFacade(name));
    }
    expect(seen.size).toBeGreaterThan(1);
    for (const facade of seen) {
      expect(PROJECT_FACADES).toContain(facade);
    }
  });
});
