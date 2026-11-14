// @vitest-environment node
import path from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { AdapterSink } from './adapter';
import { OpenCodeSession } from './opencode';

const sessions: OpenCodeSession[] = [];

function harness(resumeSessionId: string | null = null) {
  const approval = vi.fn<AdapterSink['approval']>();
  const userInput = vi.fn<AdapterSink['userInput']>();
  const turnFinished = vi.fn<AdapterSink['turnFinished']>();
  const sink = {
    session: vi.fn<AdapterSink['session']>(),
    models: vi.fn<AdapterSink['models']>(),
    delta: vi.fn<AdapterSink['delta']>(),
    item: vi.fn<AdapterSink['item']>(),
    approval,
    approvalCancelled: vi.fn<AdapterSink['approvalCancelled']>(),
    userInput,
    userInputCancelled: vi.fn<AdapterSink['userInputCancelled']>(),
    turnFinished,
    exited: vi.fn<AdapterSink['exited']>(),
  } satisfies AdapterSink;
  const session = new OpenCodeSession(
    {
      binary: process.execPath,
      cwd: process.cwd(),
      env: process.env,
      model: 'test/provider-model',
      permissionMode: 'ask',
      resumeSessionId,
    },
    sink,
    [path.join(__dirname, 'testing/fake-opencode.mjs')],
  );
  sessions.push(session);
  return { session, sink, approval, userInput, turnFinished };
}

afterEach(() => {
  for (const session of sessions.splice(0)) session.dispose(true);
});

describe('OpenCode ACP protocol', () => {
  it('starts an ACP session, selects the requested model and streams a completed turn', async () => {
    const { session, sink } = harness();
    session.send('hello');
    await vi.waitFor(() => expect(sink.turnFinished).toHaveBeenCalledTimes(1));
    expect(sink.session).toHaveBeenCalledWith('ses_fake_focus_1', 'test/provider-model');
    expect(sink.delta).toHaveBeenCalledWith(expect.any(String), 'assistant', 'ACP_OK');
    expect(sink.item).toHaveBeenCalledWith({ type: 'assistant', itemId: expect.any(String), text: 'ACP_OK' });
    expect(sink.turnFinished).toHaveBeenCalledWith(
      expect.objectContaining({
        outcome: 'completed',
        usage: { inputTokens: 3, cachedInputTokens: 0, outputTokens: 2, costUsd: null },
      }),
    );
  });

  it('maps only one-shot approval choices and records the actual tool result', async () => {
    const { session, sink, approval } = harness();
    session.send('approval');
    await vi.waitFor(() => expect(approval).toHaveBeenCalledTimes(1));
    const [request] = approval.mock.calls[0] ?? [];
    expect(request).toMatchObject({ kind: 'command', title: 'touch result.txt', canAllowForSession: false });
    expect(session.respondApproval(request?.requestId ?? '', 'allow-session')).toBe(false);
    expect(session.respondApproval(request?.requestId ?? '', 'allow')).toBe(true);
    await vi.waitFor(() => expect(sink.turnFinished).toHaveBeenCalledTimes(1));
    expect(sink.item).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'tool.started',
        itemId: 'tool-write-1',
        kind: 'command',
        title: 'touch result.txt',
      }),
    );
    expect(sink.item).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'tool.finished',
        itemId: 'tool-write-1',
        ok: true,
        output: expect.stringContaining('Created result.txt'),
      }),
    );
  });

  it('answers non-secret forms without adding answers to Focus events', async () => {
    const { session, sink, userInput } = harness();
    session.send('question');
    await vi.waitFor(() => expect(userInput).toHaveBeenCalledTimes(1));
    const [requestId, questions] = userInput.mock.calls[0] ?? [];
    expect(questions).toEqual([
      expect.objectContaining({
        id: 'color',
        header: 'Color',
        isSecret: false,
        isOther: true,
        options: [
          { label: 'Blue', description: '' },
          { label: 'Red', description: '' },
        ],
      }),
    ]);
    expect(session.respondUserInput(requestId ?? '', { color: ['Blue'] })).toBe(true);
    await vi.waitFor(() => expect(sink.turnFinished).toHaveBeenCalledTimes(1));
    expect(JSON.stringify(userInput.mock.calls)).not.toContain('private token');
  });

  it('cancels ACP forms that request credentials or other sensitive values', async () => {
    const { session, sink, userInput } = harness();
    session.send('secret-question');
    await vi.waitFor(() => expect(sink.turnFinished).toHaveBeenCalledTimes(1));
    expect(userInput).not.toHaveBeenCalled();
    expect(sink.item).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'notice',
        level: 'warning',
        text: expect.stringContaining('sensitive information'),
      }),
    );
  });

  it('cancels a running ACP prompt and reports interruption', async () => {
    const { session, sink } = harness();
    session.send('hold');
    await vi.waitFor(() => expect(sink.session).toHaveBeenCalled());
    session.interrupt();
    await vi.waitFor(() =>
      expect(sink.turnFinished).toHaveBeenCalledWith(expect.objectContaining({ outcome: 'interrupted' })),
    );
  });

  it('drains queued prompts once and in order after interruption', async () => {
    const { session, sink } = harness();
    session.send('hold');
    await vi.waitFor(() => expect(sink.session).toHaveBeenCalled());
    session.send('queued one');
    session.send('queued two');
    session.interrupt();
    await vi.waitFor(() => expect(sink.turnFinished).toHaveBeenCalledTimes(3));
    await new Promise((resolve) => setTimeout(resolve, 50));

    expect(sink.delta.mock.calls.map(([, kind, delta]) => [kind, delta])).toEqual([
      ['assistant', 'QUEUED_ONE'],
      ['assistant', 'QUEUED_TWO'],
    ]);
    expect(sink.turnFinished.mock.calls.map(([result]) => result?.outcome)).toEqual([
      'interrupted',
      'completed',
      'completed',
    ]);
  });

  it('reports queued turns as failed when the provider exits during an active turn', async () => {
    const { session, sink } = harness();
    session.send('hold');
    await vi.waitFor(() => expect(sink.session).toHaveBeenCalled());
    session.send('queued one');
    session.send('queued two');
    session.dispose(true);
    await vi.waitFor(() => expect(sink.turnFinished).toHaveBeenCalledTimes(3));
    expect(sink.turnFinished.mock.calls.map(([result]) => result?.outcome)).toEqual(['failed', 'failed', 'failed']);
  });

  it('redacts provider billing URLs and account references from turn errors', async () => {
    const { session, turnFinished } = harness();
    session.send('failure');
    await vi.waitFor(() => expect(turnFinished).toHaveBeenCalledTimes(1));
    const [result] = turnFinished.mock.calls[0] ?? [];
    const detail = JSON.stringify(result);
    expect(detail).toContain('Insufficient balance');
    expect(detail).not.toContain('provider.example');
    expect(detail).not.toContain('work_12345678901234567890');
  });

  it('loads the saved OpenCode session when resuming', async () => {
    const { session, sink } = harness('ses_fake_focus_2');
    session.send('hello');
    await vi.waitFor(() => expect(sink.turnFinished).toHaveBeenCalledTimes(1));
    expect(sink.session).toHaveBeenCalledWith('ses_fake_focus_2', 'test/provider-model');
  });
});
