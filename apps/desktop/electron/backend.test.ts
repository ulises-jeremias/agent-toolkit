// @vitest-environment node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { BackendSupervisor, resolveExpectedBackendMajor } from './backend';

const FIXTURE_SOURCE = `#!/usr/bin/env node
// Minimal 'agent-toolkit serve' stand-in: serves /api/v1/health only.
const http = require('node:http');
const args = process.argv.slice(2);
const port = Number(args[args.indexOf('--port') + 1]);
const server = http.createServer((req, res) => {
  if (req.url === '/api/v1/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ ok: true, version: '9.9.9-test', uptime_s: 1 }));
  } else {
    res.writeHead(404);
    res.end('{}');
  }
});
server.listen(port, '127.0.0.1');
`;

/**
 * Backend lifecycle against a hermetic fixture binary (runs everywhere,
 * including CI without a real agent-toolkit installed). Real-binary
 * supervision is proven separately by packaged-app UAT (CDP tour against
 * linux-unpacked with the bundled backend).
 */
describe('BackendSupervisor', () => {
  let fixtureDir = '';
  let savedPath = '';
  let savedExpected = '';
  let supervisor: BackendSupervisor | null = null;

  beforeEach(() => {
    fixtureDir = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-fixture-'));
    const bin = path.join(fixtureDir, 'agent-toolkit');
    fs.writeFileSync(bin, FIXTURE_SOURCE, { mode: 0o755 });
    savedPath = process.env.PATH ?? '';
    process.env.PATH = `${fixtureDir}${path.delimiter}${savedPath}`;
    savedExpected = process.env.ATK_EXPECTED_BACKEND_MAJOR ?? '';
    process.env.ATK_EXPECTED_BACKEND_MAJOR = '9';
  });

  afterEach(async () => {
    process.env.PATH = savedPath;
    if (savedExpected) process.env.ATK_EXPECTED_BACKEND_MAJOR = savedExpected;
    else delete process.env.ATK_EXPECTED_BACKEND_MAJOR;
    if (supervisor) {
      await supervisor.stop();
      supervisor = null;
    }
    fs.rmSync(fixtureDir, { recursive: true, force: true });
  });

  it('starts, reports ready with a version, restarts, and stops', async () => {
    supervisor = new BackendSupervisor();
    const started = await supervisor.start();
    expect(started).toBe(true);

    const snapshot = supervisor.snapshot();
    expect(snapshot.status).toBe('ready');
    expect(snapshot.url).toMatch(/^http:\/\/127\.0\.0\.1:\d+$/);
    expect(snapshot.version).toBe('9.9.9-test');

    const restarted = await supervisor.restart();
    expect(restarted).toBe(true);
    expect(supervisor.snapshot().status).toBe('ready');

    await supervisor.stop();
    expect(supervisor.snapshot().status).toBe('stopped');
  }, 90_000);

  it('parses the expected-major override', () => {
    process.env.ATK_EXPECTED_BACKEND_MAJOR = 'v2.0.0';
    expect(resolveExpectedBackendMajor()).toBe('2');
    process.env.ATK_EXPECTED_BACKEND_MAJOR = '9';
    expect(resolveExpectedBackendMajor()).toBe('9');
  });

  it('reports version-mismatch instead of ready on major drift', async () => {
    process.env.ATK_EXPECTED_BACKEND_MAJOR = '1';
    supervisor = new BackendSupervisor();
    const started = await supervisor.start();
    expect(started).toBe(false);
    expect(supervisor.snapshot().status).toBe('version-mismatch');
    expect(supervisor.snapshot().version).toBe('9.9.9-test');
  }, 90_000);
});
