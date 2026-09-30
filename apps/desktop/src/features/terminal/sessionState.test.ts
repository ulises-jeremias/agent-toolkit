import { describe, expect, it } from 'vitest';
import { sessionState } from './sessionState';

describe('sessionState', () => {
  it('labels a live process as running', () => {
    expect(sessionState(null)).toEqual({ tone: 'ok', label: 'running' });
  });

  it('keeps a zero exit honest', () => {
    expect(sessionState(0)).toEqual({ tone: 'idle', label: 'exited 0' });
  });

  it('surfaces a non-zero exit as an error', () => {
    expect(sessionState(3)).toEqual({ tone: 'err', label: 'exited 3' });
  });
});
