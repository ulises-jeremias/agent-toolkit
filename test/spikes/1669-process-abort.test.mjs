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
  try {
    assert.equal(journal.status, 'running', 'child must start before cancellation');
    controller.abort();
    await assert.rejects(projection, error => error?.name === 'AbortError' || /abort/i.test(error?.message ?? ''));
    assert.equal(journal.status, 'interrupted');
    assert.equal(journal.events.at(-1).reason, 'transport-error');
    assert.ok(!journal.events.some(event => event.type === 'completed'));
  } finally {
    // A failed assertion before abort must not leave the interval child alive
    // and hang the Node test runner. Always settle the projection as well.
    controller.abort();
    await projection.catch(() => {});
  }
});

test('a completion frame followed by a hung child cannot become success on abort', async () => {
  const controller = new AbortController();
  const journal = new SessionJournal('abort-after-completion');
  const body = `
    console.log(JSON.stringify({type:'start',runId:'pending-run'}));
    console.log(JSON.stringify({type:'completed',runId:'pending-run'}));
    setInterval(() => {}, 1000);
  `;
  const projection = projectTransport(
    processEvents(process.execPath, ['--input-type=module', '-e', body], {
      signal: controller.signal,
    }),
    journal,
  );
  try {
    const deadline = Date.now() + 5000;
    while (journal.status === 'idle' && Date.now() < deadline) {
      await new Promise(resolve => setTimeout(resolve, 10));
    }
    assert.equal(journal.status, 'running');
    // The transport must withhold the child's completion until successful exit.
    assert.ok(!journal.events.some(event => event.type === 'completed'));
    controller.abort();
    await assert.rejects(projection, error => error?.name === 'AbortError' || /abort/i.test(error?.message ?? ''));
    assert.equal(journal.status, 'interrupted');
    assert.ok(!journal.events.some(event => event.type === 'completed'));
  } finally {
    controller.abort();
    await projection.catch(() => {});
  }
});

// Regression: child.kill('SIGTERM') may set signalCode before the process\n// exits; escalation must still SIGKILL the live child within the deadline.\ntest('malformed transport kills a child that ignores graceful termination', async () => {
  if (process.platform === 'win32') return; // POSIX signal behavior is required.
  const body = `
    process.on('SIGTERM', () => {});
    console.log('not-json');
    setInterval(() => {}, 1000);
  `;
  const started = Date.now();
  await assert.rejects(
    async () => {
      for await (const _event of processEvents(process.execPath, ['--input-type=module', '-e', body])) {
        // Invalid JSON must reject before any event is yielded.
      }
    },
    /invalid JSONL transport event/,
  );
  assert.ok(Date.now() - started < 4000, 'teardown must not wait forever for SIGTERM');
});
