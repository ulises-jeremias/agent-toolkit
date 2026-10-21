// @vitest-environment node
import { randomUUID } from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { PtyHostClient } from './pty-host-client.js';
import { PtyHostCore } from './pty-host-core.js';
import { readOrCreateToken } from './pty-protocol.js';
import { TerminalCwdError, TerminalService } from './terminal.js';

function tempRuntimeDir(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'atk-pty-runtime-'));
}

/**
 * Tests run from TypeScript sources, where the compiled pty-host.js entry
 * does not exist yet; stand the host core up in-process instead. The
 * detached-process path itself is covered by pty-host.test.ts against the
 * real tsc build.
 */
const cores = new Map<string, PtyHostCore>();

function testClient(runtimeDir: string): PtyHostClient {
  return new PtyHostClient({
    runtimeDir,
    spawnHost: () => {
      if (cores.has(runtimeDir)) return;
      const core = new PtyHostCore({ runtimeDir, token: readOrCreateToken(runtimeDir, () => randomUUID()) });
      cores.set(runtimeDir, core);
      void core.listen();
    },
  });
}

function makeService(options: { runtimeDir: string; defaultCwd?: () => string }): TerminalService {
  return new TerminalService({ ...options, client: testClient(options.runtimeDir) });
}

async function cleanup(service: TerminalService, runtimeDir: string): Promise<void> {
  await service.terminateAll().catch(() => undefined);
  service.dispose();
  const core = cores.get(runtimeDir);
  if (core) {
    core.terminateAll();
    await core.close();
    cores.delete(runtimeDir);
  }
  fs.rmSync(runtimeDir, { recursive: true, force: true });
}

