import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { BurnDownChart } from './BurnDownChart';

describe('BurnDownChart', () => {
  it('summarizes recorded spend against the budget for assistive tech', () => {
    render(
      <BurnDownChart
        runs={[
          { id: 'run-1', tokens: 120 },
          { id: 'run-2', tokens: 30 },
        ]}
        maxTokens={1000}
      />,
    );
    expect(screen.getByRole('img', { name: /150 recorded, 850 left/ })).toBeInTheDocument();
    expect(screen.getByText(/Budget 1,000 tokens · 150 recorded across 2 runs/)).toBeInTheDocument();
  });

  it('announces an over-budget burn-down', () => {
    render(
      <BurnDownChart
        runs={[
          { id: 'run-1', tokens: 900 },
          { id: 'run-2', tokens: 250 },
        ]}
        maxTokens={1000}
      />,
    );
    expect(screen.getByRole('img', { name: /over budget/ })).toBeInTheDocument();
  });
});
