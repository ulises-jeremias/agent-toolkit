// @vitest-environment node
import { execFileSync, spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import net from 'node:net';
import os from 'node:os';
import path from 'node:path';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { captureCodexSessionId } from './provider-session-capture.js';
import { PtyHostClient } from './pty-host-client.js';
import { PtyHostCore } from './pty-host-core.js';
import { encodeFrame, PTY_HOST_PROTOCOL, ptyRuntimeDir, ptySocketPath, readOrCreateToken } from './pty-protocol.js';

const desktopDir = path.resolve(__dirname, '..');

function tempRuntimeDir(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'atk-pty-host-test-'));
}

async function waitFor(check: () => Promise<boolean>, timeoutMs = 15_000): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  for (;;) {
    if (await check()) return;
    if (Date.now() > deadline) throw new Error('waitFor timed out');
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
}

async function waitForProcessExit(pid: number, timeoutMs = 15_000): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  for (;;) {
    try {
      process.kill(pid, 0);
    } catch {
      return; // ESRCH: process is gone.
    }
    if (Date.now() > deadline) throw new Error(`process ${pid} did not exit`);
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
}

/** rm -rf that tolerates a dying host still releasing files (ENOTEMPTY race). */
async function removeDirRobust(dir: string): Promise<void> {
  for (let attempt = 0; attempt < 20; attempt++) {
    try {
      fs.rmSync(dir, { recursive: true, force: true });
      return;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOTEMPTY' || attempt === 19) throw error;
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
  }
}

describe('ptyRuntimeDir', () => {
  it('honors the absolute AGENT_TOOLKIT_PTY_RUNTIME_DIR override over XDG', () => {
    expect(ptyRuntimeDir({ AGENT_TOOLKIT_PTY_RUNTIME_DIR: '/tmp/atk-pty-iso', XDG_RUNTIME_DIR: '/run/user/1000' })).toBe(
      '/tmp/atk-pty-iso',
    );
  });

  it('ignores a relative override and falls back to the XDG runtime dir', () => {
    expect(ptyRuntimeDir({ AGENT_TOOLKIT_PTY_RUNTIME_DIR: 'relative/dir', XDG_RUNTIME_DIR: '/run/user/1000' })).toBe(
      path.join('/run/user/1000', 'agent-toolkit'),
    );
  });
});

describe('PtyHost (ADR-037)', () => {
  it('keeps sessions alive across client disconnect and reattaches with output intact', async () => {
    const runtimeDir = tempRuntimeDir();
    const token = readOrCreateToken(runtimeDir, () => randomUUID());
    const core = new PtyHostCore({ runtimeDir, token });
    await core.listen();
    const noSpawn = () => {
      throw new Error('host already listening; spawn must not be called');
    };
    try {
      const clientA = new PtyHostClient({ runtimeDir, spawnHost: noSpawn });
      const session = await clientA.create({
        agent: 'survivor',
        cmd: '/bin/sh',
        args: [],
        cwd: os.tmpdir(),
      });
      expect(await clientA.write(session.id, 'echo marker-$((6*7))\n')).toBe(true);
      await waitFor(async () => (await clientA.tail(session.id)).includes('marker-42'));

      // Simulate app death: the client socket goes away, nothing is killed.
      clientA.disconnect();

      const clientB = new PtyHostClient({ runtimeDir, spawnHost: noSpawn });
      const adopted = await clientB.list();
      expect(adopted.map((info) => info.id)).toContain(session.id);
      expect(await clientB.tail(session.id)).toContain('marker-42');

      // The reattached session is fully interactive, not a read-only ghost.
      expect(await clientB.write(session.id, 'echo again-$((1+1))\n')).toBe(true);
      await waitFor(async () => (await clientB.tail(session.id)).includes('again-2'));

      expect(await clientB.close(session.id)).toBe(true);
      await waitFor(async () => (await clientB.list()).length === 0);
      clientB.disconnect();
    } finally {
      core.terminateAll();
      await core.close();
      fs.rmSync(runtimeDir, { recursive: true, force: true });
    }
  }, 60_000);

  it('destroys connections that do not present the shared token', async () => {
    const runtimeDir = tempRuntimeDir();
    const token = readOrCreateToken(runtimeDir, () => randomUUID());
    const core = new PtyHostCore({ runtimeDir, token });
    await core.listen();
    try {
      const closed = await new Promise<boolean>((resolve) => {
        const socket = net.createConnection(ptySocketPath(runtimeDir));
        const timer = setTimeout(() => resolve(false), 5_000);
        socket.on('connect', () => {
          socket.write(encodeFrame({ id: 0, op: 'hello', token: 'wrong-token', protocol: PTY_HOST_PROTOCOL }));
        });
        socket.on('close', () => {
          clearTimeout(timer);
          resolve(true);
        });
        socket.on('error', () => {
          clearTimeout(timer);
          resolve(true);
        });
      });
      expect(closed).toBe(true);
    } finally {
      core.terminateAll();
      await core.close();
      fs.rmSync(runtimeDir, { recursive: true, force: true });
    }
  }, 30_000);

  it('captures the codex session id recorded for the session cwd', async () => {
    const runtimeDir = tempRuntimeDir();
    const codexHome = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-codex-home-'));
    const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-codex-cwd-'));
    const previousCodexHome = process.env.CODEX_HOME;
    process.env.CODEX_HOME = codexHome;
    const token = readOrCreateToken(runtimeDir, () => randomUUID());
    const core = new PtyHostCore({ runtimeDir, token });
    await core.listen();
    try {
      const client = new PtyHostClient({
        runtimeDir,
        spawnHost: () => {
          throw new Error('host already listening');
        },
      });
      const rolloutDir = path.join(codexHome, 'sessions', '2026', '10', '21');
      const meta = JSON.stringify({ type: 'session_meta', payload: { id: 'codex-conv-123', cwd: workDir } });
      const script = `mkdir -p ${rolloutDir} && printf '%s\\n' '${meta}' > ${path.join(rolloutDir, 'rollout-test.jsonl')} && sleep 30`;
      const session = await client.create({ agent: 'codex-test', provider: 'codex', cmd: '/bin/sh', args: ['-c', script], cwd: workDir });
      expect(session.providerSessionId).toBeUndefined();
      await waitFor(async () => {
        const info = (await client.list()).find((candidate) => candidate.id === session.id);
        return info?.providerSessionId === 'codex-conv-123';
      });
      expect(await client.close(session.id)).toBe(true);
      client.disconnect();
    } finally {
      if (previousCodexHome === undefined) delete process.env.CODEX_HOME;
      else process.env.CODEX_HOME = previousCodexHome;
      core.terminateAll();
      await core.close();
      fs.rmSync(runtimeDir, { recursive: true, force: true });
      fs.rmSync(codexHome, { recursive: true, force: true });
      fs.rmSync(workDir, { recursive: true, force: true });
    }
  }, 60_000);

  it('never captures a codex session recorded for a different cwd', async () => {
    const codexHome = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-codex-home-'));
    try {
      const rolloutDir = path.join(codexHome, 'sessions', '2026', '10', '21');
      fs.mkdirSync(rolloutDir, { recursive: true });
      fs.writeFileSync(
        path.join(rolloutDir, 'rollout-other.jsonl'),
        `${JSON.stringify({ type: 'session_meta', payload: { id: 'other-conv', cwd: '/somewhere/else' } })}\n`,
      );
      const captured = await captureCodexSessionId({
        cwd: os.tmpdir(),
        sinceMs: Date.now() - 60_000,
        codexHome,
        timeoutMs: 300,
        intervalMs: 50,
      });
      expect(captured).toBeNull();
    } finally {
      fs.rmSync(codexHome, { recursive: true, force: true });
    }
  }, 30_000);

  describe('detached host process', () => {
    let buildDir = '';

    beforeAll(() => {
      buildDir = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-pty-host-build-'));
      execFileSync(
        path.join(desktopDir, 'node_modules', '.bin', 'tsc'),
        ['-p', 'tsconfig.node.json', '--noEmit', 'false', '--outDir', buildDir, '--rootDir', 'electron'],
        { cwd: desktopDir, stdio: 'pipe' },
      );
    }, 300_000);

    afterAll(() => {
      if (buildDir) fs.rmSync(buildDir, { recursive: true, force: true });
    });

    it('survives the death of the process that created the session', async () => {
      const runtimeDir = tempRuntimeDir();
      const driverPath = path.join(runtimeDir, 'driver.cjs');
      fs.writeFileSync(
        driverPath,
        [
          `const { PtyHostClient } = require(${JSON.stringify(path.join(buildDir, 'pty-host-client.js'))});`,
          '(async () => {',
          '  const client = new PtyHostClient({ runtimeDir: process.argv[2] });',
          "  const session = await client.create({ agent: 'driver', cmd: '/bin/sh', args: ['-c', 'echo driver-marker; sleep 60'], cwd: process.argv[3] });",
          '  console.log(session.id);',
          '  client.disconnect();',
          '  process.exit(0);',
          '})().catch((error) => { console.error(error); process.exit(1); });',
        ].join('\n'),
      );
      const nodeModules = path.join(desktopDir, 'node_modules');
      const sessionId = await new Promise<string>((resolve, reject) => {
        const driver = spawn(process.execPath, [driverPath, runtimeDir, os.tmpdir()], {
          env: { ...process.env, NODE_PATH: nodeModules },
          stdio: ['ignore', 'pipe', 'pipe'],
        });
        let out = '';
        let err = '';
        driver.stdout.on('data', (chunk: Buffer) => (out += chunk.toString()));
        driver.stderr.on('data', (chunk: Buffer) => (err += chunk.toString()));
        driver.on('exit', (code) => {
          if (code === 0 && out.trim()) resolve(out.trim());
          else reject(new Error(`driver failed (${code}): ${err}`));
        });
      });
      // The driver process is gone. Its PTY must still be alive in the host.
      try {
        const client = new PtyHostClient({
          runtimeDir,
          spawnHost: () => {
            throw new Error('detached host should already be running');
          },
        });
        await waitFor(async () => (await client.list()).some((info) => info.id === sessionId));
        await waitFor(async () => (await client.tail(sessionId)).includes('driver-marker'));
        expect(await client.close(sessionId)).toBe(true);
        await waitFor(async () => (await client.list()).length === 0);
        client.disconnect();
      } finally {
        // Stop the detached host explicitly via its registry pid, wait
        // for it to actually exit, then remove the runtime dir. Removing
        // while the host is still shutting down races with its socket /
        // registry cleanup and intermittently fails with ENOTEMPTY.
        try {
          const registry = JSON.parse(fs.readFileSync(path.join(runtimeDir, 'pty-registry.json'), 'utf8')) as {
            pid: number;
          };
          process.kill(registry.pid, 'SIGTERM');
          await waitForProcessExit(registry.pid);
        } catch {
          // Host already exited.
        }
        await removeDirRobust(runtimeDir);
      }
    }, 120_000);
  });
});
