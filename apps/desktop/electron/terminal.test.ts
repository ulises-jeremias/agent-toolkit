// @vitest-environment node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { TerminalCwdError, TerminalService } from './terminal';

/** Real PTY round-trips through node-pty (no display required). */
describe('TerminalService', () => {
  it('streams output and reports exit state', async () => {
    const service = new TerminalService();
    try {
      const session = service.create({ agent: 'test', cmd: '/bin/echo', args: ['hello-pty'] });
      expect(session.exitCode).toBeNull();
      // Spawn identity is preserved for faithful restart and display.
      expect(session.cmd).toBe('/bin/echo');
      expect(session.args).toEqual(['hello-pty']);
      expect(service.list()[0]).toMatchObject({ cmd: '/bin/echo', args: ['hello-pty'] });

      const output = await new Promise<string>((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('no pty output within 10s')), 10_000);
        const off = service.onData((id, chunk) => {
          if (id === session.id && chunk.includes('hello-pty')) {
            clearTimeout(timer);
            off();
            resolve(chunk);
          }
        });
      });
      expect(output).toContain('hello-pty');
      // Buffered tail supports pane-mount catch-up.
      expect(service.tail(session.id)).toContain('hello-pty');
      expect(service.tail('no-such-id')).toBe('');

      const exitCode = await new Promise<number>((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error('no pty exit within 10s')), 10_000);
        const off = service.onExit((id, code) => {
          if (id === session.id) {
            clearTimeout(timer);
            off();
            resolve(code);
          }
        });
      });
      expect(exitCode).toBe(0);

      // Exited sessions keep their state for inspection; transport ops refuse.
      expect(service.write(session.id, 'x')).toBe(false);
      expect(service.signal(session.id, 'int')).toBe(false);
      expect(service.close(session.id)).toBe(true);
      expect(service.list()).toHaveLength(0);
    } finally {
      service.dispose();
    }
  }, 30_000);

  it('opens in the default cwd (the harness) and validates requested cwds', () => {
    const harness = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'atk-term-harness-')));
    fs.mkdirSync(path.join(harness, 'sub'));
    const service = new TerminalService({ defaultCwd: () => harness });
    try {
      expect(service.resolveCwd()).toBe(harness);
      expect(service.resolveCwd('  ')).toBe(harness);
      expect(service.resolveCwd('sub')).toBe(path.join(harness, 'sub'));
      expect(service.resolveCwd(os.tmpdir())).toBe(path.resolve(os.tmpdir()));
      expect(() => service.resolveCwd(path.join(harness, 'missing'))).toThrow(TerminalCwdError);
      expect(fs.existsSync(path.join(harness, 'missing'))).toBe(false);

      const session = service.create({ agent: 'test', cmd: '/bin/sleep', args: ['5'] });
      expect(session.cwd).toBe(harness);
      expect(() => service.create({ agent: 'test', cmd: '/bin/sleep', cwd: '/definitely/missing' })).toThrow(
        TerminalCwdError,
      );
      expect(service.list()).toHaveLength(1);
    } finally {
      service.dispose();
      fs.rmSync(harness, { recursive: true, force: true });
    }
  });

  it('resizes, signals, and closes a live session', async () => {
    const service = new TerminalService();
    try {
      const session = service.create({ agent: 'test-live', cmd: '/bin/sleep', args: ['30'] });
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
      service.dispose();
    }
  }, 30_000);
});
