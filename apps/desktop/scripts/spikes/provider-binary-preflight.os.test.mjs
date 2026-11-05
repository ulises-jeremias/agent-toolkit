import test from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { probeBinary } from './provider-binary-preflight.mjs';

// Exercise the actual OS process boundary while keeping provider credentials and
// subscriptions out of CI. This is NOT a real provider session or Gate 0 evidence.
function nodeFixture(script) {
  return (_command, _args, options) => {
    assert.equal(options.shell, false);
    assert.equal(options.stdio[0], 'ignore');
    return spawn(process.execPath, ['--input-type=module', '-e', script], options);
  };
}

test('OS subprocess: successful version probe does not imply authentication', async () => {
  const result = await probeBinary('claude', {
    spawnFn: nodeFixture("process.stdout.write('fixture 1.0\\n')"),
  });
  assert.equal(result.status, 'binary_present');
  assert.equal(result.versionOutput, 'fixture 1.0');
  assert.equal(result.authenticated, 'unverified');
  assert.equal(result.session, 'unverified');
});

test('OS subprocess: nonzero exit captures bounded diagnostics', async () => {
  const result = await probeBinary('codex', {
    spawnFn: nodeFixture("process.stderr.write('fixture error\\n'); process.exitCode = 17"),
  });
  assert.equal(result.status, 'version_failed');
  assert.equal(result.exitCode, 17);
  assert.equal(result.diagnostic, 'fixture error');
});

test('OS subprocess: missing executable is unavailable', async () => {
  const result = await probeBinary('opencode', {
    spawnFn: (_command, _args, options) =>
      spawn('atk-intentionally-nonexistent-provider-binary-1669', ['--version'], options),
  });
  assert.equal(result.status, 'unavailable');
  assert.equal(result.reason, 'ENOENT');
});

test('OS subprocess: timed-out child never counts as a provider session', async () => {
  const result = await probeBinary('claude', {
    timeoutMs: 100,
    spawnFn: nodeFixture('setInterval(() => {}, 1000)'),
  });
  assert.equal(result.status, 'timeout');
  assert.equal(result.session, 'unverified');
});