/** Real PTY round-trips through the detached host + node-pty (no display required). */
describe('TerminalService', () => {
  it('streams output and reports exit state', async () => {
    const runtimeDir = tempRuntimeDir();
    const service = makeService({ runtimeDir });
    try {
      // Subscribe before create: with the host transport, output can arrive
      // in the same socket batch as the create response.
      const outputPromise = new Promise<string>((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('no pty output within 10s')), 10_000);
        const off = service.onData((_id, chunk) => {
          if (chunk.includes('hello-pty')) {
            clearTimeout(timer);
            off();
            resolve(chunk);
          }
        });
      });
      const exitPromise = new Promise<number>((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('no pty exit within 10s')), 10_000);
        const off = service.onExit((_id, code) => {
          clearTimeout(timer);
          off();
          resolve(code);
        });
      });
      const session = await service.create({ agent: 'test', cmd: '/bin/echo', args: ['hello-pty'] });
      expect(session.exitCode).toBeNull();
      // Spawn identity is preserved for faithful restart and display.
      expect(session.cmd).toBe('/bin/echo');
      expect(session.args).toEqual(['hello-pty']);
      expect(service.list()[0]).toMatchObject({ cmd: '/bin/echo', args: ['hello-pty'] });

      const output = await outputPromise;
      expect(output).toContain('hello-pty');
      // Buffered tail supports pane-mount catch-up.
      expect(service.tail(session.id)).toContain('hello-pty');
      expect(service.tail('no-such-id')).toBe('');

      const exitCode = await exitPromise;
      expect(exitCode).toBe(0);

      // Exited sessions keep their state for inspection; transport ops refuse.
      expect(service.write(session.id, 'x')).toBe(false);
      expect(service.signal(session.id, 'int')).toBe(false);
      expect(service.close(session.id)).toBe(true);
      expect(service.list()).toHaveLength(0);
    } finally {
      await cleanup(service, runtimeDir);
    }
  }, 30_000);

  it('opens in the default cwd (the harness) and validates requested cwds', async () => {
    const harness = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'atk-term-harness-')));
    fs.mkdirSync(path.join(harness, 'sub'));
    const runtimeDir = tempRuntimeDir();
    const service = makeService({ defaultCwd: () => harness, runtimeDir });
    try {
      expect(service.resolveCwd()).toBe(harness);
      expect(service.resolveCwd('  ')).toBe(harness);
      expect(service.resolveCwd('sub')).toBe(path.join(harness, 'sub'));
      expect(service.resolveCwd(os.tmpdir())).toBe(path.resolve(os.tmpdir()));
      expect(() => service.resolveCwd(path.join(harness, 'missing'))).toThrow(TerminalCwdError);
      expect(fs.existsSync(path.join(harness, 'missing'))).toBe(false);

      const session = await service.create({ agent: 'test', cmd: '/bin/sleep', args: ['5'] });
      expect(session.cwd).toBe(harness);
      await expect(service.create({ agent: 'test', cmd: '/bin/sleep', cwd: '/definitely/missing' })).rejects.toThrow(
        TerminalCwdError,
      );
      expect(service.list()).toHaveLength(1);
    } finally {
      await cleanup(service, runtimeDir);
      fs.rmSync(harness, { recursive: true, force: true });
    }
  });

  it('retains Person and project identity on a real PTY until it is reaped', async () => {
    const runtimeDir = tempRuntimeDir();
    const service = makeService({ runtimeDir });
    try {
      const session = await service.create({
        agent: 'Lina',
        personId: 'lina',
        agentSessionId: 'session-test-lina',
        sessionWorkspace: '/work/harness',
        projectId: 'agent-toolkit',
        provider: 'opencode',
        model: 'model-x',
        cmd: '/bin/sleep',
        args: ['30'],
        cwd: process.cwd(),
      });
      expect(service.list()[0]).toMatchObject({
        id: session.id,
        agent: 'Lina',
        personId: 'lina',
        agentSessionId: 'session-test-lina',
        sessionWorkspace: '/work/harness',
        projectId: 'agent-toolkit',
        provider: 'opencode',
        model: 'model-x',
        exitCode: null,
      });
      const exited = new Promise<{ code: number; reason?: string }>((resolve) => {
        service.onExit((id, code, reason) => {
          if (id === session.id) resolve({ code, reason });
        });
      });
      expect(service.close(session.id)).toBe(true);
      await expect(exited).resolves.toMatchObject({ reason: 'user-stop' });
      expect(service.list()).toHaveLength(0);
    } finally {
      await cleanup(service, runtimeDir);
    }
  });

  it('terminates a Person PTY when its configured time budget expires', async () => {
    const runtimeDir = tempRuntimeDir();
    const service = makeService({ runtimeDir });
    try {
      const session = await service.create({
        agent: 'bounded-person',
        personId: 'bounded',
        cmd: '/bin/sleep',
        args: ['30'],
        maxSeconds: 1,
      });
      expect(session.maxSeconds).toBe(1);
      const exit = await new Promise<{ code: number; reason?: string }>((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('time budget did not stop the PTY within 10s')), 10_000);
        const off = service.onExit((id, code) => {
          if (id !== session.id) return;
          clearTimeout(timer);
          off();
          resolve({ code, reason: service.list().find((item) => item.id === id)?.exitReason });
        });
      });
      expect(exit.reason).toBe('time-budget');
      expect(typeof exit.code).toBe('number');
    } finally {
      await cleanup(service, runtimeDir);
    }
  }, 15_000);

  it('resizes, signals, and closes a live session', async () => {
    const runtimeDir = tempRuntimeDir();
    const service = makeService({ runtimeDir });
    try {
      const session = await service.create({ agent: 'test-live', cmd: '/bin/sleep', args: ['30'] });
      expect(service.resize(session.id, 100, 25)).toBe(true);
      expect(service.write(session.id, '')).toBe(true);

      const exitCode = await new Promise<number>((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('no pty exit within 10s')), 10_000);
        const off = service.onExit((id, code) => {
          if (id === session.id) {
            clearTimeout(timer);
            off();
            resolve(code);
          }
        });
        expect(service.signal(session.id, 'term')).toBe(true);
      });
      // node-pty reports the wait status code; what matters here is that the
      // signal terminated the session and the exit event fired exactly once.
      expect(typeof exitCode).toBe('number');
      expect(service.close(session.id)).toBe(true);
    } finally {
      await cleanup(service, runtimeDir);
    }
  }, 30_000);
});
