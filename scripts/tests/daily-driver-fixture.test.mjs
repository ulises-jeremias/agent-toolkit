import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';

test('field fixture is an isolated committed repo with a failing test', () => {
  const created = spawnSync(process.execPath, ['scripts/daily-driver-fixture.mjs'], { encoding: 'utf8' });
  assert.equal(created.status, 0, created.stderr);
  const result = JSON.parse(created.stdout);
  assert.equal(result.baseline, 'failing-test-confirmed');
  assert.equal(result.evidence_level, 'U');
  try {
    const baseline = spawnSync('git', ['status', '--porcelain'], { cwd: result.path, encoding: 'utf8' });
    assert.equal(baseline.status, 0);
    assert.equal(baseline.stdout.trim(), '');
    assert.match(readFileSync(join(result.path, 'src/sum.mjs'), 'utf8'), /a - b/);
    const failed = spawnSync(process.execPath, ['--test'], { cwd: result.path, encoding: 'utf8' });
    assert.equal(failed.status, 1);
  } finally {
    rmSync(result.path, { recursive: true, force: true });
  }
});
