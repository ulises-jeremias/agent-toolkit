// @vitest-environment node
import { describe, expect, it } from 'vitest';
import { TerminalService } from './terminal';

/** Real PTY round-trips through node-pty (no display required). */
describe('TerminalService', () => {
  it('streams output and reports exit state', async () => {
    const service = new TerminalService();
    try {
      const session = service.create({ agent: 'test', cmd: '/bin/echo', args: ['hello-pty'] });
      expect(session.exitCode).toBeNull();

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
