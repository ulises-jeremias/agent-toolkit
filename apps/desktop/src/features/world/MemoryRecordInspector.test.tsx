import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import type { MemoryReadResponse } from '../../lib/api';
import { MemoryRecordInspector } from './MemoryRecordInspector';

const fixture: MemoryReadResponse = {
  ok: true,
  entry: {
    id: 'knowledge/learnings/fixture.md',
    kind: 'learning',
    title: 'Fixture note',
    snippet: 'Short snippet',
    body: 'Full body from GET /api/v1/memory/file',
    tags: ['desk'],
    provenance: {
      file: 'knowledge/learnings/fixture.md',
      author: 'tester',
      timestamp: '2026-09-30T12:00:00Z',
      project: 'alpha',
      agent: 'desktop',
    },
  },
};

describe('MemoryRecordInspector', () => {
  it('renders provenance and body from a fixture memory-file payload', () => {
    render(<MemoryRecordInspector path={fixture.entry.provenance.file} data={fixture} onBack={() => undefined} />);

    expect(screen.getByRole('region', { name: /Memory record knowledge\/learnings\/fixture.md/i })).toBeInTheDocument();
    expect(screen.getByText('Fixture note')).toBeInTheDocument();
    expect(screen.getByText('learning')).toBeInTheDocument();
    expect(screen.getByText('tester')).toBeInTheDocument();
    expect(screen.getByText('alpha')).toBeInTheDocument();
    expect(screen.getByLabelText('Memory body')).toHaveTextContent('Full body from GET /api/v1/memory/file');
  });

  it('keeps an empty body empty and prefers snippet when body is blank', () => {
    const emptyBody: MemoryReadResponse = {
      ok: true,
      entry: { ...fixture.entry, body: '', snippet: 'Only snippet' },
    };
    const { rerender } = render(
      <MemoryRecordInspector path={emptyBody.entry.id} data={emptyBody} onBack={() => undefined} />,
    );
    expect(screen.getByLabelText('Memory snippet')).toHaveTextContent('Only snippet');

    rerender(
      <MemoryRecordInspector
        path={emptyBody.entry.id}
        data={{ ok: true, entry: { ...fixture.entry, body: '', snippet: '' } }}
        onBack={() => undefined}
      />,
    );
    expect(screen.getByLabelText('Memory body')).toHaveTextContent('Body is empty.');
  });

  it('shows an honest error when the read fails', () => {
    render(
      <MemoryRecordInspector
        path="knowledge/learnings/missing.md"
        error={new Error('memory file not found')}
        onBack={() => undefined}
      />,
    );
    expect(screen.getByRole('alert')).toHaveTextContent('memory file not found');
  });

  it('Back dismisses the inspector', async () => {
    const onBack = vi.fn();
    const user = userEvent.setup();
    render(<MemoryRecordInspector path={fixture.entry.id} data={fixture} onBack={onBack} />);
    await user.click(screen.getByRole('button', { name: 'Back' }));
    expect(onBack).toHaveBeenCalledTimes(1);
  });
});
