import { describe, expect, it, vi } from 'vitest';
import { applyInstallTargets, type TargetApplyProgress } from './installProgress';

describe('applyInstallTargets', () => {
  it('applies targets in order and reports determinate progress', async () => {
    const applied: string[] = [];
    const snapshots: TargetApplyProgress[] = [];
    const result = await applyInstallTargets(
      ['claude-code', 'opencode'],
      async (target) => {
        applied.push(target);
      },
      (progress) => snapshots.push(progress),
    );
    expect(applied).toEqual(['claude-code', 'opencode']);
    expect(result).toEqual({ total: 2, done: ['claude-code', 'opencode'], failed: [], current: null });
    expect(snapshots.at(-1)).toEqual(result);
    expect(snapshots.some((snapshot) => snapshot.current === 'opencode' && snapshot.done.length === 1)).toBe(true);
  });

  it('continues past a failed target and reports every outcome', async () => {
    const result = await applyInstallTargets(
      ['claude-code', 'cursor', 'opencode'],
      async (target) => {
        if (target === 'cursor') throw new Error('profile source missing');
      },
      vi.fn(),
    );
    expect(result.done).toEqual(['claude-code', 'opencode']);
    expect(result.failed).toEqual([{ target: 'cursor', message: 'profile source missing' }]);
    expect(result.current).toBeNull();
  });

  it('settles an empty selection without calling apply', async () => {
    const applyOne = vi.fn(async () => undefined);
    const result = await applyInstallTargets([], applyOne, vi.fn());
    expect(applyOne).not.toHaveBeenCalled();
    expect(result).toEqual({ total: 0, done: [], failed: [], current: null });
  });
});
