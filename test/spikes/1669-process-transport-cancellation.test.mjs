import test from 'node:test';
import assert from 'node:assert/strict';
import { processEvents } from '../../scripts/spikes/1669-process-transport.mjs';

const nodeArgs = source => ['--input-type=module', '-e', source];

// Gate 1 tests exercise only a disposable JSONL child, not a real provider.
test('cancellation reaps a SIGTERM-resistant child without reporting completion', async () => {
  const controller = new AbortController();
  const events = [];
  const started = Date.now();
  const child = processEvents(process.execPath, nodeArgs(`
    process.on('SIGTERM', () => {});
    console.log(JSON.stringify({ type: 'start', runId: 'cancel-fixture' }));
    setInterval(() => {}, 1000);
  `), { signal: controller.signal });

  await assert.rejects(async () => {
    for await (const event of child) {
      events.push(event);
      if (event.type === 'start') controller.abort();
    }
  }, error => error?.name === 'AbortError');
  assert.deepEqual(events.map(event => event.type), ['start']);
  assert.ok(Date.now() - started < 8000, 'aborted child must be reaped promptly');
});

test('duplicate completion cannot be accepted as a successful run', async () => {
  const events = [];
  await assert.rejects(async () => {
    for await (const event of processEvents(process.execPath, nodeArgs(`
      console.log(JSON.stringify({ type: 'start', runId: 'duplicate-fixture' }));
      console.log(JSON.stringify({ type: 'completed', runId: 'duplicate-fixture' }));
      console.log(JSON.stringify({ type: 'completed', runId: 'duplicate-fixture' }));
    `))) events.push(event);
  }, /duplicate transport completion/);
  assert.deepEqual(events.map(event => event.type), ['start']);
});
