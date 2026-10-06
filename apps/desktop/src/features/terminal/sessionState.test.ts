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

  it('reports a configured time limit separately from a process error', () => {
    expect(sessionState(143, 'time-budget')).toEqual({ tone: 'warn', label: 'time limit reached' });
  });

  it('reports a user stop as an intentional action', () => {
    expect(sessionState(143, 'user-stop')).toEqual({ tone: 'idle', label: 'stopped' });
  });

  it('reports app shutdown as an interrupted session', () => {
    expect(sessionState(137, 'app-shutdown')).toEqual({ tone: 'warn', label: 'interrupted' });
  });
});
