// @vitest-environment node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { harnessSpawnContext, isDirectory, resolveHarness, type HarnessInputs } from './harness';

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

  it('leaves cwd and env untouched on fallback', () => {
    const ctx = harnessSpawnContext(
      { path: '/c', source: 'fallback', defaultPath: '/d', overrideVar: null, notice: 'x' },
      base,
    );
    expect(ctx).toEqual({ cwd: undefined, env: base });
  });
});
