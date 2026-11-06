#!/usr/bin/env node
// Gate 0: disposable, deliberately failing repository for a real packaged Desktop trial.
// This script never invokes a coding provider and is not acceptance evidence.
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = mkdtempSync(join(tmpdir(), 'atk-daily-driver-'));
// Git location/config overrides must never redirect fixture writes into a user repository.
const gitEnv = { ...process.env };
for (const key of Object.keys(gitEnv)) {
  if (key.startsWith('GIT_')) delete gitEnv[key];
}
gitEnv.GIT_CONFIG_NOSYSTEM = '1';
gitEnv.GIT_CONFIG_GLOBAL = process.platform === 'win32' ? 'NUL' : '/dev/null';

function git(...args) {
  const result = spawnSync('git', args, { cwd: root, env: gitEnv, encoding: 'utf8' });
  if (result.error || result.status !== 0) {
    throw new Error(`git ${args[0]} failed: ${result.error?.message ?? result.stderr}`);
  }
}

try {
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
  git('init', '-q');
  git('config', '--local', 'user.name', 'Agent Toolkit Fixture');
  git('config', '--local', 'user.email', 'fixture@invalid.example');
  git('add', 'src/sum.mjs', 'test/sum.test.mjs');
  git('-c', 'commit.gpgsign=false', 'commit', '-qm', 'test: establish failing fixture');

  // Node's test runner exports NODE_TEST_CONTEXT to descendants; remove it so this\n  // independent fixture test is not mistaken for a recursive nested test.\n  const testEnv = { ...process.env };\n  delete testEnv.NODE_TEST_CONTEXT;\n  const result = spawnSync(process.execPath, ['--test', 'test/sum.test.mjs'], { cwd: root, env: testEnv, encoding: 'utf8' });
  if (result.error || result.status !== 1) {
    throw new Error(`Expected deliberately failing test (exit 1); got ${result.status}: ${result.stderr}`);
  }
  console.log(JSON.stringify({
    path: root,
    baseline: 'failing-test-confirmed',
    evidence_level: 'U',
    instructions: 'Open this existing repo in the installed Desktop. Run D01-D07 with real authenticated providers; capture redacted evidence. Do not treat this fixture as Gate 0 acceptance.',
  }, null, 2));
} catch (error) {
  rmSync(root, { recursive: true, force: true });
  console.error(`Fixture setup failed (temporary directory cleaned): ${error.message}`);
  process.exitCode = 1;
}
