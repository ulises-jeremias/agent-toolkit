import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync, spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { createFixture } from './daily-driver-fixture.mjs';

test('field-trial fixture starts failing, is committed and becomes green only after source fix', () => {
  const directory = createFixture();
  const original = spawnSync(process.execPath, ['--test'], { cwd: directory, encoding: 'utf8' });
  assert.notEqual(original.status, 0, 'baseline must fail, not accidentally pass');
  assert.match(original.stdout + original.stderr, /not ok/);
  assert.equal(execFileSync('git', ['-C', directory, 'status', '--porcelain'], { encoding: 'utf8' }).trim(), '');
  const source = join(directory, 'src', 'sum.mjs');
  assert.match(readFileSync(source, 'utf8'), /a - b/);
  writeFileSync(source, 'export const sum = (a, b) => a + b;\n');
  const fixed = spawnSync(process.execPath, ['--test'], { cwd: directory, encoding: 'utf8' });
  assert.equal(fixed.status, 0, fixed.stdout + fixed.stderr);
  assert.match(execFileSync('git', ['-C', directory, 'diff', '--', 'src/sum.mjs'], { encoding: 'utf8' }), /a \+ b/);
  assert.equal(execFileSync('git', ['-C', directory, 'diff', '--', 'test/sum.test.mjs'], { encoding: 'utf8' }), '');
});
