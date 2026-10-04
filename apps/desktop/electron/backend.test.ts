// @vitest-environment node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  BackendSupervisor,
  resolveExpectedBackendMajor,
  type BackendState,
  type BackendSupervisorOptions,
} from './backend';
import {
  defaultCandidateInputs,
  isExecutableFile,
  listBackendCandidates,
  resolveBackendPin,
  runBinary,
  selectBackendBinary,
} from './backend-binary';
import type { HarnessResolution } from './harness';

/** Keeps lifecycle tests independent of the developer's real ~/.ai-workspace and env. */
const fallbackHarness = (): HarnessResolution => ({
  path: process.cwd(),
  source: 'fallback',
  defaultPath: '/nonexistent/.ai-workspace',
  overrideVar: null,
  notice: 'test fallback',
});

/** Real discovery + probes, minus bundled/staged dirs a dev checkout may contain. */
function newSupervisor(options: BackendSupervisorOptions): BackendSupervisor {
  return new BackendSupervisor({
    selectBinary: (cwd) =>
      selectBackendBinary(
        listBackendCandidates({ ...defaultCandidateInputs(), resourcesPath: '', stagedDir: '/nonexistent/atk-staged' }),
        { pin: resolveBackendPin(process.env, []), run: runBinary, cwd, isExecutable: isExecutableFile },
      ),
    resolvePin: () => resolveBackendPin(process.env, []),
    ...options,
  });
}

interface FixtureOptions {
  version?: string;
  /** false = pre-serve CLI: `serve` is an unknown command. */
  serve?: boolean;
  /** false = pre-gate serve: every cross-site mutation is 403. */
  gate?: boolean;
  /** Exit right after startup instead of serving. */
  exitOnServe?: boolean;
}

/** Minimal 'agent-toolkit' stand-in: --version, serve --help, /health, gate-aware POST /jobs. */
function fixtureSource({ version = '9.9.9-test', serve = true, gate = true, exitOnServe = false }: FixtureOptions) {
  return `#!/usr/bin/env node
const http = require('node:http');
const args = process.argv.slice(2);
if (args[0] === '--version') { console.log('agent-toolkit ${version}'); process.exit(0); }
if (args[0] !== 'serve' || ${!serve}) { console.error('Unknown command: ' + args[0]); process.exit(1); }
if (args.includes('--help')) { console.log('Usage: agent-toolkit serve [--host HOST] [--port PORT]'); process.exit(0); }
if (${exitOnServe}) { console.error('boom: fixture refuses to serve ' + (process.env.MCP_TEST_LOG_PREFIX ?? '') + (process.env.MCP_TEST_SECRET ?? '') + (process.env.MCP_TEST_LOG_SUFFIX ?? '')); process.exit(3); }
const port = Number(args[args.indexOf('--port') + 1]);
const server = http.createServer((req, res) => {
  if (req.url === '/api/v1/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ ok: true, version: '${version}', uptime_s: 1 }));
  } else if (req.url === '/__fixture/spawn') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ cwd: process.cwd(), workspace: process.env.AGENT_TOOLKIT_WORKSPACE ?? null }));
  } else if (req.url === '/__fixture/pid') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ pid: process.pid }));
  } else if (req.url === '/__fixture/secret') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ value: process.env.MCP_TEST_SECRET ?? null }));
  } else if (req.url === '/api/v1/jobs' && req.method === 'POST') {
    const crossSite = req.headers['sec-fetch-site'] === 'cross-site';
    const allowed = !crossSite || (${gate} && req.headers['x-atk-desktop'] === '1');
    res.writeHead(allowed ? 422 : 403, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ ok: false, error: allowed ? 'cmd is required' : 'cross-site request forbidden' }));
  } else {
    res.writeHead(404);
    res.end('{}');
  }
});
server.listen(port, '127.0.0.1');
`;
}

function writeFixture(dir: string, options: FixtureOptions = {}): string {
  fs.mkdirSync(dir, { recursive: true });
  const bin = path.join(dir, 'agent-toolkit');
  fs.writeFileSync(bin, fixtureSource(options), { mode: 0o755 });
  return bin;
}

/**
 * Backend lifecycle against hermetic fixture binaries (runs everywhere,
 * including CI without a real agent-toolkit installed). Real-binary
 * supervision is proven separately by packaged-app UAT.
 */
