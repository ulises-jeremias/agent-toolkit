import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { FocusProvider, FocusStore } from '../../data/focus';
import type { AtkBridge } from '../../types/electron';
import type { FocusBridge, FocusEvent, FocusEventBody, FocusProviderStatus, FocusThread } from '../../types/focus';
import { Conversation } from './Conversation';

const thread = (patch: Partial<FocusThread> = {}): FocusThread => ({
  id: 'th_test000001',
  title: 'Fix add',
  workspace: '/ws',
  projectName: 'demo',
  cwd: '/ws/demo',
  provider: 'claude',
  model: null,
  resolvedModel: 'claude-haiku',
  permissionMode: 'ask',
  providerSessionId: 's1',
  status: 'idle',
  createdAt: '2026-11-12T00:00:00.000Z',
  updatedAt: '2026-11-12T00:00:00.000Z',
  turns: 1,
  lastError: null,
  usage: { inputTokens: 0, cachedInputTokens: 0, outputTokens: 0, costUsd: null },
  ...patch,
});

const provider = { id: 'claude', label: 'Claude Code' } as FocusProviderStatus;

function journal(bodies: FocusEventBody[]): FocusEvent[] {
  return bodies.map(
    (body, index) => ({ seq: index + 1, at: '2026-11-12T00:00:00.000Z', turn: 1, ...body }) as FocusEvent,
  );
}

function setup(current: FocusThread, events: FocusEvent[]) {
  const api = {
    listThreads: vi.fn(async () => [current]),
    readThread: vi.fn(async () => ({ thread: current, events })),
    send: vi.fn(async () => ({ ok: true as const, value: true as const })),
    respondApproval: vi.fn(async () => ({ ok: true as const, value: true as const })),
    respondUserInput: vi.fn(async () => ({ ok: true as const, value: true as const })),
    interrupt: vi.fn(async () => ({ ok: true as const, value: true as const })),
    onUpdate: vi.fn(() => () => undefined),
  };
  window.atk = { focus: api as unknown as FocusBridge } as AtkBridge;
  const onError = vi.fn();
  const store = new FocusStore(api as unknown as FocusBridge);
  const view = render(
    <FocusProvider store={store}>
      <Conversation thread={current} provider={provider} onError={onError} />
    </FocusProvider>,
  );
  return { api, onError, store, user: userEvent.setup(), ...view };
}

beforeEach(() => {
  Element.prototype.scrollBy ??= () => undefined;
});

afterEach(() => {
  delete window.atk;
});

