import test from 'node:test';
import assert from 'node:assert/strict';
import { SessionJournal } from '../../scripts/spikes/1669-session-journal.mjs';

// Gate 1 level M: synthetic events only, not a provider-authenticated session.
test('provider reuse of nested event payload cannot rewrite previously observed history', () => {
  const journal = new SessionJournal('immutable-thread');
  journal.append({ type: 'start', runId: 'immutable-run' });
  const payload = { tool: { name: 'read', args: { path: 'safe.txt' } } };
  journal.append({ type: 'output', runId: 'immutable-run', text: 'reading', payload });
  const observed = journal.snapshot();
  payload.tool.args.path = 'rewritten.txt';
  assert.equal(journal.events[1].payload.tool.args.path, 'safe.txt');
  assert.deepEqual(journal.snapshot(), observed);
});

test('editing a returned snapshot cannot corrupt live journal or future replay', () => {
  const journal = new SessionJournal('snapshot-thread');
  journal.append({ type: 'start', runId: 'snapshot-run' });
  journal.append({ type: 'output', runId: 'snapshot-run', text: 'ok', payload: { tool: { name: 'test' } } });
  const snapshot = journal.snapshot();
  snapshot.events[1].payload.tool.name = 'tampered';
  assert.equal(journal.snapshot().events[1].payload.tool.name, 'test');
  assert.deepEqual(SessionJournal.replay(journal.threadId, journal.snapshot().events).snapshot(), journal.snapshot());
});
