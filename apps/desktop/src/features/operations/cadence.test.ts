import { describe, expect, it } from 'vitest';
import { cadenceIntervalSeconds, nextCadenceRuns } from './cadence';

describe('cadenceIntervalSeconds', () => {
  it('parses the canonical cadence units', () => {
    expect(cadenceIntervalSeconds('15m')).toBe(900);
    expect(cadenceIntervalSeconds('4h')).toBe(14_400);
    expect(cadenceIntervalSeconds('1d')).toBe(86_400);
    expect(cadenceIntervalSeconds('1w')).toBe(604_800);
    expect(cadenceIntervalSeconds(' 2h ')).toBe(7_200);
  });

  it('rejects out-of-contract cadences like the backend does', () => {
    expect(cadenceIntervalSeconds('90m')).toBeNull();
    expect(cadenceIntervalSeconds('25h')).toBeNull();
    expect(cadenceIntervalSeconds('0m')).toBeNull();
    expect(cadenceIntervalSeconds('5x')).toBeNull();
    expect(cadenceIntervalSeconds('')).toBeNull();
    expect(cadenceIntervalSeconds('h')).toBeNull();
  });
});

describe('nextCadenceRuns', () => {
  it('previews the next five fires at the cadence interval from now', () => {
    const from = new Date('2026-10-22T10:00:00Z');
    const runs = nextCadenceRuns('2h', from);
    expect(runs.map((d) => d.toISOString())).toEqual([
      '2026-10-22T12:00:00.000Z',
      '2026-10-22T14:00:00.000Z',
      '2026-10-22T16:00:00.000Z',
      '2026-10-22T18:00:00.000Z',
      '2026-10-22T20:00:00.000Z',
    ]);
  });

  it('previews nothing for an invalid cadence', () => {
    expect(nextCadenceRuns('soon', new Date())).toEqual([]);
  });
});
