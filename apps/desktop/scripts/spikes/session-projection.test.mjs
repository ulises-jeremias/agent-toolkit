import test from 'node:test';
import assert from 'node:assert/strict';
import { SessionProjection } from './session-projection.mjs';

const ids = { threadId: 'thread-local-1', runId: 'run-local-1' };
const event = (sequence, type, extra = {}) => ({ ...ids, sequence, type, ...extra });

test('child completion cannot complete root; replay is deterministic and deduplicated', () => {
  const p = new SessionProjection(ids);
  const events = [
    event(1, 'started', { providerCursor: 'opaque-native-ref' }),
    event(2, 'child_started', { nodeId: 'tool-1' }),
    event(3, 'child_completed', { nodeId: 'tool-1' }),
    event(4, 'root_completed')
  ];
  events.forEach(e => p.apply(e));
  assert.equal(p.status, 'root_completed');
  assert.equal(p.apply(events[3]), false);
  assert.deepEqual(SessionProjection.replay(ids, events).events, p.events);
  assert.equal(p.providerCursor, 'opaque-native-ref');
});

test('reject event gaps, stale conflicts and cross-session leakage without advancing cursor', () => {
  const p = new SessionProjection(ids);
  p.apply(event(1, 'started'));
  assert.throws(() => p.apply(event(3, 'root_completed')), /gap/);
  assert.throws(() => p.apply({ ...event(2, 'root_completed'), runId: 'other' }), /cross-session/);
  assert.throws(() => p.apply(event(1, 'root_failed')), /conflicting/);
  assert.equal(p.lastSequence, 1);
  p.apply(event(2, 'root_completed'));
  assert.throws(() => p.apply(event(3, 'started')), /terminal/);
});

test('approval must resolve exactly once; unresolved approval blocks root completion', () => {
  const p = new SessionProjection(ids);
  p.apply(event(1, 'started'));
  p.apply(event(2, 'approval_requested', { nodeId: 'approval-1' }));
  assert.equal(p.status, 'needs_approval');
  assert.throws(() => p.apply(event(3, 'root_completed')), /unfinished/);
  p.apply(event(3, 'approval_resolved', { nodeId: 'approval-1', approved: false }));
  assert.equal(p.nodes.get('approval-1'), 'denied');
  assert.throws(() => p.apply(event(4, 'approval_resolved', { nodeId: 'approval-1' })), /unknown approval/);
  p.apply(event(4, 'root_completed'));
});

test('crash recovery marks a running session interrupted, never falsely resumed', () => {
  const events = [event(1, 'started'), event(2, 'child_started', { nodeId: 'child-1' })];
  const p = SessionProjection.replay(ids, events, { afterCrash: true });
  assert.equal(p.status, 'interrupted');
  assert.equal(p.nodes.get('child-1'), 'running'); // last observed state, not live presence
  assert.throws(() => p.apply(event(3, 'root_completed')), /terminal/);
});

test('unverified provider capabilities are not inferred from a native cursor', () => {
  const p = new SessionProjection(ids);
  p.apply(event(1, 'started', { providerCursor: 'opaque' }));
  assert.equal(p.status, 'running');
  assert.equal('resumeSupported' in p, false);
});

test('resolving one of two approvals does not clear the remaining approval', () => {
  const p = new SessionProjection(ids);
  p.apply(event(1, 'started'));
  p.apply(event(2, 'approval_requested', { nodeId: 'approval-a' }));
  p.apply(event(3, 'approval_requested', { nodeId: 'approval-b' }));
  p.apply(event(4, 'approval_resolved', { nodeId: 'approval-a', approved: true }));
  assert.equal(p.status, 'needs_approval');
  assert.throws(() => p.apply(event(5, 'root_completed')), /unfinished/);
  p.apply(event(5, 'approval_resolved', { nodeId: 'approval-b', approved: false }));
  assert.equal(p.status, 'running');
  p.apply(event(6, 'root_completed'));
  assert.equal(p.status, 'root_completed');
});
