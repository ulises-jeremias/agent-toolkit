import { describe, expect, it } from 'vitest';
import type { LiveStatus } from '../data/live';
import type { LiveSnapshot } from '../lib/live/jobStreams';
import type { BackendState } from '../types/electron';
import { indicatorState } from './LiveIndicator';

const IDLE: LiveSnapshot = { state: 'idle', streams: 0, nextRetryAt: null };

const online: LiveStatus = {
  connection: 'online',
  streams: IDLE,
  bus: IDLE,
  lastHealthyAt: Date.parse('2026-09-29T10:00:00Z'),
};

const backend = (status: BackendState['status']): BackendState => ({
  status,
  url: 'http://127.0.0.1:1',
  version: '1.35.0',
  detail: null,
  restarts: 0,
  harness: null,
  binary: null,
  rejected: [],
  problem: null,
});

describe('indicatorState', () => {
  it('reports a crashed supervisor before anything else', () => {
    expect(indicatorState(backend('crashed'), online)).toMatchObject({ tone: 'err', label: 'Backend down' });
  });

  it('says data is stale when the backend stops answering', () => {
    const state = indicatorState(backend('ready'), { ...online, connection: 'offline' });
    expect(state.tone).toBe('err');
    expect(state.label).toBe('Offline');
    expect(state.detail).toMatch(/^Showing data from /);
  });

  it('distinguishes reconnecting streams from a healthy backend', () => {
    const state = indicatorState(backend('ready'), {
      ...online,
      streams: { state: 'reconnecting', streams: 1, nextRetryAt: Date.now() + 2_000 },
    });
    expect(state).toMatchObject({ tone: 'warn', label: 'Reconnecting' });
  });

  it('counts open job streams when live', () => {
    const state = indicatorState(null, { ...online, streams: { state: 'live', streams: 2, nextRetryAt: null } });
    expect(state).toMatchObject({ tone: 'ok', label: 'Live', detail: '2 job streams open', live: true });
  });

  it('is quietly connected with no running jobs', () => {
    expect(indicatorState(backend('ready'), online)).toMatchObject({ tone: 'ok', label: 'Connected' });
  });

  it('is live from the global event bus with no job streams', () => {
    const state = indicatorState(backend('ready'), {
      ...online,
      bus: { state: 'live', streams: 1, nextRetryAt: null },
    });
    expect(state).toMatchObject({ tone: 'ok', label: 'Live', detail: 'Event stream open', live: true });
  });
});
