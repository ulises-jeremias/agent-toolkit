// @vitest-environment node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  activeOverrideVar,
  createDefaultHarnessDirectory,
  harnessSpawnContext,
  isDirectory,
  resolveHarness,
  validateHarnessPath,
  type HarnessInputs,
} from './harness';

describe('resolveHarness', () => {
  let home = '';
  let cwd = '';

  beforeEach(() => {
    home = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-home-'));
    cwd = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-cwd-'));
  });

  afterEach(() => {
    fs.rmSync(home, { recursive: true, force: true });
    fs.rmSync(cwd, { recursive: true, force: true });
  });

  const inputs = (env: NodeJS.ProcessEnv = {}): HarnessInputs => ({ env, homeDir: home, cwd, isDirectory });

  it('uses ~/.ai-workspace when it exists and no override is set', () => {
    const ws = path.join(home, '.ai-workspace');
    fs.mkdirSync(ws);
    expect(resolveHarness(inputs())).toEqual({
      path: ws,
      source: 'default',
      defaultPath: ws,
      overrideVar: null,
      notice: null,
    });
  });

  it('falls back to cwd with a notice when ~/.ai-workspace is missing, without creating it', () => {
    const result = resolveHarness(inputs());
    expect(result.source).toBe('fallback');
    expect(result.path).toBe(cwd);
    expect(result.notice).toContain(`Default harness ${path.join(home, '.ai-workspace')} not found`);
    expect(fs.existsSync(path.join(home, '.ai-workspace'))).toBe(false);
  });

  it('treats a regular file at ~/.ai-workspace as missing', () => {
    fs.writeFileSync(path.join(home, '.ai-workspace'), 'not a dir');
    expect(resolveHarness(inputs()).source).toBe('fallback');
  });

  it('prefers AGENT_TOOLKIT_WORKSPACE over the default', () => {
    fs.mkdirSync(path.join(home, '.ai-workspace'));
    const other = path.join(home, 'other');
    fs.mkdirSync(other);
    const result = resolveHarness(inputs({ AGENT_TOOLKIT_WORKSPACE: other }));
    expect(result).toMatchObject({ path: other, source: 'override', overrideVar: 'AGENT_TOOLKIT_WORKSPACE' });
  });

  it('expands ~ and resolves relative overrides against cwd', () => {
    fs.mkdirSync(path.join(home, 'ws'));
    expect(resolveHarness(inputs({ AGENT_TOOLKIT_WORKSPACE: '~/ws' })).path).toBe(path.join(home, 'ws'));
    fs.mkdirSync(path.join(cwd, 'rel'));
    expect(resolveHarness(inputs({ HARNESS_DIR: 'rel' })).path).toBe(path.join(cwd, 'rel'));
  });

  it('skips an invalid AGENT_TOOLKIT_WORKSPACE for a valid HARNESS_DIR, like core', () => {
    const harnessDir = path.join(home, 'harness');
    fs.mkdirSync(harnessDir);
    const result = resolveHarness(
      inputs({ AGENT_TOOLKIT_WORKSPACE: path.join(home, 'missing'), HARNESS_DIR: harnessDir }),
    );
    expect(result).toMatchObject({ path: harnessDir, source: 'override', overrideVar: 'HARNESS_DIR' });
    expect(result.notice).toContain('AGENT_TOOLKIT_WORKSPACE');
  });

  it('falls back (not to the default) when an explicit override is not a directory', () => {
    fs.mkdirSync(path.join(home, '.ai-workspace'));
    const missing = path.join(home, 'missing');
    const result = resolveHarness(inputs({ AGENT_TOOLKIT_WORKSPACE: missing }));
    expect(result).toMatchObject({ path: cwd, source: 'fallback', overrideVar: 'AGENT_TOOLKIT_WORKSPACE' });
    expect(result.notice).toContain(`AGENT_TOOLKIT_WORKSPACE=${missing} (not a directory)`);
  });

  it('ignores blank override values', () => {
    fs.mkdirSync(path.join(home, '.ai-workspace'));
    expect(resolveHarness(inputs({ AGENT_TOOLKIT_WORKSPACE: '  ' })).source).toBe('default');
  });

  describe('persisted user choice', () => {
    const withChoice = (userChoice: string | null, env: NodeJS.ProcessEnv = {}): HarnessInputs => ({
      ...inputs(env),
      userChoice,
    });

    it('beats the default', () => {
      fs.mkdirSync(path.join(home, '.ai-workspace'));
      const chosen = path.join(home, 'chosen');
      fs.mkdirSync(chosen);
      expect(resolveHarness(withChoice(chosen))).toEqual({
        path: chosen,
        source: 'user',
        defaultPath: path.join(home, '.ai-workspace'),
        overrideVar: null,
        notice: null,
      });
    });

    it('loses to an env override', () => {
      const chosen = path.join(home, 'chosen');
      const env = path.join(home, 'env');
      fs.mkdirSync(chosen);
      fs.mkdirSync(env);
      expect(resolveHarness(withChoice(chosen, { AGENT_TOOLKIT_WORKSPACE: env }))).toMatchObject({
        path: env,
        source: 'override',
      });
    });

    it('falls to the default with a notice when the choice is gone, without creating it', () => {
      fs.mkdirSync(path.join(home, '.ai-workspace'));
      const gone = path.join(home, 'gone');
      const result = resolveHarness(withChoice(gone));
      expect(result).toMatchObject({ source: 'default', path: path.join(home, '.ai-workspace') });
      expect(result.notice).toBe(`Saved harness ${gone} is not a directory; using the default ${path.join(home, '.ai-workspace')}`);
      expect(fs.existsSync(gone)).toBe(false);
    });

    it('falls back to cwd when both the choice and the default are gone', () => {
      const result = resolveHarness(withChoice(path.join(home, 'gone')));
      expect(result).toMatchObject({ source: 'fallback', path: cwd });
      expect(result.notice).toContain('Saved harness');
      expect(result.notice).toContain('Default harness');
    });
  });
});

