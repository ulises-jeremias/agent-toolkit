import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import type { ToolInfo } from '../../lib/api';
import { ReceiptsProvider } from '../../ui';
import { ToolRecordInspector } from './ToolRecordInspector';

const fixture: ToolInfo = {
  id: 'claude',
  tool_name: 'Claude Code',
  detected: true,
  configured: true,
  enabled: 'unknown',
  verified: false,
  resolved_path: '/usr/bin/claude',
  config_paths: [],
  version: '1.0.0',
  reason: '',
  install_hint: 'agent-toolkit install',
};

describe('ToolRecordInspector', () => {
  it('renders only catalog fields and keeps enabled unknown as unknown', () => {
    render(
      <ReceiptsProvider>
        <ToolRecordInspector toolId="claude" tool={fixture} onBack={() => undefined} onInstall={() => undefined} />
      </ReceiptsProvider>,
    );

    expect(screen.getByRole('region', { name: /Coding tool claude/i })).toBeInTheDocument();
    expect(screen.getAllByText('claude').length).toBeGreaterThan(0);
    expect(screen.getByText('unknown')).toBeInTheDocument();
    expect(screen.getAllByText('yes').length).toBeGreaterThanOrEqual(1);
    expect(screen.getByText('agent-toolkit install')).toBeInTheDocument();
    // Extra catalog fields exist on ToolInfo but must not invent metrics UI here.
    expect(screen.queryByText('/usr/bin/claude')).not.toBeInTheDocument();
    expect(screen.queryByText('1.0.0')).not.toBeInTheDocument();
  });

  it('shows an Install button that calls the real install handler when install_hint is set', async () => {
    const onInstall = vi.fn();
    const user = userEvent.setup();
    render(
      <ReceiptsProvider>
        <ToolRecordInspector toolId="claude" tool={fixture} onBack={() => undefined} onInstall={onInstall} />
      </ReceiptsProvider>,
    );

    await user.click(screen.getByRole('button', { name: 'Install profiles' }));
    await user.click(screen.getByRole('button', { name: 'Install' }));
    expect(onInstall).toHaveBeenCalledTimes(1);
  });

  it('shows install_hint as text only when no install API handler is provided', () => {
    render(
      <ReceiptsProvider>
        <ToolRecordInspector toolId="claude" tool={fixture} onBack={() => undefined} />
      </ReceiptsProvider>,
    );
    expect(screen.getByText(/Install hint is text only/i)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Install profiles' })).not.toBeInTheDocument();
  });

  it('hides install UI when install_hint is empty', () => {
    render(
      <ReceiptsProvider>
        <ToolRecordInspector
          toolId="claude"
          tool={{ ...fixture, install_hint: '' }}
          onBack={() => undefined}
          onInstall={() => undefined}
        />
      </ReceiptsProvider>,
    );
    expect(screen.queryByRole('button', { name: 'Install profiles' })).not.toBeInTheDocument();
    expect(screen.queryByText(/Install hint is text only/i)).not.toBeInTheDocument();
  });
});
