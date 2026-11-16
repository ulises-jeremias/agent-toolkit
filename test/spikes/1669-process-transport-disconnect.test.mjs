import test from 'node:test';
import assert from 'node:assert/strict';
import { processEvents } from '../../scripts/spikes/1669-process-transport.mjs';

const nodeArgs = source => ['--input-type=module', '-e', source];

// Gate 1 fixture only. Closing a Focus stream is not permission to orphan
// a provider-like child; no real Claude/Codex/OpenCode protocol is assumed.
test('consumer disconnect reaps a SIGTERM-resistant subprocess', async () => {
  const started = Date.now();
  const events = [];
  for await (const event of processEvents(process.execPath, nodeArgs(`
    process.on('SIGTERM', () => {});
    console.log(JSON.stringify({ type: 'start', runId: 'disconnect-fixture' }));
    setInterval(() => {}, 1000);
  `))) {
    events.push(event);
    break; // e.g. Focus closes its event subscription mid-run
  }
  assert.deepEqual(events.map(event => event.type), ['start']);
  assert.ok(Date.now() - started < 8000, 'disconnect must reap the child promptly');
});
