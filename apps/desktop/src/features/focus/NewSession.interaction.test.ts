import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { createElement } from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { FocusBridge, FocusProviderStatus, FocusThread } from '../../types/focus';
import type { AtkBridge } from '../../types/electron';
import { NewSession } from './NewSession';

vi.mock('../../data/projects', () => ({
  useLinkProject: () => ({ mutate: vi.fn(), isPending: false, error: null }),
}));

const provider: FocusProviderStatus = {
  id: 'claude',
  label: 'Claude Code',
  installed: true,
  binary: '/usr/bin/claude',
  version: '1.0',
  auth: 'ready',
  authDetail: 'Signed in',
  signInHint: null,
  models: [],
  capabilities: { sessions: true, approvals: true, interrupt: true, resume: true, modelSwitch: true },
  checkedAt: '2026-11-12T00:00:00.000Z',
};

const created: FocusThread = {
  id: 'th_test000001',
  title: 'Fix the test',
  workspace: '/ws',
  projectName: 'demo',
  cwd: '/ws/demo',
  provider: 'claude',
  model: null,
  resolvedModel: null,
  permissionMode: 'ask',
  providerSessionId: null,
  status: 'idle',
  createdAt: '2026-11-12T00:00:00.000Z',
  updatedAt: '2026-11-12T00:00:00.000Z',
  turns: 0,
  lastError: null,
  usage: { inputTokens: 0, cachedInputTokens: 0, outputTokens: 0, costUsd: null },
};

afterEach(() => {
  delete window.atk;
  vi.clearAllMocks();
});

describe('NewSession', () => {
  it('creates only one session when keyboard and pointer submissions overlap', async () => {
    let finishCreate: ((result: Awaited<ReturnType<FocusBridge['createThread']>>) => void) | undefined;
    const createThread = vi.fn(
      () => new Promise<Awaited<ReturnType<FocusBridge['createThread']>>>((resolve) => (finishCreate = resolve)),
    );
    const send = vi.fn(async () => ({ ok: true as const, value: true as const }));
    window.atk = { focus: { createThread, send } as unknown as FocusBridge } as AtkBridge;
    const onStarted = vi.fn();
    const user = userEvent.setup();

    render(
      createElement(NewSession, {
        workspace: '/ws',
        projects: [{ name: 'demo', target: '/ws/demo', status: 'ok' }],
        projectsLoading: false,
        providers: [provider],
        providersLoading: false,
        onRefreshProviders: vi.fn(),
        onStarted,
      }),
    );

    const task = screen.getByLabelText('Task');
    await user.type(task, 'Fix the test');
    fireEvent.keyDown(task, { key: 'Enter', ctrlKey: true });
    fireEvent.keyDown(task, { key: 'Enter', ctrlKey: true });

    expect(createThread).toHaveBeenCalledTimes(1);
    finishCreate?.({ ok: true, value: created });
    await waitFor(() => expect(send).toHaveBeenCalledOnce());
    expect(onStarted).toHaveBeenCalledWith(created.id);
  });
});
