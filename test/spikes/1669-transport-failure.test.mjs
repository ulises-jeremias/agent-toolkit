import test from 'node:test';
import assert from 'node:assert/strict';
import { SessionJournal, projectTransport } from '../../scripts/spikes/1669-session-journal.mjs';

// Gate 1: deterministic transport-contract regression tests (M evidence only).
// These deliberately do not claim provider auth, resume or packaged Desktop acceptance.
test('invalid event after a valid start interrupts rather than preserving a phantom running session', async () => {
  async function* invalidTransport() {
    yield { type: 'start', runId: 'r1' };
    yield { type: 'output', runId: 'foreign-run', text: 'spoofed' };
  }
  const journal = new SessionJournal('thread');
  await assert.rejects(projectTransport(invalidTransport(), journal), /cross-run event rejected/);
  assert.equal(journal.status, 'interrupted');
  assert.deepEqual(journal.events.map(event => event.type), ['start', 'interrupted']);
  assert.equal(journal.events[1].reason, 'transport-error');
  assert.deepEqual(SessionJournal.replay('thread', journal.events).snapshot(), journal.snapshot());
});

test('transport error during cancellation does not convert a request into a confirmed cancel', async () => {
  async function* disconnected() {
    yield { type: 'start', runId: 'r1' };
    yield { type: 'cancel_requested', runId: 'r1' };
    throw new Error('transport disconnected');
  }
  const journal = new SessionJournal('thread');
  await assert.rejects(projectTransport(disconnected(), journal), /transport disconnected/);
  assert.equal(journal.status, 'interrupted');
  assert.deepEqual(journal.events.map(event => event.type), ['start', 'cancel_requested', 'interrupted']);
  assert.deepEqual(SessionJournal.replay('thread', journal.events).snapshot(), journal.snapshot());
});

test('confirmed terminal event remains terminal on clean EOF', async () => {
  for (const type of ['completed', 'failed', 'cancelled']) {
    async function* terminalTransport() {
      yield { type: 'start', runId: 'r1' };
      if (type === 'cancelled') yield { type: 'cancel_requested', runId: 'r1' };
      yield { type, runId: 'r1' };
    }
    const journal = new SessionJournal('thread');
    const snapshot = await projectTransport(terminalTransport(), journal);
    assert.equal(snapshot.status, type);
    assert.equal(snapshot.events.at(-1).type, type);
    assert.deepEqual(SessionJournal.replay('thread', snapshot.events).snapshot(), snapshot);
  }
});
