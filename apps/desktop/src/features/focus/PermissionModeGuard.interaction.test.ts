import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { createElement } from 'react';
import { describe, expect, it, vi } from 'vitest';
import type { FocusPermissionMode } from '../../types/focus';
import { usePermissionModeGuard } from './PermissionModeGuard';

interface Context {
  current: FocusPermissionMode;
  provider: string;
  cwd: string;
  thread: string;
  apply: (mode: FocusPermissionMode) => void;
}

function GuardHarness({ current, provider, cwd, thread, apply }: Context) {
  const guard = usePermissionModeGuard(current, provider, cwd, thread, apply);
  return createElement(
    'div',
    null,
    createElement('button', { onClick: () => guard.choose('bypass') }, 'Request unrestricted'),
    guard.dialog,
  );
}

describe('active Focus permission consent', () => {
  it.each([
    ['provider', { provider: 'Codex' }],
    ['project directory', { cwd: '/ws/other' }],
    ['thread identity', { thread: 'thread-b' }],
  ] as const)('invalidates pending consent when %s changes', async (_label, change) => {
    const user = userEvent.setup();
    const apply = vi.fn();
    const initial: Context = {
      current: 'ask',
      provider: 'Claude Code',
      cwd: '/ws/demo',
      thread: 'thread-a',
      apply,
    };
    const view = render(createElement(GuardHarness, initial));
    await user.click(screen.getByRole('button', { name: 'Request unrestricted' }));
    expect(screen.getByRole('dialog', { name: 'Enable unrestricted access?' })).toBeVisible();

    view.rerender(createElement(GuardHarness, { ...initial, ...change }));
    await waitFor(() =>
      expect(screen.queryByRole('dialog', { name: 'Enable unrestricted access?' })).not.toBeInTheDocument(),
    );
    expect(apply).not.toHaveBeenCalled();

    await user.click(screen.getByRole('button', { name: 'Request unrestricted' }));
    const dialog = screen.getByRole('dialog', { name: 'Enable unrestricted access?' });
    expect(dialog).toBeVisible();
    await user.click(screen.getByRole('button', { name: 'Enable without asking' }));
    expect(apply).toHaveBeenCalledExactlyOnceWith('bypass');
  });

  it('does not grant unrestricted access when the user dismisses the confirmation', async () => {
    const user = userEvent.setup();
    const apply = vi.fn();
    render(
      createElement(GuardHarness, {
        current: 'ask',
        provider: 'Claude Code',
        cwd: '/ws/demo',
        thread: 'thread-a',
        apply,
      }),
    );
    await user.click(screen.getByRole('button', { name: 'Request unrestricted' }));
    await user.click(screen.getByRole('button', { name: 'Keep current permissions' }));
    expect(apply).not.toHaveBeenCalled();
    expect(screen.queryByRole('dialog', { name: 'Enable unrestricted access?' })).not.toBeInTheDocument();
  });
});
