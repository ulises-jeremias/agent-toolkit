import { act, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from '../lib/api';
import {
  Button,
  CommandReport,
  ConfirmAction,
  Dialog,
  ErrorState,
  Field,
  Panel,
  ReceiptsProvider,
  StatusBadge,
  TextInput,
  useReceipts,
} from './index';
import { RECEIPT_DISMISS_MS } from './receipts';

describe('Panel', () => {
  it('is a region named by its heading', () => {
    render(
      <Panel title="Jobs">
        <p>content</p>
      </Panel>,
    );
    expect(screen.getByRole('region', { name: 'Jobs' })).toBeInTheDocument();
    expect(screen.getByRole('heading', { level: 2, name: 'Jobs' })).toBeInTheDocument();
  });
});

describe('StatusBadge', () => {
  it('always states the status in words', () => {
    render(<StatusBadge tone="err" label="failed" />);
    expect(screen.getByText('failed')).toHaveAttribute('data-tone', 'err');
  });
});

describe('Field', () => {
  it('wires label, hint and error to the control', () => {
    render(
      <Field label="Command" hint="A subcommand" error="Required">
        {(control) => <TextInput {...control} />}
      </Field>,
    );
    const input = screen.getByLabelText('Command');
    expect(input).toHaveAttribute('aria-invalid', 'true');
    expect(input).toHaveAccessibleDescription('A subcommand Required');
  });
});

describe('ErrorState', () => {
  it('shows the server message and a plain-language next step', () => {
    render(<ErrorState error={new ApiError('network', 0, 'backend unreachable')} onRetry={() => undefined} />);
    expect(screen.getByRole('alert')).toHaveTextContent('backend unreachable');
    expect(screen.getByRole('alert')).toHaveTextContent('restart it from Settings');
    expect(screen.getByRole('button', { name: 'Try again' })).toBeInTheDocument();
  });
});

describe('CommandReport', () => {
  it('shows output verbatim, drops raw-payload duplicates, and flags failures', () => {
    render(
      <CommandReport
        label="Doctor"
        envelope={{ ok: false, message: 'line one\nline two', data: { JSON: '{}', errors: '2' } }}
        failureLabel="Checks failing"
      />,
    );
    expect(screen.getByLabelText('Doctor')).toHaveTextContent('line one line two');
    expect(screen.getByText('Checks failing')).toBeInTheDocument();
    expect(screen.getByText('errors')).toBeInTheDocument();
    expect(screen.queryByText('JSON')).not.toBeInTheDocument();
  });
});

describe('Dialog', () => {
  function Harness() {
    const [open, setOpen] = useState(false);
    return (
      <>
        <Button onClick={() => setOpen(true)}>Open</Button>
        <Dialog
          open={open}
          onClose={() => setOpen(false)}
          title="Start a job"
          footer={<Button onClick={() => setOpen(false)}>Done</Button>}
        >
          <p>body</p>
        </Dialog>
      </>
    );
  }

  it('opens as a labelled modal and returns focus to the trigger on close', async () => {
    const user = userEvent.setup();
    render(<Harness />);
    const trigger = screen.getByRole('button', { name: 'Open' });
    await user.click(trigger);
    expect(screen.getByRole('dialog', { name: 'Start a job' })).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Done' }));
    expect(screen.queryByText('body')).not.toBeInTheDocument();
    expect(trigger).toHaveFocus();
  });
});

describe('ConfirmAction', () => {
  it('acts only after an explicit confirm, with cancel focused first', async () => {
    const user = userEvent.setup();
    const onConfirm = vi.fn();
    render(
      <ConfirmAction
        label="Uninstall profiles"
        title="Uninstall tool profiles?"
        description="Removes managed files."
        confirmLabel="Uninstall"
        onConfirm={onConfirm}
      />,
    );
    await user.click(screen.getByRole('button', { name: 'Uninstall profiles' }));
    expect(onConfirm).not.toHaveBeenCalled();
    expect(screen.getByRole('button', { name: 'Cancel' })).toHaveFocus();
    await user.click(screen.getByRole('button', { name: 'Uninstall' }));
    expect(onConfirm).toHaveBeenCalledTimes(1);
  });
});

describe('receipts', () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  function Pusher({ tone }: { tone: 'ok' | 'err' }) {
    const { push, history } = useReceipts();
    return (
      <>
        <button type="button" onClick={() => push({ tone, title: `Receipt ${tone}` })}>
          push
        </button>
        <output>{history.length}</output>
      </>
    );
  }

  it('auto-dismisses successes but keeps them in the session history', () => {
    vi.useFakeTimers();
    render(
      <ReceiptsProvider>
        <Pusher tone="ok" />
      </ReceiptsProvider>,
    );
    act(() => screen.getByRole('button', { name: 'push' }).click());
    expect(screen.getByText('Receipt ok')).toBeInTheDocument();
    act(() => vi.advanceTimersByTime(RECEIPT_DISMISS_MS + 10));
    expect(screen.queryByText('Receipt ok')).not.toBeInTheDocument();
    expect(screen.getByRole('status')).toHaveTextContent('1');
  });

  it('keeps failures on screen until dismissed', () => {
    vi.useFakeTimers();
    render(
      <ReceiptsProvider>
        <Pusher tone="err" />
      </ReceiptsProvider>,
    );
    act(() => screen.getByRole('button', { name: 'push' }).click());
    act(() => vi.advanceTimersByTime(RECEIPT_DISMISS_MS * 3));
    expect(screen.getByRole('alert')).toHaveTextContent('Receipt err');
    act(() => screen.getByRole('button', { name: 'Dismiss: Receipt err' }).click());
    expect(screen.queryByText('Receipt err')).not.toBeInTheDocument();
  });
});
