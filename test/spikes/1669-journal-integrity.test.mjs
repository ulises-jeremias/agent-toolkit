import test from 'node:test';
import assert from 'node:assert/strict';
import { SessionJournal } from '../../scripts/spikes/1669-session-journal.mjs';

// Gate 1 evidence level M only: deterministic journal integrity, not provider E2E.
test('replay rejects missing, duplicated, reordered and cross-thread records', () => {
  const journal = new SessionJournal('integrity-thread');
  journal.append({ type: 'start', runId: 'integrity-run' });
  journal.append({ type: 'output', runId: 'integrity-run', text: 'observed' });
  journal.append({ type: 'completed', runId: 'integrity-run' });
  const events = journal.snapshot().events;
  assert.deepEqual(SessionJournal.replay(journal.threadId, events).snapshot(), journal.snapshot());
  for (const corrupted of [
    events.slice(1),
    [events[0], events[0], events[2]],
    [events[1], events[0], events[2]],
    events.map((event, i) => i === 1 ? { ...event, threadId: 'other-thread' } : event),
    events.map((event, i) => i === 1 ? { ...event, runId: 'other-run' } : event),
  ]) {
    assert.throws(() => SessionJournal.replay(journal.threadId, corrupted));
  }
});

test('invalid events are atomic and do not consume a sequence number', () => {
  const journal = new SessionJournal('atomic-thread');
  journal.append({ type: 'start', runId: 'atomic-run' });
  const before = journal.snapshot();
  assert.throws(() => journal.append({ type: 'output', runId: 'atomic-run', text: 123 }), /output text required/);
  assert.throws(() => journal.append({ type: 'approval_observed', runId: 'atomic-run', approved: true }), /invalid transition/);
  assert.throws(() => journal.append({ type: 'completed', runId: 'foreign-run' }), /cross-run/);
  assert.deepEqual(journal.snapshot(), before);
  const accepted = journal.append({ type: 'output', runId: 'atomic-run', text: 'valid' });
  assert.equal(accepted.sequence, 2);
  assert.deepEqual(SessionJournal.replay(journal.threadId, journal.snapshot().events).snapshot(), journal.snapshot());
});
