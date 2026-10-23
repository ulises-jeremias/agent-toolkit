import { describe, expect, it } from 'vitest';
import { burnDownBarPercent, burnDownPoints } from './burnDown';

describe('burnDownPoints', () => {
  it('burns the budget down cumulatively from recorded spend only', () => {
    const points = burnDownPoints(
      [
        { id: 'run-1', tokens: 120 },
        { id: 'run-2', tokens: 30 },
        { id: 'run-3', tokens: 0 },
      ],
      1000,
    );
    expect(points.map((p) => p.left)).toEqual([880, 850, 850]);
    expect(points.map((p) => p.cumulative)).toEqual([120, 150, 150]);
    expect(points.every((p) => !p.over)).toBe(true);
  });

  it('flags the run that crosses the budget and clamps its bar', () => {
    const points = burnDownPoints(
      [
        { id: 'run-1', tokens: 900 },
        { id: 'run-2', tokens: 250 },
      ],
      1000,
    );
    expect(points.at(1)?.left).toBe(-150);
    expect(points.at(1)?.over).toBe(true);
    expect(burnDownBarPercent(points.at(1)!, 1000)).toBe(0);
    expect(burnDownBarPercent(points.at(0)!, 1000)).toBe(10);
  });

  it('never divides by a missing budget', () => {
    const points = burnDownPoints([{ id: 'run-1', tokens: 5 }], 0);
    expect(burnDownBarPercent(points.at(0)!, 0)).toBe(0);
  });
});