describe('validateHarnessPath', () => {
  let home = '';
  beforeEach(() => {
    home = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'atk-validate-')));
  });
  afterEach(() => {
    fs.rmSync(home, { recursive: true, force: true });
  });

  it('accepts an existing directory, normalizing and expanding ~', () => {
    fs.mkdirSync(path.join(home, 'ws'));
    expect(validateHarnessPath(`${home}/ws/../ws/`, home)).toEqual({ ok: true, path: path.join(home, 'ws') });
    expect(validateHarnessPath('~/ws', home)).toEqual({ ok: true, path: path.join(home, 'ws') });
  });

  it.each([
    [42, 'invalid-path'],
    ['   ', 'invalid-path'],
    ['relative', 'invalid-path'],
    ['/tmp/a\0b', 'invalid-path'],
    ['/x'.repeat(3000), 'invalid-path'],
  ])('rejects %j as %s', (input, error) => {
    expect(validateHarnessPath(input, home)).toMatchObject({ ok: false, error });
  });

  it('distinguishes missing paths from files', () => {
    fs.writeFileSync(path.join(home, 'file'), 'x');
    expect(validateHarnessPath(path.join(home, 'nope'), home)).toMatchObject({ ok: false, error: 'not-found' });
    expect(validateHarnessPath(path.join(home, 'file'), home)).toMatchObject({ ok: false, error: 'not-a-directory' });
  });

  it.skipIf(process.platform === 'win32' || process.getuid?.() === 0)('rejects a directory serve cannot write', () => {
    const readOnly = path.join(home, 'ro');
    fs.mkdirSync(readOnly, { mode: 0o555 });
    try {
      expect(validateHarnessPath(readOnly, home)).toMatchObject({ ok: false, error: 'not-accessible' });
    } finally {
      fs.chmodSync(readOnly, 0o755);
    }
  });
});

describe('activeOverrideVar', () => {
  it('reports the first non-blank override var', () => {
    expect(activeOverrideVar({})).toBeNull();
    expect(activeOverrideVar({ AGENT_TOOLKIT_WORKSPACE: ' ' })).toBeNull();
    expect(activeOverrideVar({ HARNESS_DIR: '/h' })).toBe('HARNESS_DIR');
    expect(activeOverrideVar({ AGENT_TOOLKIT_WORKSPACE: '/a', HARNESS_DIR: '/h' })).toBe('AGENT_TOOLKIT_WORKSPACE');
  });
});

describe('harnessSpawnContext', () => {
  const base = { PATH: '/bin', AGENT_TOOLKIT_WORKSPACE: '/stale' };

  it('roots serve at the harness and exports it for core find_workspace_root', () => {
    const ctx = harnessSpawnContext(
      { path: '/h', source: 'default', defaultPath: '/h', overrideVar: null, notice: null },
      base,
    );
    expect(ctx).toEqual({ cwd: '/h', env: { PATH: '/bin', AGENT_TOOLKIT_WORKSPACE: '/h' } });
  });

  it('roots serve at a user-chosen harness the same way', () => {
    const ctx = harnessSpawnContext(
      { path: '/u', source: 'user', defaultPath: '/d', overrideVar: null, notice: null },
      base,
    );
    expect(ctx).toEqual({ cwd: '/u', env: { PATH: '/bin', AGENT_TOOLKIT_WORKSPACE: '/u' } });
  });

  it('leaves cwd and env untouched on fallback', () => {
    const ctx = harnessSpawnContext(
      { path: '/c', source: 'fallback', defaultPath: '/d', overrideVar: null, notice: 'x' },
      base,
    );
    expect(ctx).toEqual({ cwd: undefined, env: base });
  });
});

describe('createDefaultHarnessDirectory', () => {
  let home = '';

  beforeEach(() => {
    home = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-home-'));
  });

  afterEach(() => {
    fs.rmSync(home, { recursive: true, force: true });
  });

  it('creates ~/.ai-workspace when missing and does not when it already exists', () => {
    const created: string[] = [];
    const first = createDefaultHarnessDirectory({
      homeDir: home,
      isDirectory,
      mkdir: (candidate) => {
        created.push(candidate);
        fs.mkdirSync(candidate, { recursive: true });
      },
    });
    expect(first).toEqual({ ok: true, path: path.join(home, '.ai-workspace'), created: true, error: null });
    expect(created).toEqual([path.join(home, '.ai-workspace')]);

    const second = createDefaultHarnessDirectory({
      homeDir: home,
      isDirectory,
      mkdir: () => {
        throw new Error('must not create again');
      },
    });
    expect(second.created).toBe(false);
    expect(second.ok).toBe(true);
  });

  it('reports a failure when the path exists as a file', () => {
    fs.writeFileSync(path.join(home, '.ai-workspace'), 'not a dir');
    const result = createDefaultHarnessDirectory({
      homeDir: home,
      isDirectory,
      mkdir: (candidate) => fs.mkdirSync(candidate),
    });
    expect(result.ok).toBe(false);
    expect(result.created).toBe(false);
    expect(result.error).toBeTruthy();
  });
});
