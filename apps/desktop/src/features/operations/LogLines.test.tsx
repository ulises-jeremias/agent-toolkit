import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { LogLines } from './LogLines';

describe('LogLines', () => {
  afterEach(() => {
    vi.restoreAllMocks();
    // @ts-expect-error test cleanup: drop the stubbed clipboard
    delete navigator.clipboard;
  });

  it('renders every line with its own copy action', () => {
    render(<LogLines lines={['[running]', 'listening on http://127.0.0.1:39173/', '[canceled]']} label="Job log" />);
    expect(screen.getByText('listening on http://127.0.0.1:39173/')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Copy log line 1' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Copy log line 3' })).toBeInTheDocument();
  });

  it('copies exactly the clicked line and confirms it', async () => {
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true });
    render(<LogLines lines={['first line', 'second line']} label="Job log" />);
    await userEvent.click(screen.getByRole('button', { name: 'Copy log line 2' }));
    expect(writeText).toHaveBeenCalledTimes(1);
    expect(writeText).toHaveBeenCalledWith('second line');
    expect(screen.getByRole('status')).toHaveTextContent('Line 2 copied to clipboard.');
  });

  it('reports a manual-copy fallback when the clipboard rejects', async () => {
    const writeText = vi.fn().mockRejectedValue(new Error('denied'));
    Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true });
    render(<LogLines lines={['only line']} label="Job log" />);
    await userEvent.click(screen.getByRole('button', { name: 'Copy log line 1' }));
    expect(screen.getByText(/Could not copy the line/)).toBeInTheDocument();
    expect(screen.queryByRole('status')).not.toBeInTheDocument();
  });
});
