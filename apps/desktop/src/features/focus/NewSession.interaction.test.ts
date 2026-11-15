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
  it('announces provider discovery while the first agent check is pending', () => {
    render(
      createElement(NewSession, {
        workspace: '/ws',
        projects: [],
        projectsLoading: true,
        providers: [],
        providersLoading: true,
        onRefreshProviders: vi.fn(),
        onStarted: vi.fn(),
      }),
    );

    expect(screen.getByRole('status')).toHaveTextContent('Checking installed agents…');
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

  it('requires an explicit confirmation before starting a session without permission prompts', async () => {
    const createThread = vi.fn(async () => ({ ok: true as const, value: created }));
    const send = vi.fn(async () => ({ ok: true as const, value: true as const }));
    window.atk = { focus: { createThread, send } as unknown as FocusBridge } as AtkBridge;
    const user = userEvent.setup();

    render(
      createElement(NewSession, {
        workspace: '/ws',
        projects: [{ name: 'demo', target: '/ws/demo', status: 'ok' }],
        projectsLoading: false,
        providers: [provider],
        providersLoading: false,
        onRefreshProviders: vi.fn(),
        onStarted: vi.fn(),
      }),
    );

    await user.type(screen.getByLabelText('Task'), 'Update this project');
    const permissions = screen.getByLabelText('Permissions');
    await user.selectOptions(permissions, 'bypass');

    const confirmation = screen.getByRole('dialog', { name: 'Enable unrestricted access?' });
    expect(confirmation).toHaveTextContent('does not enforce an operating-system sandbox');
    expect(createThread).not.toHaveBeenCalled();
    await user.click(screen.getByRole('button', { name: 'Keep current permissions' }));
    expect(permissions).toHaveValue('ask');

    await user.selectOptions(permissions, 'bypass');
    await user.click(screen.getByRole('button', { name: 'Enable without asking' }));
    expect(permissions).toHaveValue('bypass');
    await user.click(screen.getByRole('button', { name: 'Start session' }));

    await waitFor(() =>
      expect(createThread).toHaveBeenCalledWith(expect.objectContaining({ permissionMode: 'bypass' })),
    );
    expect(send).toHaveBeenCalledOnce();
  });

  it('invalidates unrestricted consent when the selected repository changes', async () => {
    const createThread = vi.fn(async () => ({ ok: true as const, value: created }));
    const send = vi.fn(async () => ({ ok: true as const, value: true as const }));
    window.atk = { focus: { createThread, send } as unknown as FocusBridge } as AtkBridge;
    const user = userEvent.setup();
    render(
      createElement(NewSession, {
        workspace: '/ws',
        projects: [
          { name: 'demo', target: '/ws/demo', status: 'ok' },
          { name: 'other', target: '/ws/other', status: 'ok' },
        ],
        projectsLoading: false,
        providers: [provider],
        providersLoading: false,
        onRefreshProviders: vi.fn(),
        onStarted: vi.fn(),
      }),
    );

    await user.selectOptions(screen.getByLabelText('Permissions'), 'bypass');
    expect(screen.getByRole('dialog', { name: 'Enable unrestricted access?' })).toBeVisible();
    await user.selectOptions(screen.getByLabelText('Project'), 'other');
    await waitFor(() =>
      expect(screen.queryByRole('dialog', { name: 'Enable unrestricted access?' })).not.toBeInTheDocument(),
    );
    expect(screen.getByLabelText('Permissions')).toHaveValue('ask');
    expect(createThread).not.toHaveBeenCalled();
    await user.selectOptions(screen.getByLabelText('Permissions'), 'bypass');
    expect(screen.getByRole('dialog', { name: 'Enable unrestricted access?' })).toHaveTextContent('/ws/other');
  });

  it('revokes an already confirmed bypass when switching project or provider', async () => {
    const createThread = vi.fn(async () => ({ ok: true as const, value: created }));
    const send = vi.fn(async () => ({ ok: true as const, value: true as const }));
    window.atk = { focus: { createThread, send } as unknown as FocusBridge } as AtkBridge;
    const user = userEvent.setup();
    const codex: FocusProviderStatus = { ...provider, id: 'codex', label: 'Codex' };
    render(
      createElement(NewSession, {
        workspace: '/ws',
        projects: [
          { name: 'demo', target: '/ws/demo', status: 'ok' },
          { name: 'other', target: '/ws/other', status: 'ok' },
        ],
        projectsLoading: false,
        providers: [provider, codex],
        providersLoading: false,
        onRefreshProviders: vi.fn(),
        onStarted: vi.fn(),
      }),
    );
    await user.type(screen.getByLabelText('Task'), 'Check the project');
    await user.selectOptions(screen.getByLabelText('Permissions'), 'bypass');
    await user.click(screen.getByRole('button', { name: 'Enable without asking' }));
    expect(screen.getByLabelText('Permissions')).toHaveValue('bypass');

    await user.selectOptions(screen.getByLabelText('Project'), 'other');
    expect(screen.getByLabelText('Permissions')).toHaveValue('ask');
    await user.selectOptions(screen.getByLabelText('Permissions'), 'bypass');
    await user.click(screen.getByRole('button', { name: 'Enable without asking' }));
    expect(screen.getByLabelText('Permissions')).toHaveValue('bypass');

    await user.click(screen.getByRole('radio', { name: /Codex/ }));
    expect(screen.getByLabelText('Permissions')).toHaveValue('ask');
    await user.click(screen.getByRole('button', { name: 'Start session' }));
    await waitFor(() =>
      expect(createThread).toHaveBeenCalledWith(
        expect.objectContaining({ cwd: '/ws/other', provider: 'codex', permissionMode: 'ask' }),
      ),
    );
    expect(send).toHaveBeenCalledOnce();
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
