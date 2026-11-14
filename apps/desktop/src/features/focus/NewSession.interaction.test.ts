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

vi.mock('./ProviderSignInDialog', () => ({
  ProviderSignInDialog: ({
    session,
    onClose,
  }: {
    session: { sessionId: string } | null;
    onClose: (session: { sessionId: string } | null) => void;
  }) =>
    session
      ? createElement('button', { type: 'button', onClick: () => onClose(session) }, 'Close temporary sign-in')
      : null,
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
  it('launches a fixed provider sign-in and refreshes actual account status when it closes', async () => {
    const providerSignInStart = vi.fn(async () => ({
      ok: true as const,
      sessionId: 'temporary-1',
    }));
    const providerSignInFinish = vi.fn(async () => true);
    window.atk = { focus: {} as FocusBridge, providerSignInStart, providerSignInFinish } as unknown as AtkBridge;
    const onRefreshProviders = vi.fn();
    const user = userEvent.setup();

    render(
      createElement(NewSession, {
        workspace: '/ws',
        projects: [{ name: 'demo', target: '/ws/demo', status: 'ok' }],
        projectsLoading: false,
        providers: [{ ...provider, auth: 'signed-out', authDetail: 'Not signed in' }],
        providersLoading: false,
        onRefreshProviders,
        onStarted: vi.fn(),
      }),
    );

    await user.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(providerSignInStart).toHaveBeenCalledWith('claude');
    await user.click(await screen.findByRole('button', { name: 'Close temporary sign-in' }));
    await waitFor(() => expect(providerSignInFinish).toHaveBeenCalledWith('temporary-1'));
    expect(onRefreshProviders).toHaveBeenCalledOnce();
  });

  it('explains the sign-in blocker beside the provider choices and disabled start action', () => {
    window.atk = { focus: {} as FocusBridge } as AtkBridge;
    const signedOut = {
      ...provider,
      auth: 'signed-out' as const,
      authDetail: 'Not signed in',
      signInHint: 'claude auth login',
    };

    render(
      createElement(NewSession, {
        workspace: '/ws',
        projects: [{ name: 'demo', target: '/ws/demo', status: 'ok' }],
        projectsLoading: false,
        providers: [signedOut],
        providersLoading: false,
        onRefreshProviders: vi.fn(),
        onStarted: vi.fn(),
      }),
    );

    expect(screen.getByRole('status')).toHaveTextContent('No coding agent is signed in');
    expect(screen.getByText(/claude auth login/)).toBeVisible();
    expect(screen.getByRole('button', { name: 'Start session' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Start session' })).toHaveAttribute(
      'aria-describedby',
      'focus-start-hint',
    );
    expect(screen.getByText('Sign in to an agent to start')).toBeVisible();
  });

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

  it('keeps an unavailable explicit project blocked instead of substituting another repository', async () => {
    const createThread = vi.fn();
    const send = vi.fn();
    window.atk = { focus: { createThread, send } as unknown as FocusBridge } as AtkBridge;
    const onStarted = vi.fn();
    const user = userEvent.setup();

    render(
      createElement(NewSession, {
        workspace: '/ws',
        projects: [{ name: 'available', target: '/ws/available', status: 'ok' }],
        projectsLoading: false,
        providers: [provider],
        providersLoading: false,
        onRefreshProviders: vi.fn(),
        defaults: { project: 'deleted-project' },
        onStarted,
      }),
    );

    await user.type(screen.getByLabelText('Task'), 'Inspect this project safely');
    expect(screen.getByRole('alert')).toHaveTextContent('selected repository is unavailable');
    expect(screen.getByRole('button', { name: 'Start session' })).toBeDisabled();
    expect(createThread).not.toHaveBeenCalled();
    expect(send).not.toHaveBeenCalled();
    expect(onStarted).not.toHaveBeenCalled();
  });

  it('retains the task and project when provider dispatch returns an error', async () => {
    const createThread = vi.fn(async () => ({ ok: true as const, value: created }));
    const send = vi.fn(async () => ({ ok: false as const, error: 'Provider rejected the task.' }));
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
    await user.type(task, 'Keep this task after an error');
    await user.click(screen.getByRole('button', { name: 'Start session' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('Provider rejected the task.');
    expect(task).toHaveValue('Keep this task after an error');
    expect(screen.getByLabelText('Project')).toHaveValue('demo');
    expect(createThread).toHaveBeenCalledOnce();
    expect(send).toHaveBeenCalledWith(created.id, 'Keep this task after an error');
    expect(onStarted).not.toHaveBeenCalled();
  });

  it('shows thrown IPC errors without clearing the task or leaving the composer', async () => {
    const createThread = vi.fn(async () => {
      throw new Error('Desktop bridge disconnected.');
    });
    const send = vi.fn();
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
    await user.type(task, 'Keep this task after disconnect');
    await user.click(screen.getByRole('button', { name: 'Start session' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('Desktop bridge disconnected.');
    expect(task).toHaveValue('Keep this task after disconnect');
    expect(createThread).toHaveBeenCalledOnce();
    expect(send).not.toHaveBeenCalled();
    expect(onStarted).not.toHaveBeenCalled();
  });
});
