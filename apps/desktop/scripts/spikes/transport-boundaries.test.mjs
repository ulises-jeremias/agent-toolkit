import test from 'node:test';
import assert from 'node:assert/strict';
import { consumePull, consumePush } from './transport-boundaries.mjs';

const ids = { threadId: 'app-thread', runId: 'app-run' };
const e = (sequence, type, extra = {}) => ({ ...ids, sequence, type, ...extra });
const trace = [e(1, 'started', { providerCursor: 'opaque' }), e(2, 'child_started', { nodeId: 'child' }), e(3, 'child_completed', { nodeId: 'child' }), e(4, 'root_completed')];

function push(events, { finish = true } = {}) {
  return (onEvent, onEnd) => {
    queueMicrotask(() => {
      for (const event of events) onEvent(event);
      if (finish) onEnd();
    });
    return () => {};
  };
}

test('pull and push boundaries project identical app-owned events', async () => {
  const pull = await consumePull({ ids, events: (async function* () { yield* trace; })() });
  const pushed = await consumePush({ ids, subscribe: push(trace) });
  assert.deepEqual(pushed.events, pull.events);
  assert.equal(pushed.status, 'root_completed');
  assert.equal(pushed.providerCursor, 'opaque');
});

test('both boundaries reject gaps and cross-thread injection', async () => {
  for (const invalid of [e(3, 'root_completed'), { ...e(2, 'root_completed'), threadId: 'other' }]) {
    await assert.rejects(consumePull({ ids, events: (async function* () { yield trace[0]; yield invalid; })() }));
    await assert.rejects(consumePush({ ids, subscribe: push([trace[0], invalid]) }));
  }
});

test('push transport error does not invent completion', async () => {
  await assert.rejects(consumePush({
    ids,
    subscribe: (onEvent, onEnd, onError) => {
      queueMicrotask(() => { onEvent(trace[0]); onError(new Error('disconnected')); });
      return () => {};
    }
  }), /disconnected/);
});

test('pre-aborted signal rejects both transports', async () => {
  const controller = new AbortController();
  controller.abort();
  await assert.rejects(consumePull({ ids, events: (async function* () { yield* trace; })(), signal: controller.signal }), /cancelled/);
  await assert.rejects(consumePush({ ids, subscribe: push(trace), signal: controller.signal }), /cancelled/);
});

test('push synchronously ending source unsubscribes once', async () => {
  let count = 0;
  const projection = await consumePush({
    ids,
    subscribe: (onEvent, onEnd) => {
      trace.forEach(onEvent);
      onEnd();
      return () => { count++; };
    }
  });
  assert.equal(projection.status, 'root_completed');
  assert.equal(count, 1);
});

test('normal end without root terminal event is an error in both transports', async () => {
  const incomplete = [trace[0], trace[1]];
  await assert.rejects(
    consumePull({ ids, events: (async function* () { yield* incomplete; })() }),
    /before root terminal event/
  );
  await assert.rejects(
    consumePush({ ids, subscribe: push(incomplete) }),
    /before root terminal event/
  );
});

test('a clean root failure or interruption is a terminal transport outcome', async () => {
  for (const type of ['root_failed', 'cancelled', 'interrupted']) {
    const events = [trace[0], e(2, type)];
    const pull = await consumePull({ ids, events: (async function* () { yield* events; })() });
    const pushed = await consumePush({ ids, subscribe: push(events) });
    assert.equal(pull.status, type);
    assert.equal(pushed.status, type);
  }
});

test('push synchronous end without a root terminal event still unsubscribes', async () => {
  let unsubscribed = 0;
  await assert.rejects(consumePush({
    ids,
    subscribe: (onEvent, onEnd) => {
      onEvent(trace[0]);
      onEnd();
      return () => { unsubscribed++; };
    }
  }), /before root terminal event/);
  assert.equal(unsubscribed, 1);
});
