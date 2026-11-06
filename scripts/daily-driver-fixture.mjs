#!/usr/bin/env node
// Gate 0: disposable, deliberately failing repository for a real packaged Desktop trial.
// This script never invokes a coding provider and is not acceptance evidence.
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = mkdtempSync(join(tmpdir(), 'atk-daily-driver-'));
mkdirSync(join(root, 'src'));
mkdirSync(join(root, 'test'));
writeFileSync(join(root, 'src/sum.mjs'), 'export const sum = (a, b) => a - b;\n');
writeFileSync(join(root, 'test/sum.test.mjs'), [
  "import test from 'node:test';",
  "import assert from 'node:assert/strict';",
  "import { sum } from '../src/sum.mjs';",
  "test('sum', () => assert.equal(sum(2, 3), 5));",
  '',
].join('\n'));

function git(...args) {
  const result = spawnSync('git', args, { cwd: root, encoding: 'utf8' });
  if (result.error || result.status !== 0) {
    throw new Error(`git ${args[0]} failed: ${result.error?.message ?? result.stderr}`);
  }
}
git('init', '-q');
git('config', '--local', 'user.name', 'Agent Toolkit Fixture');
git('config', '--local', 'user.email', 'fixture@invalid.example');
git('add', 'src/sum.mjs', 'test/sum.test.mjs');
git('commit', '-qm', 'test: establish failing fixture');

const result = spawnSync(process.execPath, ['--test'], { cwd: root, encoding: 'utf8' });
if (result.error || result.status !== 1) {
  throw new Error(`Expected deliberately failing test (exit 1); got ${result.status}: ${result.stderr}`);
}
console.log(JSON.stringify({
  path: root,
  baseline: 'failing-test-confirmed',
  evidence_level: 'U',
  instructions: 'Open this existing repo in the installed Desktop. Run D01-D07 with real authenticated providers; capture redacted evidence. Do not treat this fixture as Gate 0 acceptance.',
}, null, 2));
