// @vitest-environment node
import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { AdapterSink } from './adapter';
import { CodexSession } from './codex';
const sessions: CodexSession[] = [];
function harness(args: string[] = [], requestTimeoutMs = 30_000) {
  const sink: AdapterSink = {
    session: vi.fn(),
    models: vi.fn(),
    delta: vi.fn(),
    item: vi.fn(),
    approval: vi.fn(),
    approvalCancelled: vi.fn(),
    userInput: vi.fn(),
    userInputCancelled: vi.fn(),
    turnFinished: vi.fn(),
    exited: vi.fn(),
  };
  const session = new CodexSession(
    {
      binary: process.execPath,
      cwd: process.cwd(),
      env: process.env,
      model: null,
      permissionMode: 'ask',
      resumeSessionId: null,
    },
    sink,
    [path.join(__dirname, 'testing/fake-codex.mjs'), ...args],
    requestTimeoutMs,
  );
  sessions.push(session);
  return { session, sink };
}
afterEach(() => {
  for (const session of sessions.splice(0)) session.dispose(true);
});
describe('Codex app-server protocol', () => {
  it.skipIf(process.platform !== 'linux')(
    'forced shutdown stops descendants before they can keep mutating files',
    async () => {
      const runtimeDir = fs.mkdtempSync(path.join(process.env.TMPDIR ?? os.tmpdir(), 'atk-codex-descendant-'));
      const pidFile = path.join(runtimeDir, 'grandchild.pid');
      const mutationFile = path.join(runtimeDir, 'mutation.log');
      const { session, sink } = harness(['--spawn-grandchild', pidFile, mutationFile]);
      try {
        session.send('hold');
        await vi.waitFor(() => expect(sink.session).toHaveBeenCalled(), { timeout: 3_000 });
        await vi.waitFor(() => expect(fs.existsSync(pidFile)).toBe(true), { timeout: 3_000 });
        await vi.waitFor(() => expect(fs.statSync(mutationFile).size).toBeGreaterThan(0), { timeout: 3_000 });
        const pid = Number(fs.readFileSync(pidFile, 'utf8').trim());
        expect(Number.isInteger(pid)).toBe(true);
        expect(isProcessRunning(pid)).toBe(true);

        session.dispose(true);
        await vi.waitFor(() => expect(sink.exited).toHaveBeenCalledWith(expect.objectContaining({ expected: true })), {
          timeout: 3_000,
        });
        await vi.waitFor(() => expect(isProcessRunning(pid)).toBe(false), { timeout: 3_000, interval: 50 });
        const sizeAfterShutdown = fs.statSync(mutationFile).size;
        await new Promise((resolve) => setTimeout(resolve, 150));
        expect(fs.statSync(mutationFile).size).toBe(sizeAfterShutdown);
      } finally {
        session.dispose(true);
        fs.rmSync(runtimeDir, { recursive: true, force: true });
      }
    },
  );

  it('keeps child and stale-turn frames out of the parent journal', async () => {
    const { session, sink } = harness();
    session.send('scope');
    await vi.waitFor(() => expect(sink.turnFinished).toHaveBeenCalledTimes(1));
    expect(sink.delta).not.toHaveBeenCalled();
    expect(sink.approval).not.toHaveBeenCalled();
    expect(sink.item).toHaveBeenCalledTimes(1);
    expect(sink.item).toHaveBeenCalledWith({ type: 'assistant', itemId: 'parent-message', text: 'parent text' });
    expect(sink.turnFinished).toHaveBeenCalledWith(expect.objectContaining({ outcome: 'completed' }));
  });
  it('refuses malformed question requests so the provider is not left waiting', async () => {
    const { session, sink } = harness();
    session.send('unsupported');
    await vi.waitFor(() => expect(sink.turnFinished).toHaveBeenCalledTimes(1));
    expect(sink.item).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'notice',
        level: 'error',
        text: expect.stringContaining('invalid'),
      }),
    );
  });
  it('answers a blocking question using the app-server shape without emitting answers to the journal sink', async () => {
    const { session, sink } = harness();
    session.send('question');
    await vi.waitFor(() => expect(sink.userInput).toHaveBeenCalledTimes(1));
    expect(sink.userInput).toHaveBeenCalledWith('codex-question', [
      expect.objectContaining({ id: 'purpose', isSecret: true }),
    ]);
    expect(session.respondUserInput('codex-question', { unrelated: ['wrong question'] })).toBe(false);
    expect(session.respondUserInput('codex-question', { purpose: ['user_note: private token'] })).toBe(true);
    await vi.waitFor(() => expect(sink.turnFinished).toHaveBeenCalledTimes(1));
    expect(sink.turnFinished).toHaveBeenCalledWith(expect.objectContaining({ outcome: 'completed' }));
    expect(sink.item).not.toHaveBeenCalledWith(expect.objectContaining({ text: 'private token' }));
    expect(session.respondUserInput('codex-question', { purpose: ['again'] })).toBe(false);
  });
  it('cancels a blocking question when the turn is interrupted', async () => {
    const { session, sink } = harness();
    session.send('question');
    await vi.waitFor(() => expect(sink.userInput).toHaveBeenCalledTimes(1));
    session.interrupt();
    await vi.waitFor(() => expect(sink.userInputCancelled).toHaveBeenCalledWith('codex-question', 'interrupt'));
    expect(session.respondUserInput('codex-question', { purpose: ['late answer'] })).toBe(false);
  });
  it('does not misreport context or thread token usage as per-turn usage', async () => {
    const { session, sink } = harness();
    session.send('usage');
    await vi.waitFor(() => expect(sink.turnFinished).toHaveBeenCalledTimes(1));
    expect(sink.turnFinished).toHaveBeenCalledWith(expect.objectContaining({ outcome: 'completed', usage: null }));
  });
  it('preserves approval context and uses the current response dialect', async () => {
    const { session, sink } = harness();
    session.send('approval');
    await vi.waitFor(() => expect(sink.approval).toHaveBeenCalledTimes(1));
    expect(sink.approval).toHaveBeenCalledWith(
      expect.objectContaining({
        canAllowForSession: true,
        input: expect.objectContaining({
          kind: 'writeStdin',
          networkApprovalContext: { host: 'example.test' },
          additionalPermissions: { network: { enabled: true } },
          availableDecisions: expect.arrayContaining([
            'accept',
            'acceptForSession',
            'decline',
            { acceptWithExecpolicyAmendment: { execpolicy_amendment: ['echo yes'] } },
          ]),
        }),
      }),
    );
    expect(session.respondApproval('codex-approval', 'allow-session')).toBe(true);
    await vi.waitFor(() => expect(sink.turnFinished).toHaveBeenCalledTimes(1));
    expect(sink.item).toHaveBeenCalledWith(expect.objectContaining({ text: 'acceptForSession' }));
  });
  it('does not offer or accept an unadvertised session grant', async () => {
    const { session, sink } = harness();
    session.send('approval-limited');
    await vi.waitFor(() => expect(sink.approval).toHaveBeenCalledTimes(1));
    expect(sink.approval).toHaveBeenCalledWith(expect.objectContaining({ canAllowForSession: false }));
    expect(session.respondApproval('codex-approval', 'allow-session')).toBe(false);
    expect(session.respondApproval('codex-approval', 'allow')).toBe(true);
    await vi.waitFor(() => expect(sink.turnFinished).toHaveBeenCalledTimes(1));
    expect(sink.item).toHaveBeenCalledWith(expect.objectContaining({ text: 'accept' }));
  });
  it('refuses an approval allowlist that has no safe one-shot allow and deny choices', async () => {
    const { session, sink } = harness();
    session.send('approval-unsupported');
    await vi.waitFor(() =>
      expect(sink.item).toHaveBeenCalledWith(
        expect.objectContaining({
          type: 'notice',
          level: 'error',
          text: expect.stringContaining('cannot present safely'),
        }),
      ),
    );
    expect(sink.approval).not.toHaveBeenCalled();
    expect(session.respondApproval('codex-approval', 'allow')).toBe(false);
  });
  it('reports an interrupt RPC failure without an unhandled rejection', async () => {
    const { session, sink } = harness();
    session.send('hold');
    await vi.waitFor(() => expect(sink.session).toHaveBeenCalled());
    await new Promise((resolve) => setTimeout(resolve, 50));
    session.interrupt();
    await vi.waitFor(() =>
      expect(sink.item).toHaveBeenCalledWith(
        expect.objectContaining({ text: 'Codex could not interrupt: interrupt failed' }),
      ),
    );
  });
  it('bounds handshake requests and terminates an unresponsive app-server', async () => {
    const { session, sink } = harness(['--hang-initialize'], 250);
    session.send('start');
    await vi.waitFor(() => expect(sink.exited).toHaveBeenCalledTimes(1), { timeout: 3_000 });
    expect(sink.exited).toHaveBeenCalledWith(
      expect.objectContaining({
        beforeSession: true,
        signal: 'SIGKILL',
        stderr: expect.stringContaining('initialize request timed out after 250 ms'),
      }),
    );
  });
  it('fails and stops an app-server that never answers turn/start', async () => {
    const { session, sink } = harness(['--hang-turn-start'], 250);
    session.send('hang');
    await vi.waitFor(() => expect(sink.turnFinished).toHaveBeenCalledTimes(1), { timeout: 3_000 });
    expect(sink.turnFinished).toHaveBeenCalledWith(
      expect.objectContaining({ outcome: 'failed', detail: 'Codex turn/start request timed out after 250 ms.' }),
    );
    await vi.waitFor(() => expect(sink.exited).toHaveBeenCalledTimes(1), { timeout: 3_000 });
  });
  it('clears pending RPC timeouts on forced disposal', async () => {
    const { session, sink } = harness(['--hang-initialize'], 1_000);
    session.send('stop');
    session.dispose(true);
    await vi.waitFor(() => expect(sink.exited).toHaveBeenCalledTimes(1), { timeout: 2_000 });
    await new Promise((resolve) => setTimeout(resolve, 1_100));
    expect(sink.exited).toHaveBeenCalledTimes(1);
  });
  it.skipIf(process.platform === 'win32')('hard-stops a provider that ignores SIGTERM', async () => {
    const { session, sink } = harness();
    session.send('hold');
    await vi.waitFor(() => expect(sink.session).toHaveBeenCalled());
    session.dispose(true);
    await vi.waitFor(
      () => expect(sink.exited).toHaveBeenCalledWith(expect.objectContaining({ signal: 'SIGKILL', expected: true })),
      { timeout: 3000 },
    );
  });
});

function isProcessRunning(pid: number): boolean {
  try {
    const stat = fs.readFileSync(`/proc/${pid}/stat`, 'utf8');
    const state = stat.slice(stat.lastIndexOf(')') + 2, stat.lastIndexOf(')') + 3);
    return state !== 'Z';
  } catch {
    try {
      process.kill(pid, 0);
      return true;
    } catch {
      return false;
    }
  }
}
