import { describe, expect, it } from 'vitest';
import { DialogOpeningGuard } from './dialogOpeningGuard';

describe('DialogOpeningGuard', () => {
  it('rejects completion from a closed and reopened dialog of the same type', () => {
    const guard = new DialogOpeningGuard();
    guard.observe('start-job');
    const first = guard.capture('start-job');
    guard.invalidate(); // close, before the router has rendered
    guard.observe(null);
    guard.observe('start-job');
    const second = guard.capture('start-job');
    expect(first()).toBe(false);
    expect(second()).toBe(true);
  });

  it('rejects completion from a previous dialog type and preserves deep-link changes', () => {
    const guard = new DialogOpeningGuard();
    guard.observe('run-loop');
    const loop = guard.capture('run-loop');
    guard.observe('start-job');
    expect(loop()).toBe(false);
    expect(guard.capture('start-job')()).toBe(true);
  });

  it('invalidates a pending completion immediately on close even before rerender', () => {
    const guard = new DialogOpeningGuard();
    guard.observe('start-job');
    const pending = guard.capture('start-job');
    guard.invalidate();
    expect(pending()).toBe(false);
  });

  it('does not invalidate callbacks on unrelated renders', () => {
    const guard = new DialogOpeningGuard();
    guard.observe('run-loop');
    const pending = guard.capture('run-loop');
    guard.observe('run-loop');
    expect(pending()).toBe(true);
  });
});
