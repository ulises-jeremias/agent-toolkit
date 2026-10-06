import { describe, expect, it } from 'vitest';
import { personSessionEndStatus } from './personSessionStatus';

describe('personSessionEndStatus', () => {
  it.each([
    [0, undefined, 'completed'],
    [1, undefined, 'failed'],
    [143, 'time-budget', 'timed_out'],
    [143, 'user-stop', 'stopped'],
    [137, 'app-shutdown', 'interrupted'],
  ] as const)('maps real exit evidence (%s, %s) to %s', (code, reason, status) => {
    expect(personSessionEndStatus(code, reason)).toBe(status);
  });
});
