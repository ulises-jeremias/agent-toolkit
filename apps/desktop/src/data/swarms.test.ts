import { describe, expect, it } from 'vitest';
import { swarmRefreshInterval } from './swarms';

describe('swarmRefreshInterval', () => {
  it.each(['planning', 'running', 'awaiting_human', 'awaiting_plan_approval'])(
    'refreshes active state %s promptly',
    (state) => {
      expect(swarmRefreshInterval([state])).toBe(2_000);
    },
  );

  it.each(['paused', 'budget_exhausted', 'failed'])(
    'keeps recoverable state %s observable at a slower cadence',
    (state) => {
      expect(swarmRefreshInterval([state])).toBe(10_000);
    },
  );

  it('stops polling terminal and unknown states', () => {
    expect(swarmRefreshInterval(['completed', 'cancelled'])).toBe(false);
    expect(swarmRefreshInterval([])).toBe(false);
  });

  it('uses the fastest cadence while any listed run is active', () => {
    expect(swarmRefreshInterval(['paused', 'running'])).toBe(2_000);
  });
});