describe('BackendSupervisor', () => {
  let fixtureDir = '';
  const saved: Record<string, string | undefined> = {};
  let supervisor: BackendSupervisor | null = null;

  beforeEach(() => {
    fixtureDir = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-fixture-'));
    for (const name of ['PATH', 'ATK_EXPECTED_BACKEND_MAJOR', 'ATK_BACKEND_BIN']) saved[name] = process.env[name];
    writeFixture(path.join(fixtureDir, 'good'));
    process.env.PATH = `${path.join(fixtureDir, 'good')}${path.delimiter}${saved.PATH ?? ''}`;
    process.env.ATK_EXPECTED_BACKEND_MAJOR = '9';
    delete process.env.ATK_BACKEND_BIN;
  });

  afterEach(async () => {
    for (const [name, value] of Object.entries(saved)) {
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
    if (supervisor) {
      await supervisor.stop();
      supervisor = null;
    }
    fs.rmSync(fixtureDir, { recursive: true, force: true });
  });

  it('starts, reports ready with binary identity, restarts, and stops', async () => {
    supervisor = newSupervisor({ resolveHarness: fallbackHarness });
    expect(await supervisor.start()).toBe(true);

    const snapshot = supervisor.snapshot();
    expect(snapshot.status).toBe('ready');
    expect(snapshot.url).toMatch(/^http:\/\/127\.0\.0\.1:\d+$/);
    expect(snapshot.version).toBe('9.9.9-test');
    expect(snapshot.binary).toEqual({
      path: path.join(fixtureDir, 'good', 'agent-toolkit'),
      source: 'path',
      version: '9.9.9-test',
    });
    expect(snapshot.problem).toBeNull();

    expect(await supervisor.restart()).toBe(true);
    expect(supervisor.snapshot().status).toBe('ready');
    expect(supervisor.snapshot().restarts).toBe(1);

    await supervisor.stop();
    expect(supervisor.snapshot().status).toBe('stopped');
  }, 90_000);

  it('injects stored secrets only into the supervised backend environment', async () => {
    supervisor = newSupervisor({
      resolveHarness: fallbackHarness,
      resolveEnvironmentSecrets: () => ({ MCP_TEST_SECRET: 'secret-value-for-child' }),
    });
    expect(await supervisor.start()).toBe(true);
    const url = supervisor.snapshot().url;
    expect(url).not.toBeNull();
    expect(await (await fetch(`${url}/__fixture/secret`)).json()).toEqual({ value: 'secret-value-for-child' });
    expect(JSON.stringify(supervisor.snapshot())).not.toContain('secret-value-for-child');
  }, 90_000);

  it('redacts a stored credential if the backend prints it to stderr during startup', async () => {
    writeFixture(path.join(fixtureDir, 'good'), { exitOnServe: true });
    supervisor = newSupervisor({
      resolveHarness: fallbackHarness,
      resolveEnvironmentSecrets: () => ({ MCP_TEST_SECRET: 'do-not-leak-this' }),
    });
    expect(await supervisor.start()).toBe(false);
    expect(supervisor.snapshot().detail).toContain('[credential redacted]');
    expect(supervisor.snapshot().detail).not.toContain('do-not-leak-this');
  }, 90_000);

  it('redacts credential fragments when the bounded stderr tail truncates the value', async () => {
    writeFixture(path.join(fixtureDir, 'good'), { exitOnServe: true });
    const secret = 's'.repeat(8_192);
    supervisor = newSupervisor({
      resolveHarness: fallbackHarness,
      resolveEnvironmentSecrets: () => ({
        MCP_TEST_SECRET: secret,
        MCP_TEST_LOG_PREFIX: 'p'.repeat(2_000),
        MCP_TEST_LOG_SUFFIX: 'done',
      }),
    });
    expect(await supervisor.start()).toBe(false);
    expect(supervisor.snapshot().detail).toContain('[credential redacted]');
    expect(supervisor.snapshot().detail).not.toContain(secret.slice(-200));
  }, 90_000);

  it('restarts into a new harness: stop, spawn in the new cwd, health gate', async () => {
    const first = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'atk-harness-a-')));
    const second = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'atk-harness-b-')));
    const harnessOf = (dir: string): HarnessResolution => ({
      path: dir,
      source: 'user',
      defaultPath: '/nonexistent/.ai-workspace',
      overrideVar: null,
      notice: null,
    });
    let current = harnessOf(first);
    const events: string[] = [];
    try {
      supervisor = newSupervisor({ resolveHarness: () => current });
      supervisor.onState((state: BackendState) => events.push(`${state.status}:${state.harness?.path ?? '-'}`));
      expect(await supervisor.start()).toBe(true);
      const spawnedAt = async (): Promise<unknown> =>
        (await fetch(`${supervisor!.snapshot().url}/__fixture/spawn`)).json();
      expect(await spawnedAt()).toEqual({ cwd: first, workspace: first });

      current = harnessOf(second);
      events.length = 0;
      expect(await supervisor.restart()).toBe(true);
      expect(await spawnedAt()).toEqual({ cwd: second, workspace: second });
      expect(supervisor.snapshot().harness).toEqual(current);
      // The old child is fully stopped before anything starts in the new harness.
      expect(events[0]).toBe(`stopped:${first}`);
      expect(events.at(-1)).toBe(`ready:${second}`);
      expect(events.findIndex((e) => e.startsWith('starting:'))).toBeGreaterThan(0);
    } finally {
      await supervisor?.stop();
      supervisor = null;
      fs.rmSync(first, { recursive: true, force: true });
      fs.rmSync(second, { recursive: true, force: true });
    }
  }, 90_000);

  it('skips a stale PATH binary without serve and reports why', async () => {
    const stale = writeFixture(path.join(fixtureDir, 'stale'), { version: '9.0.0', serve: false });
    process.env.PATH = `${path.dirname(stale)}${path.delimiter}${process.env.PATH}`;
    supervisor = newSupervisor({ resolveHarness: fallbackHarness });
    expect(await supervisor.start()).toBe(true);
    const snapshot = supervisor.snapshot();
    expect(snapshot.binary?.path).toBe(path.join(fixtureDir, 'good', 'agent-toolkit'));
    expect(snapshot.rejected).toHaveLength(1);
    expect(snapshot.rejected[0]).toMatchObject({ path: stale, version: '9.0.0' });
    expect(snapshot.rejected[0]?.reason).toContain('has no `serve` command');
    expect(snapshot.detail).toContain(`skipped ${stale}`);
  }, 90_000);

  it('fails with binary-rejected (never "crashed") when only a stale binary exists', async () => {
    const stale = writeFixture(path.join(fixtureDir, 'stale'), { version: '9.0.0', serve: false });
    // Keep node reachable for the fixture's shebang.
    process.env.PATH = `${path.dirname(stale)}${path.delimiter}${path.dirname(process.execPath)}`;
    supervisor = newSupervisor({ resolveHarness: fallbackHarness });
    expect(await supervisor.start()).toBe(false);
    const snapshot = supervisor.snapshot();
    expect(snapshot.status).toBe('failed');
    expect(snapshot.problem).toBe('binary-rejected');
    expect(snapshot.detail).toContain(`${stale} (path, 9.0.0): too old: has no \`serve\` command`);
    expect(snapshot.detail).toContain('ATK_BACKEND_BIN');
  }, 30_000);

  it('rejects a PATH binary with the wrong pinned major before spawning it', async () => {
    process.env.ATK_EXPECTED_BACKEND_MAJOR = '2';
    supervisor = newSupervisor({ resolveHarness: fallbackHarness });
    expect(await supervisor.start()).toBe(false);
    const snapshot = supervisor.snapshot();
    expect(snapshot.problem).toBe('binary-rejected');
    expect(snapshot.rejected[0]?.reason).toContain('needs major 2 (ATK_EXPECTED_BACKEND_MAJOR = 2)');
  }, 30_000);

  it('uses ATK_BACKEND_BIN first and never falls through when it is broken', async () => {
    const explicit = writeFixture(path.join(fixtureDir, 'explicit'));
    process.env.ATK_BACKEND_BIN = explicit;
    supervisor = newSupervisor({ resolveHarness: fallbackHarness });
    expect(await supervisor.start()).toBe(true);
    expect(supervisor.snapshot().binary).toMatchObject({ path: explicit, source: 'env' });
    await supervisor.stop();

    process.env.ATK_BACKEND_BIN = path.join(fixtureDir, 'missing', 'agent-toolkit');
    expect(await supervisor.start()).toBe(false);
    expect(supervisor.snapshot()).toMatchObject({ status: 'failed', problem: 'binary-rejected', binary: null });
    expect(supervisor.snapshot().detail).toContain('not an executable file');
    expect(supervisor.snapshot().detail).toContain('Fix or unset ATK_BACKEND_BIN');
  }, 90_000);

  it('reports a pre-gate backend as version-mismatch/desktop-gate-missing', async () => {
    const old = writeFixture(path.join(fixtureDir, 'old'), { gate: false });
    process.env.ATK_BACKEND_BIN = old;
    supervisor = newSupervisor({ resolveHarness: fallbackHarness });
    expect(await supervisor.start()).toBe(false);
    const snapshot = supervisor.snapshot();
    expect(snapshot.status).toBe('version-mismatch');
    expect(snapshot.problem).toBe('desktop-gate-missing');
    expect(snapshot.detail).toContain('predates the X-Atk-Desktop first-party gate');
    expect(snapshot.url).not.toBeNull();
  }, 90_000);

  it('reports an exit before health as a startup failure, not a crash', async () => {
    process.env.ATK_BACKEND_BIN = writeFixture(path.join(fixtureDir, 'dies'), { exitOnServe: true });
    supervisor = newSupervisor({ resolveHarness: fallbackHarness });
    expect(await supervisor.start()).toBe(false);
    const snapshot = supervisor.snapshot();
    expect(snapshot.status).toBe('failed');
    expect(snapshot.problem).toBe('exited-during-start');
    expect(snapshot.detail).toContain('exited during startup code=3');
    expect(snapshot.detail).toContain('boom');
  }, 30_000);

  it('reports a crash after ready as crashed/exited', async () => {
    supervisor = newSupervisor({ resolveHarness: fallbackHarness });
    expect(await supervisor.start()).toBe(true);
    const crashed = new Promise<BackendState>((resolve) => {
      supervisor!.onState((state) => {
        if (state.status === 'crashed') resolve(state);
      });
    });
    const { pid } = (await (await fetch(`${supervisor.snapshot().url}/__fixture/pid`)).json()) as { pid: number };
    process.kill(pid, 'SIGKILL');
    const state = await crashed;
    expect(state.problem).toBe('exited');
    expect(state.detail).toContain('signal=SIGKILL');
  }, 90_000);

  it('abandons an in-flight start when stopped', async () => {
    let release: () => void = () => undefined;
    supervisor = newSupervisor({
      resolveHarness: fallbackHarness,
      selectBinary: () =>
        new Promise((resolve) => {
          release = () => resolve({ ok: false, problem: 'no-backend', message: 'late', rejected: [] });
        }),
    });
    const pending = supervisor.start();
    await supervisor.stop();
    release();
    expect(await pending).toBe(false);
    expect(supervisor.snapshot().status).toBe('stopped');
  });

  it('shares one attempt between concurrent start() calls', async () => {
    let calls = 0;
    supervisor = newSupervisor({
      resolveHarness: fallbackHarness,
      selectBinary: async () => {
        calls += 1;
        return { ok: false, problem: 'no-backend', message: 'none', rejected: [] };
      },
    });
    await Promise.all([supervisor.start(), supervisor.start()]);
    expect(calls).toBe(1);
    expect(supervisor.snapshot()).toMatchObject({ status: 'failed', problem: 'no-backend' });
  });

  it('parses the expected-major override', () => {
    process.env.ATK_EXPECTED_BACKEND_MAJOR = 'v2.0.0';
    expect(resolveExpectedBackendMajor()).toBe('2');
    process.env.ATK_EXPECTED_BACKEND_MAJOR = '9';
    expect(resolveExpectedBackendMajor()).toBe('9');
  });

  it('reports version-mismatch when the healthy backend drifts from the pin', async () => {
    supervisor = newSupervisor({
      resolveHarness: fallbackHarness,
      resolvePin: () => ({ major: '1', version: '1.0.0', source: 'backend-version.json' }),
    });
    expect(await supervisor.start()).toBe(false);
    expect(supervisor.snapshot()).toMatchObject({
      status: 'version-mismatch',
      problem: 'major-mismatch',
      version: '9.9.9-test',
    });
  }, 90_000);
});
