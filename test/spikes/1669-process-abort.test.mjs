import test from 'node:test';
import assert from 'node:assert/strict';
import { processEvents } from '../../scripts/spikes/1669-process-transport.mjs';
import { SessionJournal, projectTransport } from '../../scripts/spikes/1669-session-journal.mjs';

// Gate 1 evidence level M: a real OS child, synthetic fixture events.
// Abort is not provider-native cancellation or authenticated acceptance.
test('abort of a running child interrupts rather than completing the journal', async () => {
  const controller = new AbortController();
  const journal = new SessionJournal('abort-fixture');
  const body = `
    console.log(JSON.stringify({type:'start',runId:'abort-run'}));
    setInterval(() => {}, 1000);
  `;
  const events = processEvents(process.execPath, ['--input-type=module', '-e', body], {
    signal: controller.signal,
  });
  const projection = projectTransport(events, journal);
  // Wait for the actual start event, rather than relying on a timer.
  const deadline = Date.now() + 5000;
  while (journal.status === 'idle' && Date.now() < deadline) {
    await new Promise(resolve => setTimeout(resolve, 10));
  }
  assert.equal(journal.status, 'running', 'child must start before cancellation');
  controller.abort();
  await assert.rejects(projection, error => error?.name === 'AbortError' || /abort/i.test(error?.message ?? ''));
  assert.equal(journal.status, 'interrupted');
  assert.equal(journal.events.at(-1).reason, 'transport-error');
  assert.ok(!journal.events.some(event => event.type === 'completed'));
});
