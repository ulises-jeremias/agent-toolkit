import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

function independentNodeEnv(env = process.env) {
  const isolated = { ...env };
  delete isolated.NODE_TEST_CONTEXT;
  return isolated;
}

function runFixture(env = process.env) {
  const created = spawnSync(process.execPath, ['scripts/daily-driver-fixture.mjs'], { encoding: 'utf8', env: independentNodeEnv(env) });
  assert.equal(created.status, 0, created.stderr);
  const result = JSON.parse(created.stdout);
  assert.equal(result.baseline, 'failing-test-confirmed');
  assert.equal(result.evidence_level, 'U');
  return result.path;
}

test('field fixture is an isolated committed repo with a failing test', () => {
  const path = runFixture();
  try {
    const baseline = spawnSync('git', ['status', '--porcelain'], { cwd: path, encoding: 'utf8' });
    assert.equal(baseline.status, 0);
    assert.equal(baseline.stdout.trim(), '');
    assert.match(readFileSync(join(path, 'src/sum.mjs'), 'utf8'), /a - b/);
    const failed = spawnSync(process.execPath, ['--test', 'test/sum.test.mjs'], { cwd: path, encoding: 'utf8', env: independentNodeEnv() });
    assert.equal(failed.status, 1);
  } finally {
    rmSync(path, { recursive: true, force: true });
  }
});

test('inherited GIT_DIR cannot redirect fixture writes into another repository', () => {
  const original = mkdtempSync(join(tmpdir(), 'atk-original-'));
  let fixture;
  try {
    const init = spawnSync('git', ['init', '-q'], { cwd: original, encoding: 'utf8' });
    assert.equal(init.status, 0, init.stderr);
    fixture = runFixture({ ...process.env, GIT_DIR: join(original, '.git'), GIT_WORK_TREE: original });
    const originalStatus = spawnSync('git', ['-C', original, 'status', '--porcelain'], { encoding: 'utf8' });
    assert.equal(originalStatus.status, 0, originalStatus.stderr);
    assert.equal(originalStatus.stdout.trim(), '');
    const originalHead = spawnSync('git', ['-C', original, 'rev-parse', '--verify', 'HEAD'], { encoding: 'utf8' });
    assert.notEqual(originalHead.status, 0, 'original repository must not gain a commit');
  } finally {
    if (fixture) rmSync(fixture, { recursive: true, force: true });
    rmSync(original, { recursive: true, force: true });
  }
});
