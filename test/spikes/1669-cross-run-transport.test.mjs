import test from 'node:test';
import assert from 'node:assert/strict';
import { processEvents } from '../../scripts/spikes/1669-process-transport.mjs';
import { SessionJournal, projectTransport } from '../../scripts/spikes/1669-session-journal.mjs';

// Gate 1 evidence level M: real OS subprocess with synthetic provider frames.
// This is not evidence of authenticated providers or a packaged Desktop.
test('cross-run subprocess frames cannot contaminate an active session', async () => {
  const journal = new SessionJournal('cross-run-fixture');
  const body = [
    { type: 'start', runId: 'owned-run' },
    { type: 'output', runId: 'foreign-run', text: 'must not appear' },
    { type: 'completed', runId: 'owned-run' },
  ].map(frame => 'console.log(' + JSON.stringify(JSON.stringify(frame)) + ')').join(';');
  await assert.rejects(
    projectTransport(processEvents(process.execPath, ['--input-type=module', '-e', body]), journal),
    /cross-run event rejected/,
  );
  assert.equal(journal.status, 'interrupted');
  assert.equal(journal.run, 'owned-run');
  assert.ok(!journal.events.some(event => event.runId === 'foreign-run'));
  assert.ok(!journal.events.some(event => event.type === 'completed'));
});

test('provider completion without a start cannot fabricate a run', async () => {
  const journal = new SessionJournal('orphan-completion-fixture');
  const body = "console.log(JSON.stringify({type:'completed',runId:'orphan'}))";
  await assert.rejects(
    projectTransport(processEvents(process.execPath, ['--input-type=module', '-e', body]), journal),
    /run must start first/,
  );
  assert.equal(journal.status, 'idle');
  assert.equal(journal.run, null);
  assert.deepEqual(journal.events, []);
});
