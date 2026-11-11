import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, symlinkSync, rmSync, existsSync, mkdirSync, writeFileSync, chmodSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(new URL('../daily-driver-baseline.mjs', import.meta.url));

function run(output, app, envOverrides = {}) {
  return spawnSync(process.execPath, [script, '--output-dir', output, ...(app ? ['--app', app] : [])], {
    env: { ...Object.fromEntries(Object.entries(process.env).filter(([key]) => key !== 'NODE_TEST_CONTEXT')), ...envOverrides },
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


test('Gate 0 preflight recognizes complete macOS .app bundles without claiming launch', () => {
  const dir = mkdtempSync(join(tmpdir(), 'atk-gate0-macos-'));
  try {
    const bundle = join(dir, 'Toolkit.app');
    const macos = join(bundle, 'Contents', 'MacOS');
    mkdirSync(macos, { recursive: true });
    writeFileSync(join(bundle, 'Contents', 'Info.plist'), '<plist/>');
    writeFileSync(join(macos, 'Toolkit'), 'placeholder');
    chmodSync(join(macos, 'Toolkit'), 0o755);
    const result = run(join(dir, 'complete'), bundle);
    assert.equal(result.status, 0, result.stderr);
    const data = JSON.parse(readFileSync(join(dir, 'complete', 'baseline.json'), 'utf8'));
    assert.deepEqual(data.installed_app, { supplied: true, executable_exists: true });
    assert.ok(data.journeys.every(j => j.outcome === 'unverified' && j.evidence_level === 'U'));
    rmSync(join(macos, 'Toolkit'));
    const incomplete = run(join(dir, 'incomplete'), bundle);
    assert.equal(incomplete.status, 0, incomplete.stderr);
    assert.equal(JSON.parse(readFileSync(join(dir, 'incomplete', 'baseline.json'), 'utf8')).installed_app.executable_exists, false);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('Gate 0 preflight rejects symlinked macOS app and bundle components', () => {
  const dir = mkdtempSync(join(tmpdir(), 'atk-gate0-app-link-'));
  try {
    const bundle = join(dir, 'Real.app');
    const macos = join(bundle, 'Contents', 'MacOS');
    mkdirSync(macos, { recursive: true });
    writeFileSync(join(bundle, 'Contents', 'Info.plist'), '<plist/>');
    writeFileSync(join(macos, 'Toolkit'), 'placeholder');
    const alias = join(dir, 'Alias.app');
    symlinkSync(bundle, alias, 'dir');
    let result = run(join(dir, 'alias'), alias);
    assert.equal(result.status, 0, result.stderr);
    let data = JSON.parse(readFileSync(join(dir, 'alias', 'baseline.json'), 'utf8'));
    assert.equal(data.installed_app.executable_exists, false);
    rmSync(join(macos, 'Toolkit'));
    writeFileSync(join(dir, 'external'), 'placeholder');
    symlinkSync(join(dir, 'external'), join(macos, 'Toolkit'));
    result = run(join(dir, 'inner-link'), bundle);
    assert.equal(result.status, 0, result.stderr);
    data = JSON.parse(readFileSync(join(dir, 'inner-link', 'baseline.json'), 'utf8'));
    assert.equal(data.installed_app.executable_exists, false);
    assert.ok(data.journeys.every(j => j.outcome === 'unverified' && j.evidence_level === 'U'));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('Gate 0 preflight rejects app paths through symlinked parent directories', () => {
  const dir = mkdtempSync(join(tmpdir(), 'atk-gate0-app-parent-link-'));
  try {
    const real = join(dir, 'real');
    mkdirSync(real);
    const bundle = join(real, 'Toolkit.app');
    const macos = join(bundle, 'Contents', 'MacOS');
    mkdirSync(macos, { recursive: true });
    writeFileSync(join(bundle, 'Contents', 'Info.plist'), '<plist/>');
    writeFileSync(join(macos, 'Toolkit'), 'placeholder');
    symlinkSync(real, join(dir, 'alias'), 'dir');

    const result = run(join(dir, 'evidence'), join(dir, 'alias', 'Toolkit.app'));
    assert.equal(result.status, 0, result.stderr);
    const data = JSON.parse(readFileSync(join(dir, 'evidence', 'baseline.json'), 'utf8'));
    assert.deepEqual(data.installed_app, { supplied: true, executable_exists: false });
    assert.ok(data.journeys.every(j => j.outcome === 'unverified' && j.evidence_level === 'U'));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('Gate 0 preflight ignores hostile inherited Git directory and worktree', () => {
  const dir = mkdtempSync(join(tmpdir(), 'atk-gate0-git-env-'));
  try {
    const external = join(dir, 'external');
    mkdirSync(external);
    const init = spawnSync('git', ['init', '-q', external], { encoding: 'utf8' });
    assert.equal(init.status, 0, init.stderr);
    const gitDir = join(external, '.git');
    const result = run(join(dir, 'evidence'), undefined, {
      GIT_DIR: gitDir,
      GIT_WORK_TREE: external,
      GIT_INDEX_FILE: join(external, 'injected-index'),
      GIT_CONFIG_COUNT: '1',
      GIT_CONFIG_KEY_0: 'core.hooksPath',
      GIT_CONFIG_VALUE_0: external,
    });
    assert.equal(result.status, 0, result.stderr);
    assert.equal(existsSync(join(external, 'injected-index')), false);
    const fixture = join(dir, 'evidence', 'fixture');
    const fixtureHead = spawnSync('git', ['-C', fixture, 'rev-parse', '--verify', 'HEAD'], {
      encoding: 'utf8',
      env: Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('GIT_'))),
    });
    assert.equal(fixtureHead.status, 0, fixtureHead.stderr);
    const externalHead = spawnSync('git', ['-C', external, 'rev-parse', '--verify', 'HEAD'], {
      encoding: 'utf8',
      env: Object.fromEntries(Object.entries(process.env).filter(([key]) => !key.startsWith('GIT_'))),
    });
    assert.notEqual(externalHead.status, 0, 'external repository must remain without commits');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('Gate 0 preflight does not report a non-executable POSIX file as an installed app', { skip: process.platform === 'win32' }, () => {
  const dir = mkdtempSync(join(tmpdir(), 'atk-gate0-executable-'));
  try {
    const app = join(dir, 'not-an-executable');
    writeFileSync(app, 'placeholder');
    chmodSync(app, 0o644);
    const result = run(join(dir, 'non-executable'), app);
    assert.equal(result.status, 0, result.stderr);
    const data = JSON.parse(readFileSync(join(dir, 'non-executable', 'baseline.json'), 'utf8'));
    assert.deepEqual(data.installed_app, { supplied: true, executable_exists: false });
    chmodSync(app, 0o755);
    const executable = run(join(dir, 'executable'), app);
    assert.equal(executable.status, 0, executable.stderr);
    const positive = JSON.parse(readFileSync(join(dir, 'executable', 'baseline.json'), 'utf8'));
    assert.deepEqual(positive.installed_app, { supplied: true, executable_exists: true });
    assert.ok(positive.journeys.every(j => j.evidence_level === 'U' && j.outcome === 'unverified'));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('Gate 0 macOS bundle rejects non-executable payloads without claiming real acceptance', { skip: process.platform === 'win32' }, () => {
  const dir = mkdtempSync(join(tmpdir(), 'atk-gate0-macos-mode-'));
  try {
    const bundle = join(dir, 'Toolkit.app');
    const macos = join(bundle, 'Contents', 'MacOS');
    mkdirSync(macos, { recursive: true });
    writeFileSync(join(bundle, 'Contents', 'Info.plist'), '<plist/>');
    const binary = join(macos, 'Toolkit');
    writeFileSync(binary, 'placeholder');
    chmodSync(binary, 0o644);
    let result = run(join(dir, 'not-executable'), bundle);
    assert.equal(result.status, 0, result.stderr);
    let data = JSON.parse(readFileSync(join(dir, 'not-executable', 'baseline.json'), 'utf8'));
    assert.equal(data.installed_app.executable_exists, false);
    chmodSync(binary, 0o755);
    result = run(join(dir, 'executable'), bundle);
    assert.equal(result.status, 0, result.stderr);
    data = JSON.parse(readFileSync(join(dir, 'executable', 'baseline.json'), 'utf8'));
    assert.equal(data.installed_app.executable_exists, true);
    assert.ok(data.journeys.every(j => j.outcome === 'unverified' && j.evidence_level === 'U'));
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

