import test from 'node:test';
import assert from 'node:assert/strict';
import { processEvents } from './1669-process-transport.mjs';
import { SessionJournal, projectTransport } from './1669-session-journal.mjs';

// Gate 1 competing-boundary experiment. The child is an isolated JSONL fixture,
// NOT T3 Code, ACP, or an authenticated coding provider. This demonstrates only
// that a sidecar can share the journal's identity, ordering and failure semantics.
function fixture(source, options = {}) {
  return processEvents(process.execPath, ['-e', source], options);
}
const emit = (events) => events.map(e => `process.stdout.write(${JSON.stringify(JSON.stringify(e) + '\\n')});`).join('\n');

test('sidecar JSONL preserves app-owned identity, output and authoritative completion', async () => {
  const source = emit([
    { type: 'start', runId: 'run-1', nativeCursor: 'provider-owned-cursor' },
    { type: 'output', runId: 'run-1', text: 'test output' },
    { type: 'completed', runId: 'run-1' },
  ]);
  const journal = new SessionJournal('thread-1');
  const snapshot = await projectTransport(fixture(source), journal);
  assert.equal(snapshot.threadId, 'thread-1');
  assert.equal(snapshot.runId, 'run-1');
  assert.equal(snapshot.nativeCursor, 'provider-owned-cursor');
  assert.equal(snapshot.status, 'completed');
  assert.deepEqual(snapshot.events.map(e => e.sequence), [1, 2, 3]);
  assert.deepEqual(SessionJournal.replay('thread-1', snapshot.events).snapshot(), snapshot);
});

test('sidecar clean EOF without completion is interrupted, not successful', async () => {
  const journal = new SessionJournal('thread-eof');
  const snapshot = await projectTransport(fixture(emit([
    { type: 'start', runId: 'run-eof' },
    { type: 'output', runId: 'run-eof', text: 'partial' },
  ])), journal);
  assert.equal(snapshot.status, 'interrupted');
  assert.equal(snapshot.events.at(-1).reason, 'transport-eof');
});

test('sidecar child crash rejects and records interrupted state', async () => {
  const journal = new SessionJournal('thread-crash');
  const source = emit([{ type: 'start', runId: 'run-crash' }]) + '\nprocess.exitCode = 7;';
  await assert.rejects(projectTransport(fixture(source), journal), /transport exited 7/);
  assert.equal(journal.status, 'interrupted');
  assert.equal(journal.events.at(-1).reason, 'transport-error');
});

test('sidecar with no start fails closed', async () => {
  const journal = new SessionJournal('thread-empty');
  await assert.rejects(projectTransport(fixture(''), journal), /transport ended before start/);
  assert.equal(journal.status, 'idle');
});
