// @vitest-environment node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import type { BackendState } from './backend';
import { HarnessController, type HarnessSupervisor } from './harness-controller';
import type { HarnessResolution } from './harness';
import { HarnessStore } from './harness-store';

/** Records the restart sequence and reports the harness the controller would spawn in. */
class FakeSupervisor implements HarnessSupervisor {
  calls: string[] = [];
  state: BackendState = {
    status: 'ready',
    url: 'http://127.0.0.1:1',
    version: '1.0.0',
    detail: null,
    restarts: 0,
    harness: null,
    binary: null,
    rejected: [],
    problem: null,
  };
  gate: Promise<void> = Promise.resolve();

  constructor(private readonly resolve: () => HarnessResolution) {}

  async restart(): Promise<boolean> {
    this.calls.push('stop');
    await this.gate;
    const harness = this.resolve();
    this.calls.push(`start:${harness.path}`);
    this.state = { ...this.state, status: 'ready', harness, restarts: this.state.restarts + 1 };
    return true;
  }

  snapshot(): BackendState {
    return { ...this.state };
  }
}

describe('HarnessController', () => {
  let root = '';
  let home = '';
  let env: NodeJS.ProcessEnv = {};
  let store: HarnessStore;
  let supervisor: FakeSupervisor;
  let controller: HarnessController;
  let picked: string | null = null;

  beforeEach(() => {
    root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'atk-ctl-')));
    home = path.join(root, 'home');
    fs.mkdirSync(path.join(home, '.ai-workspace'), { recursive: true });
    env = {};
    picked = null;
    store = new HarnessStore(path.join(root, 'userData', 'harness.json'));
    controller = new HarnessController({
      store,
      getSupervisor: () => supervisor,
      env: () => env,
      homeDir: home,
      cwd: () => root,
      chooseDirectory: async () => picked,
    });
    supervisor = new FakeSupervisor(() => controller.resolve());
    supervisor.state.harness = controller.resolve();
  });

  afterEach(() => {
    fs.rmSync(root, { recursive: true, force: true });
  });

  it('resolves the default until a choice is made', () => {
    expect(controller.resolve()).toMatchObject({ source: 'default', path: path.join(home, '.ai-workspace') });
  });

  it('persists, then restarts the backend into the chosen harness', async () => {
    const target = path.join(root, 'other');
    fs.mkdirSync(target);
    const result = await controller.set(target);
    expect(result).toMatchObject({ ok: true, restarted: true, harness: { path: target, source: 'user' } });
    expect(supervisor.calls).toEqual(['stop', `start:${target}`]);
    expect(new HarnessStore(store.path).current()).toBe(target);
    expect(controller.recent()).toEqual([{ path: target, exists: true, current: true }]);
  });

  it('accepts ~ paths and does not restart when the harness is unchanged', async () => {
    const result = await controller.set('~/.ai-workspace');
    expect(result).toMatchObject({ ok: true, restarted: false, harness: { source: 'user' } });
    expect(supervisor.calls).toEqual([]);
    expect(store.current()).toBe(path.join(home, '.ai-workspace'));
  });

  it.each([
    ['', 'invalid-path'],
    ['relative/dir', 'invalid-path'],
    ['/definitely/missing/atk', 'not-found'],
  ])('rejects %j with %s and never restarts or persists', async (input, error) => {
    expect(await controller.set(input)).toMatchObject({ ok: false, error });
    expect(supervisor.calls).toEqual([]);
    expect(fs.existsSync(store.path)).toBe(false);
  });

  it('rejects a file and does not create directories', async () => {
    const file = path.join(root, 'file.txt');
    fs.writeFileSync(file, 'x');
    expect(await controller.set(file)).toMatchObject({ ok: false, error: 'not-a-directory' });
    expect(await controller.set(path.join(root, 'new-dir'))).toMatchObject({ ok: false, error: 'not-found' });
    expect(fs.existsSync(path.join(root, 'new-dir'))).toBe(false);
  });

  it('refuses to switch while an env override pins the harness', async () => {
    env = { AGENT_TOOLKIT_WORKSPACE: path.join(home, '.ai-workspace') };
    const result = await controller.set(root);
    expect(result).toMatchObject({ ok: false, error: 'env-override' });
    expect(controller.status().lockedBy).toBe('AGENT_TOOLKIT_WORKSPACE');
    expect(await controller.reset()).toMatchObject({ ok: false, error: 'env-override' });
    expect(supervisor.calls).toEqual([]);
  });

  it('env override wins over a persisted choice', () => {
    store.setCurrent(root);
    const override = path.join(root, 'env');
    fs.mkdirSync(override);
    env = { HARNESS_DIR: override };
    expect(controller.resolve()).toMatchObject({ source: 'override', path: override });
  });

  it('refuses a second switch while one is in flight', async () => {
    const a = path.join(root, 'a');
    const b = path.join(root, 'b');
    fs.mkdirSync(a);
    fs.mkdirSync(b);
    let release: () => void = () => undefined;
    supervisor.gate = new Promise((resolve) => {
      release = resolve;
    });
    const first = controller.set(a);
    expect(controller.status().switching).toBe(true);
    expect(await controller.set(b)).toMatchObject({ ok: false, error: 'busy' });
    release();
    expect(await first).toMatchObject({ ok: true });
    expect(controller.status().switching).toBe(false);
    expect(store.current()).toBe(a);
  });

  it('choose: cancel is a no-op; a pick goes through the same validation', async () => {
    expect(await controller.choose()).toMatchObject({ ok: false, error: 'cancelled' });
    picked = path.join(root, 'missing');
    expect(await controller.choose()).toMatchObject({ ok: false, error: 'not-found' });
    picked = root;
    expect(await controller.choose()).toMatchObject({ ok: true, harness: { path: root } });
  });

  it('reset forgets the choice and restarts into the default', async () => {
    await controller.set(root);
    supervisor.calls = [];
    const result = await controller.reset();
    expect(result).toMatchObject({ ok: true, restarted: true, harness: { source: 'default' } });
    expect(supervisor.calls).toEqual(['stop', `start:${path.join(home, '.ai-workspace')}`]);
    expect(store.current()).toBeNull();
  });

  it('falls back to the default with a notice when the saved choice vanished', async () => {
    const gone = path.join(root, 'gone');
    fs.mkdirSync(gone);
    await controller.set(gone);
    fs.rmSync(gone, { recursive: true });
    expect(controller.resolve()).toMatchObject({ source: 'default' });
    expect(controller.resolve().notice).toContain(`Saved harness ${gone} is not a directory`);
    expect(controller.recent()).toEqual([{ path: gone, exists: false, current: true }]);
  });
});
