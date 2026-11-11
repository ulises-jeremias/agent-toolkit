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

test('child stderr is drained but never exposed in errors or session events', async () => {
  const secret = 'fixture-sensitive-provider-token-123';
  const journal = new SessionJournal('stderr-redaction');
  let failure;
  try {
    await projectTransport(processEvents(process.execPath, args(`
      console.log(JSON.stringify({type:'start',runId:'r'}));
      console.error('fixture-sensitive-provider-token-123');
      process.exit(9);
    `)), journal);
  } catch (error) {
    failure = error;
  }
  assert.ok(failure);
  assert.match(failure.message, /transport exited 9/);
  assert.ok(!failure.message.includes(secret));
  assert.ok(!JSON.stringify(journal.snapshot()).includes(secret));
  assert.equal(journal.status, 'interrupted');
});

test('completion followed by child crash never reports successful journal state', async () => {
  const journal = new SessionJournal('crash-after-complete');
  await assert.rejects(projectTransport(processEvents(process.execPath, args(`
    console.log(JSON.stringify({type:'start',runId:'r'}));
    console.log(JSON.stringify({type:'completed',runId:'r'}));
    process.exit(12);
  `)), journal), /transport exited 12/);
  assert.equal(journal.status, 'interrupted');
  assert.ok(!journal.events.some(event => event.type === 'completed'));
});

test('events after completion are rejected rather than silently accepted', async () => {
  const journal = new SessionJournal('after-complete');
  await assert.rejects(projectTransport(processEvents(process.execPath, args(`
    console.log(JSON.stringify({type:'start',runId:'r'}));
    console.log(JSON.stringify({type:'completed',runId:'r'}));
    console.log(JSON.stringify({type:'output',runId:'r',text:'late'}));
  `)), journal), /event after transport completion/);
  assert.equal(journal.status, 'interrupted');
});

test('large stderr output cannot deadlock the supervised process or leak secrets', async () => {
  const secret = 'fixture-secret-stderr-backpressure';
  const journal = new SessionJournal('stderr-backpressure');
  const result = await Promise.race([
    projectTransport(processEvents(process.execPath, args(`
      console.log(JSON.stringify({type:'start',runId:'r'}));
      const chunk = 'fixture-secret-stderr-backpressure'.repeat(2048);
      for (let i = 0; i < 128; i++) process.stderr.write(chunk);
      console.log(JSON.stringify({type:'completed',runId:'r'}));
    `)), journal),
    new Promise((_, reject) => setTimeout(() => reject(new Error('stderr drain timed out')), 10000)),
  ]);
  assert.equal(result.status, 'completed');
  assert.ok(!JSON.stringify(result).includes(secret));
});

// Regression #1755: a child may emit unbounded bytes without a newline.
test('oversized unterminated stdout fails closed and reaps a stubborn child', async () => {
  const journal = new SessionJournal('oversized-unterminated');
  const started = Date.now();
  await assert.rejects(projectTransport(processEvents(process.execPath, args(`
    process.on('SIGTERM', () => {});
    process.stdout.write(JSON.stringify({type:'start',runId:'oversized-unterminated'}) + '\\n');
    process.stdout.write('x'.repeat(1024 * 1024 + 128));
    setInterval(() => {}, 1000);
  `)), journal), /oversized transport event/);
  assert.ok(Date.now() - started < 8000, 'oversized child must be reaped promptly');
  assert.equal(journal.status, 'interrupted');
  assert.ok(!journal.events.some(event => event.type === 'completed'));
});

test('multibyte JSONL bytes are bounded before decoding', async () => {
  const journal = new SessionJournal('oversized-multibyte');
  await assert.rejects(projectTransport(processEvents(process.execPath, args(`
    console.log(JSON.stringify({type:'start',runId:'oversized-multibyte'}));
    console.log(JSON.stringify({type:'output',text:'🪺'.repeat(300000)}));
  `)), journal), /oversized transport event/);
  assert.equal(journal.status, 'interrupted');
});
