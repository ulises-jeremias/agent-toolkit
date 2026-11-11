import test from 'node:test';
import assert from 'node:assert/strict';
import { processEvents } from '../../scripts/spikes/1669-process-transport.mjs';
import { SessionJournal, projectTransport } from '../../scripts/spikes/1669-session-journal.mjs';

// Gate 1 M-level synthetic process evidence, not authenticated provider acceptance.
// A clean OS exit is not proof that a provider run completed.
test('zero exit after start but without completion remains interrupted', async () => {
  const journal = new SessionJournal('eof-without-completion');
  const body = "console.log(JSON.stringify({type:'start',runId:'eof-run'}))";
  const snapshot = await projectTransport(
    processEvents(process.execPath, ['--input-type=module', '-e', body]),
    journal,
  );
  assert.equal(snapshot.status, 'interrupted');
  assert.equal(snapshot.events.at(-1).reason, 'transport-eof');
  assert.ok(!snapshot.events.some(event => event.type === 'completed'));
});

test('zero exit without any session events rejects without fabricating a run', async () => {
  const journal = new SessionJournal('empty-eof');
  await assert.rejects(
    projectTransport(processEvents(process.execPath, ['--input-type=module', '-e', '']), journal),
    /transport ended before start/,
  );
  assert.equal(journal.status, 'idle');
  assert.equal(journal.run, null);
  assert.deepEqual(journal.events, []);
});
