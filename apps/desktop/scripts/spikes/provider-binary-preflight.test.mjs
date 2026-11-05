import test from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { probeBinary, probeAll, PROVIDERS } from './provider-binary-preflight.mjs';

function fakeSpawn({ code = 0, stdout = 'version 1.0', error = null, neverClose = false } = {}) {
  return (command, args, options) => {
    assert.ok(PROVIDERS.includes(command));
    assert.deepEqual(args, ['--version']);
    assert.equal(options.shell, false);
    const child = new EventEmitter();
    child.stdout = new EventEmitter();
    child.stderr = new EventEmitter();
    child.kill = () => { child.killed = true; return true; };
    queueMicrotask(() => {
      if (error) child.emit('error', Object.assign(new Error(error), { code: error }));
      else if (!neverClose) {
        child.stdout.emit('data', Buffer.from(stdout));
        child.emit('close', code, null);
      }
    });
    return child;
  };
}

test('only supported binaries are probed with no shell and no auth claim', async () => {
  const results = await probeAll({ spawnFn: fakeSpawn() });
  assert.deepEqual(results.map(x => x.provider), [...PROVIDERS]);
  for (const result of results) {
    assert.equal(result.status, 'binary_present');
    assert.equal(result.authenticated, 'unverified');
    assert.equal(result.session, 'unverified');
  }
  await assert.rejects(probeBinary('sh'), /unsupported provider/);
});

test('missing binary is unavailable, never authenticated', async () => {
  const result = await probeBinary('codex', { spawnFn: fakeSpawn({ error: 'ENOENT' }) });
  assert.equal(result.status, 'unavailable');
  assert.equal(result.reason, 'ENOENT');
  assert.equal(result.authenticated, 'unverified');
});

test('nonzero version exit is not a successful binary probe', async () => {
  const result = await probeBinary('claude', { spawnFn: fakeSpawn({ code: 1 }) });
  assert.equal(result.status, 'version_failed');
  assert.equal(result.exitCode, 1);
});

test('hung version probe is bounded and remains unverified', async () => {
  const result = await probeBinary('opencode', {
    timeoutMs: 15,
    spawnFn: fakeSpawn({ neverClose: true }),
  });
  assert.equal(result.status, 'timeout');
  assert.equal(result.session, 'unverified');
});
