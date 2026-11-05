/**
 * Gate 1 process-boundary spike. This exercises an actual OS subprocess,
 * NOT a provider SDK, authenticated session, ACP endpoint or packaged Desktop.
 * Run: node --test apps/desktop/scripts/spikes/process-boundary.test.mjs
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';

const childProgram = [
  "process.stdout.write(JSON.stringify({kind:'started',native_id:'fixture-1'})+'\\n')",
  "let n=0;const timer=setInterval(()=>{",
  "process.stdout.write(JSON.stringify({kind:'tick',seq:++n})+'\\n')",
  "},20)",
  "process.on('SIGTERM',()=>{clearInterval(timer);process.exit(143)})",
].join(';');

// The supervisor owns process lifecycle; consumers receive an async event stream.
// A close event is NOT a successful root completion or a resumable cursor.
/** Launch a disposable child with replayable, normalized process events. */
function launchFixture(program = childProgram) {
  const child = spawn(process.execPath, ['-e', program], {
    stdio: ['ignore', 'pipe', 'pipe'],
    shell: false,
    env: { PATH: process.env.PATH || '' },
  });
  let buffer = '';
  let done = false;
  const events = [];
  const waiters = [];
  const emit = event => {
    if (done) return;
    events.push(event);
    while (waiters.length) waiters.shift()();
  };
  child.stdout.setEncoding('utf8');
  child.stdout.on('data', chunk => {
    buffer += chunk;
    let end;
    while ((end = buffer.indexOf('\n')) >= 0) {
      const line = buffer.slice(0, end);
      buffer = buffer.slice(end + 1);
      try { emit({ type: 'provider_event', payload: JSON.parse(line) }); }
      catch { emit({ type: 'malformed_output' }); }
    }
  });
  child.stderr.setEncoding('utf8');
  child.stderr.on('data', chunk => emit({ type: 'stderr', text: chunk }));
  child.once('error', error => emit({ type: 'spawn_error', code: error.code || 'unknown' }));
  child.once('close', (code, signal) => {
    if (buffer.length > 0) {
      try { emit({ type: 'provider_event', payload: JSON.parse(buffer) }); }
      catch { emit({ type: 'malformed_output' }); }
      buffer = '';
    }
    emit({ type: 'process_closed', code, signal, root_status: 'interrupted', resumable: false });
    done = true;
    while (waiters.length) waiters.shift()();
  });
  async function* read() {
    let index = 0;
    while (true) {
      while (index < events.length) yield events[index++];
      if (done) return;
      await new Promise(resolve => waiters.push(resolve));
    }
  }
  return { child, read, cancel: () => child.kill('SIGTERM') };
}

/** Collect events until a predicate matches; cancel a stalled fixture. */
async function collectUntil(supervisor, predicate, timeoutMs = 3000) {
  const timer = setTimeout(() => supervisor.cancel(), timeoutMs);
  try {
    const result = [];
    for await (const event of supervisor.read()) {
      result.push(event);
      if (predicate(event)) return result;
    }
    return result;
  } finally { clearTimeout(timer); }
}

test('real child process streams structured lines and cancellation remains interrupted', async () => {
  const supervisor = launchFixture();
  try {
    const streamed = await collectUntil(supervisor,
      event => event.type === 'provider_event' && event.payload.kind === 'tick');
    assert.ok(streamed.some(event => event.payload?.kind === 'started'));
    assert.ok(streamed.some(event => event.payload?.kind === 'tick'));
    assert.equal(supervisor.cancel(), true);
    const rest = await collectUntil(supervisor, event => event.type === 'process_closed');
    const closed = rest.find(event => event.type === 'process_closed');
    assert.ok(closed, 'OS process must report close');
    assert.equal(closed.root_status, 'interrupted');
    assert.equal(closed.resumable, false);
    assert.ok(closed.code !== 0 || closed.signal, 'cancel must not look like successful completion');
  } finally { supervisor.cancel(); }
});

test('late subscribers replay the same ordered events without inventing success', async () => {
  const supervisor = launchFixture();
  try {
    await collectUntil(supervisor, event => event.payload?.kind === 'tick');
    supervisor.cancel();
    const first = await collectUntil(supervisor, event => event.type === 'process_closed');
    const second = await collectUntil(supervisor, event => event.type === 'process_closed');
    assert.deepEqual(first, second);
    const payloads = first.filter(event => event.type === 'provider_event').map(event => event.payload);
    assert.equal(payloads[0]?.kind, 'started');
    payloads.slice(1).forEach((payload, index) => assert.deepEqual(payload, { kind: 'tick', seq: index + 1 }));
    assert.equal(first.at(-1).type, 'process_closed');
    assert.equal(first.at(-1).root_status, 'interrupted');
    assert.equal(first.some(event => event.type === 'root_completed'), false);
  } finally { supervisor.cancel(); }
});

test('unterminated final stdout frame is retained before close, without inventing completion', async () => {
  const program = "process.stdout.write(JSON.stringify({kind:'last',seq:1}))";
  const supervisor = launchFixture(program);
  const events = await collectUntil(supervisor, event => event.type === 'process_closed');
  assert.deepEqual(events.map(event => event.type), ['provider_event', 'process_closed']);
  assert.deepEqual(events[0].payload, { kind: 'last', seq: 1 });
  assert.equal(events[1].root_status, 'interrupted');
  assert.equal(events[1].resumable, false);
});

test('stderr and malformed trailing stdout remain observable without being treated as success', async () => {
  const program = "process.stderr.write('provider failed\\n');process.stdout.write('{invalid');process.exitCode=1";
  const supervisor = launchFixture(program);
  const events = await collectUntil(supervisor, event => event.type === 'process_closed');
  assert.ok(events.some(event => event.type === 'stderr' && event.text.includes('provider failed')));
  assert.ok(events.some(event => event.type === 'malformed_output'));
  assert.equal(events.at(-1).type, 'process_closed');
  assert.equal(events.at(-1).root_status, 'interrupted');
  assert.equal(events.at(-1).code, 1);
});
