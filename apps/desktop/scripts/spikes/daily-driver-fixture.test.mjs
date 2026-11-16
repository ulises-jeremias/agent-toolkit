import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, rmSync, mkdtempSync, mkdirSync, chmodSync, existsSync } from 'node:fs';
import { execFileSync, spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { pathToFileURL } from 'node:url';
import { createFixture } from './daily-driver-fixture.mjs';

// Node's test runner propagates NODE_TEST_CONTEXT to children. Nested `node --test`
// otherwise skips the fixture tests and exits 0, hiding the intended failure.
// Force TAP: Node 22+ defaults to the spec reporter in CI terminals, where
// failures are rendered as ✖ instead of TAP's `not ok`.
const fixtureTestEnv = { ...process.env };
delete fixtureTestEnv.NODE_TEST_CONTEXT;

test('field-trial fixture starts failing, is committed and becomes green only after source fix', (t) => {
  const directory = createFixture();
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const original = spawnSync(process.execPath, ['--test', '--test-reporter=tap', 'test/sum.test.mjs'], { cwd: directory, encoding: 'utf8', env: fixtureTestEnv });
  assert.notEqual(original.status, 0, 'baseline must fail, not accidentally pass');
  assert.match(original.stdout + original.stderr, /not ok/);
  assert.match(original.stdout + original.stderr, /Expected values to be strictly equal/);
  assert.doesNotMatch(original.stdout + original.stderr, /TypeError/);
  assert.equal(execFileSync('git', ['-C', directory, 'status', '--porcelain'], { encoding: 'utf8' }).trim(), '');
  const source = join(directory, 'src', 'sum.mjs');
  assert.match(readFileSync(source, 'utf8'), /a - b/);
  writeFileSync(source, 'export const sum = (a, b) => a + b;\n');
  const fixed = spawnSync(process.execPath, ['--test', '--test-reporter=tap', 'test/sum.test.mjs'], { cwd: directory, encoding: 'utf8', env: fixtureTestEnv });
  assert.equal(fixed.status, 0, fixed.stdout + fixed.stderr);
  assert.match(execFileSync('git', ['-C', directory, 'diff', '--', 'src/sum.mjs'], { encoding: 'utf8' }), /a \+ b/);
  assert.equal(execFileSync('git', ['-C', directory, 'diff', '--', 'test/sum.test.mjs'], { encoding: 'utf8' }), '');
});


test('fixture ignores inherited Git overrides and commit signing', (t) => {
  const fixtureModule = pathToFileURL(join(import.meta.dirname, 'daily-driver-fixture.mjs')).href;
  const env = { ...process.env, GIT_DIR: '/nonexistent/atk-foreign-git-dir', GIT_WORK_TREE: '/nonexistent/atk-foreign-worktree', GIT_INDEX_FILE: '/nonexistent/atk-foreign-index' };
  const child = spawnSync(process.execPath, ['--input-type=module', '-e',
    `import { createFixture } from ${JSON.stringify(fixtureModule)}; console.log(createFixture());`],
    { encoding: 'utf8', env });
  assert.equal(child.status, 0, child.stderr);
  const directory = child.stdout.trim();
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const cleanEnv = { ...process.env };
  for (const name of Object.keys(cleanEnv)) if (name.startsWith('GIT_')) delete cleanEnv[name];
  assert.equal(execFileSync('git', ['-C', directory, 'status', '--porcelain'], { encoding: 'utf8', env: cleanEnv }).trim(), '');
  assert.equal(execFileSync('git', ['-C', directory, 'log', '-1', '--format=%s'], { encoding: 'utf8', env: cleanEnv }).trim(), 'test: establish failing fixture');
});

// A global hooksPath can execute arbitrary host hooks on every fixture commit.
// The field-trial fixture must remain hermetic even when the tester has one.
test('fixture does not execute inherited global Git hooks', { skip: process.platform === 'win32' }, (t) => {
  const home = mkdtempSync(join(tmpdir(), 'atk-git-home-'));
  t.after(() => rmSync(home, { recursive: true, force: true }));
  const hooks = join(home, 'hooks');
  mkdirSync(hooks);
  const sentinel = join(home, 'hook-executed');
  const hook = join(hooks, 'pre-commit');
  writeFileSync(hook, '#!/bin/sh\\ntouch ' + JSON.stringify(sentinel) + '\\nexit 17\\n');
  chmodSync(hook, 0o755);
  writeFileSync(join(home, '.gitconfig'), '[core]\\n\\thooksPath = ' + hooks + '\\n');
  const fixtureModule = pathToFileURL(join(import.meta.dirname, 'daily-driver-fixture.mjs')).href;
  const env = { ...process.env, HOME: home, XDG_CONFIG_HOME: home };
  delete env.GIT_CONFIG_GLOBAL;
  const child = spawnSync(process.execPath, ['--input-type=module', '-e',
    `import { createFixture } from ${JSON.stringify(fixtureModule)}; console.log(createFixture());`],
    { encoding: 'utf8', env });
  assert.equal(child.status, 0, child.stderr);
  const directory = child.stdout.trim();
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  assert.equal(existsSync(sentinel), false, 'global pre-commit hook must not execute');
});
