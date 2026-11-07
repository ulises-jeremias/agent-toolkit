import test from 'node:test';
import assert from 'node:assert/strict';
import { processEvents } from '../../scripts/spikes/1669-process-transport.mjs';
import { SessionJournal, projectTransport } from '../../scripts/spikes/1669-session-journal.mjs';

const args = body => ['--input-type=module', '-e', body];
const run = body => projectTransport(processEvents(process.execPath, args(body)), new SessionJournal('fixture-thread'));

test('actual child process projects ordered events and terminal completion', async () => {
  const result = await run(`
    console.log(JSON.stringify({type:'start',runId:'r',nativeCursor:'opaque-fixture'}));
    console.log(JSON.stringify({type:'output',runId:'r',text:'child stdout'}));
    console.log(JSON.stringify({type:'completed',runId:'r'}));
  `);
  assert.equal(result.status, 'completed');
  assert.deepEqual(result.events.map(e => e.sequence), [1, 2, 3]);
  assert.deepEqual(SessionJournal.replay('fixture-thread', result.events).snapshot(), result);
});

test('zero exit without terminal event is interruption, not success', async () => {
  const result = await run(`console.log(JSON.stringify({type:'start',runId:'r'}))`);
  assert.equal(result.status, 'interrupted');
  assert.equal(result.events.at(-1).reason, 'transport-eof');
});

test('nonzero child exit interrupts the journal and preserves failure', async () => {
  const journal = new SessionJournal('t');
  await assert.rejects(projectTransport(processEvents(process.execPath, args(`
    console.log(JSON.stringify({type:'start',runId:'r'}));
    process.exit(7);
  `)), journal), /transport exited 7/);
  assert.equal(journal.status, 'interrupted');
  assert.equal(journal.events.at(-1).reason, 'transport-error');
});

test('malformed JSONL is rejected without inventing provider events', async () => {
  await assert.rejects(run(`console.log('bad-json')`), /invalid JSONL/);
});

test('missing executable is reported without hanging', async () => {
  await assert.rejects(
    projectTransport(processEvents('/definitely-not-installed-atk-provider'), new SessionJournal('t')),
    /ENOENT/,
  );
});
