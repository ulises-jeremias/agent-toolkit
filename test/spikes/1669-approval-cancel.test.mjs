import test from 'node:test';
import assert from 'node:assert/strict';
import { SessionJournal } from '../../scripts/spikes/1669-session-journal.mjs';

// Gate 1 evidence level M: contract fixtures, NOT native provider approvals.
// A UI approval action cannot be inferred from text or a synthetic process exit.
test('approval is a blocking state until an explicit observed response', () => {
  const journal = new SessionJournal('approval-thread');
  journal.append({ type: 'start', runId: 'approval-run' });
  journal.append({ type: 'approval_required', runId: 'approval-run' });
  assert.equal(journal.status, 'awaiting_approval');
  assert.throws(() => journal.append({ type: 'output', runId: 'approval-run', text: 'ran unapproved tool' }), /invalid transition/);
  assert.throws(() => journal.append({ type: 'approval_observed', runId: 'approval-run' }), /approval observation required/);
  assert.equal(journal.status, 'awaiting_approval');
  journal.append({ type: 'approval_observed', runId: 'approval-run', approved: false });
  assert.equal(journal.status, 'running');
  assert.equal(journal.events.at(-1).approved, false);
  assert.ok(!journal.events.some(event => event.type === 'completed'));
});

test('cancel during pending approval is terminal only after observed cancellation', () => {
  const journal = new SessionJournal('cancel-approval-thread');
  journal.append({ type: 'start', runId: 'cancel-approval-run' });
  journal.append({ type: 'approval_required', runId: 'cancel-approval-run' });
  journal.append({ type: 'cancel_requested', runId: 'cancel-approval-run' });
  assert.equal(journal.status, 'cancelling');
  assert.throws(() => journal.append({ type: 'approval_observed', runId: 'cancel-approval-run', approved: true }), /invalid transition/);
  assert.throws(() => journal.append({ type: 'completed', runId: 'cancel-approval-run' }), /invalid transition/);
  assert.equal(journal.status, 'cancelling');
  journal.append({ type: 'cancelled', runId: 'cancel-approval-run' });
  assert.equal(journal.status, 'cancelled');
  assert.deepEqual(SessionJournal.replay(journal.threadId, journal.snapshot().events).snapshot(), journal.snapshot());
  assert.throws(() => journal.append({ type: 'output', runId: 'cancel-approval-run', text: 'late' }), /terminal run/);
});