describe('Conversation', () => {
  it('shows the journaled turn: message, tool, answer and how it ended', async () => {
    setup(
      thread(),
      journal([
        { type: 'user', text: 'fix add' },
        { type: 'turn.started', model: null },
        {
          type: 'tool.started',
          itemId: 't1',
          name: 'Edit',
          kind: 'edit',
          title: 'math.js',
          input: { old_string: 'a - b', new_string: 'a + b' },
          parentItemId: null,
        },
        { type: 'tool.finished', itemId: 't1', ok: true, output: 'updated', truncated: false },
        { type: 'assistant', itemId: 'a1', text: 'Fixed `add`.' },
        {
          type: 'turn.finished',
          outcome: 'completed',
          detail: null,
          durationMs: 9_000,
          usage: { inputTokens: 1, cachedInputTokens: 0, outputTokens: 1_100, costUsd: null },
        },
      ]),
    );
    expect(await screen.findByText('fix add')).toBeInTheDocument();
    const tool = screen.getByRole('button', { name: /Edited math\.js/ });
    expect(tool).toHaveAttribute('aria-expanded', 'false');
    expect(screen.getByText('add').tagName).toBe('CODE');
    expect(screen.getByText('Done in 9s, 1.1k tokens written')).toBeInTheDocument();

    await userEvent.click(tool);
    expect(tool).toHaveAttribute('aria-expanded', 'true');
    expect(screen.getByLabelText('Change preview')).toHaveTextContent('- a - b');
    expect(screen.getByLabelText('Change preview')).toHaveTextContent('+ a + b');
  });

  it('announces a pending approval without turning Enter into an allow decision', async () => {
    const { api, user } = setup(
      thread({ status: 'awaiting-approval' }),
      journal([
        { type: 'user', text: 'run tests' },
        { type: 'turn.started', model: null },
        {
          type: 'tool.started',
          itemId: 't1',
          name: 'Bash',
          kind: 'command',
          title: 'npm test',
          input: { command: 'npm test' },
          parentItemId: null,
        },
        {
          type: 'approval.requested',
          requestId: 'r1',
          itemId: 't1',
          tool: 'Bash',
          kind: 'command',
          title: 'npm test',
          input: { command: 'npm test' },
          canAllowForSession: true,
        },
      ]),
    );
    const dialog = await screen.findByRole('alertdialog', { name: 'Approval needed' });
    expect(dialog).toHaveTextContent('Claude Code wants to run a command');
    expect(screen.getByRole('button', { name: 'Allow once' })).not.toHaveFocus();
    expect(screen.getByLabelText('Message')).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Allow for this session' })).toBeInTheDocument();

    await user.keyboard('{Enter}');
    expect(api.respondApproval).not.toHaveBeenCalled();
    await user.click(screen.getByRole('button', { name: 'Allow once' }));
    expect(api.respondApproval).toHaveBeenCalledWith('th_test000001', 'r1', 'allow');
    await user.click(screen.getByRole('button', { name: 'Don’t allow' }));
    expect(api.respondApproval).toHaveBeenLastCalledWith('th_test000001', 'r1', 'deny');
  });

  it('collects Codex answers in a separate accessible form and keeps private values out of conversation state', async () => {
    const { api, user } = setup(
      thread({ provider: 'codex', status: 'awaiting-approval' }),
      journal([
        { type: 'user', text: 'choose a plan' },
        { type: 'turn.started', model: null },
        {
          type: 'userInput.requested',
          requestId: 'codex-q1',
          questions: [
            {
              id: 'plan',
              header: 'Plan',
              question: 'Choose a plan',
              isOther: false,
              isSecret: false,
              options: [{ label: 'Careful', description: 'Review each change' }],
            },
            {
              id: 'token',
              header: 'Token',
              question: 'Enter the token',
              isOther: false,
              isSecret: true,
              options: [],
            },
          ],
        },
      ]),
    );
    const dialog = await screen.findByRole('form', { name: 'Codex asks a question' });
    expect(dialog).toHaveTextContent('Choose a plan');
    await user.click(screen.getByRole('radio', { name: /Careful/ }));
    await user.type(screen.getByLabelText('Private answer'), 'do-not-store-this');
    await user.click(screen.getByRole('button', { name: 'Continue' }));
    await waitFor(() =>
      expect(api.respondUserInput).toHaveBeenCalledWith('th_test000001', 'codex-q1', {
        plan: ['Careful'],
        token: ['user_note: do-not-store-this'],
      }),
    );
    expect(dialog).not.toHaveTextContent('do-not-store-this');
  });

  it('sends on Enter, keeps Shift+Enter for a new line, and restores the draft if sending fails', async () => {
    const { api, user, onError } = setup(thread(), []);
    const box = await screen.findByLabelText('Message');
    await user.type(box, 'line one{Shift>}{Enter}{/Shift}line two');
    expect(box).toHaveValue('line one\nline two');
    api.send.mockResolvedValueOnce({ ok: false, error: 'Claude Code is not signed in.' } as never);
    await user.keyboard('{Enter}');
    await waitFor(() => expect(onError).toHaveBeenCalledWith('Claude Code is not signed in.'));
    expect(api.send).toHaveBeenCalledWith('th_test000001', 'line one\nline two');
    expect(box).toHaveValue('line one\nline two');
  });

  it('keeps unsent drafts scoped to their session while switching threads', async () => {
    const { store, user, rerender } = setup(thread(), []);
    const renderThread = (current: FocusThread) => (
      <FocusProvider store={store}>
        <Conversation thread={current} provider={provider} onError={vi.fn()} />
      </FocusProvider>
    );

    await user.type(await screen.findByLabelText('Message'), 'draft for first session');
    rerender(renderThread(thread({ id: 'th_second00002', title: 'Second session' })));
    await waitFor(() => expect(screen.getByLabelText('Message')).toHaveValue(''));
    await user.type(screen.getByLabelText('Message'), 'draft for second session');
    rerender(renderThread(thread()));
    await waitFor(() => expect(screen.getByLabelText('Message')).toHaveValue('draft for first session'));
    expect(store.getDraft('th_second00002')).toBe('draft for second session');
  });

  it('stops a running turn from the button and with Escape', async () => {
    const { api, user } = setup(
      thread({ status: 'running' }),
      journal([
        { type: 'user', text: 'go' },
        { type: 'turn.started', model: null },
      ]),
    );
    expect(await screen.findByRole('status')).toHaveTextContent('Claude Code is working');
    await user.click(screen.getByRole('button', { name: 'Stop' }));
    await user.click(screen.getByLabelText('Message'));
    await user.keyboard('{Escape}');
    expect(api.interrupt).toHaveBeenCalledTimes(2);
  });

  it('says plainly when a turn failed and why', async () => {
    setup(
      thread({ status: 'error' }),
      journal([
        { type: 'user', text: 'go' },
        { type: 'turn.started', model: null },
        {
          type: 'turn.finished',
          outcome: 'failed',
          detail: 'API Error: 529 overloaded',
          durationMs: null,
          usage: null,
        },
      ]),
    );
    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('This turn failed.');
    expect(alert).toHaveTextContent('API Error: 529 overloaded');
    expect(screen.queryByRole('button', { name: 'Stop' })).toBeNull();
  });
});
