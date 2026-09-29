import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { ConfirmButton, Panel } from './ui';

describe('Panel', () => {
  it('renders title and children with an accessible label', () => {
    render(
      <Panel title="Jobs">
        <p>content</p>
      </Panel>,
    );
    expect(screen.getByRole('region', { name: 'Jobs' })).toBeInTheDocument();
    expect(screen.getByText('content')).toBeInTheDocument();
  });
});

describe('ConfirmButton', () => {
  it('requires two clicks before confirming', async () => {
    const user = userEvent.setup();
    let confirmed = 0;
    render(
      <ConfirmButton
        label="Uninstall"
        confirmLabel="Confirm uninstall"
        onConfirm={() => {
          confirmed += 1;
        }}
      />,
    );
    await user.click(screen.getByRole('button', { name: 'Uninstall' }));
    expect(confirmed).toBe(0);
    await user.click(screen.getByRole('button', { name: 'Confirm uninstall' }));
    expect(confirmed).toBe(1);
  });
});
