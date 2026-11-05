import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, symlinkSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(new URL('../daily-driver-baseline.mjs', import.meta.url));

function run(output) {
  return spawnSync(process.execPath, [script, '--output-dir', output], {
    env: Object.fromEntries(Object.entries(process.env).filter(([key]) => key !== 'NODE_TEST_CONTEXT')),
    encoding: 'utf8', timeout: 30000, maxBuffer: 65536,
  });
}

test('Gate 0 preflight creates a failing fixture without upgrading real-provider evidence', () => {
  const dir = mkdtempSync(join(tmpdir(), 'atk-gate0-'));
  try {
    const output = join(dir, 'evidence');
    const result = run(output);
    assert.equal(result.status, 0, result.stderr);
    const data = JSON.parse(readFileSync(join(output, 'baseline.json'), 'utf8'));
    assert.equal(data.schema, 'agent-toolkit/daily-driver-preflight@1');
    assert.equal(data.fixture.failing_test_confirmed, true);
    assert.equal(data.journeys.length, 10);
    assert.ok(data.journeys.every(j => j.outcome === 'unverified' && j.evidence_level === 'U'));
    assert.ok(data.providers.every(p => p.authenticated === 'not_checked'));
    assert.equal(data.installed_app.supplied, false);
    assert.match(readFileSync(join(output, 'README.md'), 'utf8'), /No real provider session/);
    const failing = spawnSync(process.execPath, ['--test', 'test/sum.test.mjs'], {
      cwd: join(output, 'fixture'),
      env: Object.fromEntries(Object.entries(process.env).filter(([key]) => key !== 'NODE_TEST_CONTEXT')),
      encoding: 'utf8', timeout: 10000,
    });
    assert.equal(failing.status, 1, 'controlled fixture must actually fail');
    const before = readFileSync(join(output, 'baseline.json'), 'utf8');
    const second = run(output);
    assert.notEqual(second.status, 0, 'must refuse overwriting evidence');
    assert.equal(readFileSync(join(output, 'baseline.json'), 'utf8'), before);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('Gate 0 preflight refuses symlinked output ancestors', () => {
  const dir = mkdtempSync(join(tmpdir(), 'atk-gate0-link-'));
  try {
    const real = join(dir, 'real');
    const link = join(dir, 'alias');
    // A dangling symlink is sufficient to prove the path guard; no data is created.
    symlinkSync(real, link, 'dir');
    const output = join(link, 'evidence');
    const result = run(output);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /symlink/i);
    assert.equal(existsSync(real), false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
