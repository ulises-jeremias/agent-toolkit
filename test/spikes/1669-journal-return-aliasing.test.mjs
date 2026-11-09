import test from 'node:test';
import assert from 'node:assert/strict';
import { SessionJournal } from '../../scripts/spikes/1669-session-journal.mjs';

// Gate 1 evidence level M: synthetic journal isolation, not a live provider.
test('append return value cannot mutate stored nested event payload', () => {
  const journal = new SessionJournal('return-alias-thread');
  journal.append({ type: 'start', runId: 'return-alias-run' });
  const returned = journal.append({
    type: 'output',
    runId: 'return-alias-run',
    text: 'observed',
    payload: { tool: { args: { path: 'original.txt' } } },
  });
  const before = journal.snapshot();
  returned.payload.tool.args.path = 'tampered.txt';
  assert.equal(journal.snapshot().events[1].payload.tool.args.path, 'original.txt');
  assert.deepEqual(journal.snapshot(), before);
  assert.deepEqual(SessionJournal.replay(journal.threadId, journal.snapshot().events).snapshot(), before);
});
