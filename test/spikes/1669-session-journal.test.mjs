import test from 'node:test';
import assert from 'node:assert/strict';
import { SessionJournal, projectTransport } from '../../scripts/spikes/1669-session-journal.mjs';

test('sidecar-shaped async stream preserves ordered app identity and native cursor', async () => {
  async function* sidecar() {
    yield { type: 'start', runId: 'r1', nativeCursor: 'native-opaque' };
    yield { type: 'output', runId: 'r1', text: 'hello' };
    yield { type: 'completed', runId: 'r1' };
  }
  const journal = new SessionJournal('thread-1');
  const result = await projectTransport(sidecar(), journal);
  assert.equal(result.status, 'completed');
  assert.equal(result.nativeCursor, 'native-opaque');
  assert.deepEqual(result.events.map(e => e.sequence), [1, 2, 3]);
  assert.deepEqual(SessionJournal.replay('thread-1', result.events).snapshot(), result);
});
test('in-process-shaped stream supports approval observation and honest interruption', async () => {
  const j = new SessionJournal('thread-2');
  j.append({ type: 'start', runId: 'r2' });
  j.append({ type: 'approval_required', runId: 'r2' });
  j.append({ type: 'approval_observed', runId: 'r2', approved: false });
  j.append({ type: 'interrupted', runId: 'r2', reason: 'supervisor-lost' });
  assert.equal(j.status, 'interrupted');
  assert.deepEqual(SessionJournal.replay('thread-2', j.snapshot().events).snapshot(), j.snapshot());
  assert.throws(() => j.append({ type: 'completed', runId: 'r2' }), /terminal/);
});
test('cancel is a request, not success, until transport confirms termination', () => {
  const j = new SessionJournal('t');
  j.append({ type: 'start', runId: 'r' });
  j.append({ type: 'cancel_requested', runId: 'r' });
  assert.equal(j.status, 'cancelling');
  assert.throws(() => j.append({ type: 'completed', runId: 'r' }), /invalid transition/);
  j.append({ type: 'cancelled', runId: 'r' });
  assert.equal(j.status, 'cancelled');
});
test('rejects foreign run, corrupt replay, and unsupported transition', () => {
  const j = new SessionJournal('t');
  assert.throws(() => j.append({ type: 'output', runId: 'r', text: 'bad' }), /start first/);
  j.append({ type: 'start', runId: 'r' });
  assert.throws(() => j.append({ type: 'output', runId: 'other', text: 'bad' }), /cross-run/);
  assert.throws(() => j.append({ type: 'approval_observed', runId: 'r', approved: true }), /invalid transition/);
  assert.throws(() => SessionJournal.replay('other', j.snapshot().events), /corrupt/);
});

test('rejected start leaves journal pristine and permits a different valid run', () => {
  const j = new SessionJournal('t');
  assert.throws(() => j.append({ type: 'start', runId: 'invalid', nativeCursor: 42 }), /invalid native cursor/);
  assert.deepEqual(j.snapshot(), { threadId: 't', runId: null, status: 'idle', nativeCursor: null, events: [] });
  j.append({ type: 'start', runId: 'valid' });
  assert.equal(j.snapshot().runId, 'valid');
});
