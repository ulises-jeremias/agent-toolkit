import test from 'node:test';
import assert from 'node:assert/strict';
import { SessionJournal, projectTransport } from '../../scripts/spikes/1669-session-journal.mjs';

// Gate 1 hermetic evidence (M): a malformed provider payload after a valid
// start must not leave a phantom running session or silently advance the cursor.
test('uncloneable streamed payload interrupts an active run without recording partial output', async () => {
  async function* transport() {
    yield { type: 'start', runId: 'real-run', nativeCursor: 'opaque-cursor' };
    yield { type: 'output', runId: 'real-run', text: 'unsafe', payload: { fn: () => {} } };
  }
  const journal = new SessionJournal('app-thread');
  await assert.rejects(projectTransport(transport(), journal), /could not be cloned|DataCloneError/);
  assert.equal(journal.status, 'interrupted');
  assert.equal(journal.nativeCursor, 'opaque-cursor');
  assert.deepEqual(journal.events.map(e => e.type), ['start', 'interrupted']);
  assert.deepEqual(journal.events.map(e => e.sequence), [1, 2]);
  assert.equal(journal.events[1].reason, 'transport-error');
  assert.deepEqual(SessionJournal.replay('app-thread', journal.events).snapshot(), journal.snapshot());
});
