#!/usr/bin/env node
/**
 * Creates an isolated, intentionally failing Git project for the packaged
 * Desktop D01-D07 field trial. Never touches the user's existing projects.
 * This is a fixture, NOT evidence of a live provider or Desktop acceptance.
 */
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';

export function createFixture({ root = tmpdir() } = {}) {
  const directory = mkdtempSync(join(root, 'atk-daily-driver-'));
  mkdirSync(join(directory, 'src'));
  mkdirSync(join(directory, 'test'));
  writeFileSync(join(directory, 'src', 'sum.mjs'), 'export const sum = (a, b) => a - b;\\n'.replace('\\n', '\n'));
  writeFileSync(join(directory, 'test', 'sum.test.mjs'),
    "import test from 'node:test';\nimport assert from 'node:assert/strict';\nimport { sum } from '../src/sum.mjs';\ntest('sum', () => assert.equal(sum(2, 3), 5));\n");
  execFileSync('git', ['init', '-q', directory]);
  execFileSync('git', ['-C', directory, 'add', '--', 'src/sum.mjs', 'test/sum.test.mjs']);
  execFileSync('git', ['-C', directory, '-c', 'user.name=Toolkit Fixture', '-c', 'user.email=fixture@invalid.example', 'commit', '-qm', 'test: establish failing fixture']);
  return directory;
}

if (process.argv[1] && import.meta.url === new URL('file://' + process.argv[1]).href) {
  const directory = createFixture();
  console.log(JSON.stringify({
    directory,
    expected_baseline: 'node --test fails (sum subtracts)',
    task: 'Fix the failing sum test without modifying the test, explain the change and execute node --test. Show me what changed.',
    evidence_level: 'U',
    reminder: 'Run D01-D07 in an installed Desktop with an authenticated local provider; never include tokens in evidence.'
  }, null, 2));
}
