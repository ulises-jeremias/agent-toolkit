import { describe, expect, it } from 'vitest';
import type { ApiEvent } from '../api';
import { EventBusManager } from './eventBus';
import type { EventSourceLike, LiveSnapshot } from './jobStreams';

class FakeSource implements EventSourceLike {
  onopen: ((event: Event) => void) | null = null;
  onerror: ((event: Event) => void) | null = null;
  onmessage: ((event: MessageEvent<string>) => void) | null = null;
  closed = false;
  private readonly listeners = new Map<string, Array<(event: MessageEvent<string>) => void>>();

  constructor(readonly url: string) {}

  addEventListener(type: string, listener: (event: MessageEvent<string>) => void): void {
    this.listeners.set(type, [...(this.listeners.get(type) ?? []), listener]);
  }

  close(): void {
    this.closed = true;
  }

  open(): void {
    this.onopen?.(new Event('open'));
  }

  emit(type: string, data: string): void {
    for (const listener of this.listeners.get(type) ?? []) listener(new MessageEvent(type, { data }));
  }

  fail(): void {
    this.onerror?.(new Event('error'));
  }
}

function harness() {
  const sources: FakeSource[] = [];
  const events: ApiEvent[] = [];
  const snapshots: LiveSnapshot[] = [];
  const timers: Array<{ callback: () => void; ms: number; cleared: boolean }> = [];
  const manager = new EventBusManager({
    url: 'http://backend/api/v1/events?types=backend.,job.',
    createSource: (url) => {
      const source = new FakeSource(url);
      sources.push(source);
      return source;
    },
    onEvent: (event) => events.push(event),
    onSnapshot: (snapshot) => snapshots.push(snapshot),
    backoff: { baseMs: 1_000, maxMs: 8_000, jitter: 0 },
    now: () => 0,
    setTimer: (callback, ms) => {
      const timer = { callback, ms, cleared: false };
      timers.push(timer);
      return timer;
    },
    clearTimer: (handle) => {
      (handle as { cleared: boolean }).cleared = true;
    },
  });
  return { manager, sources, events, snapshots, timers };
}

describe('EventBusManager', () => {
  it('decodes named job.updated frames and goes live', () => {
    const { manager, sources, events } = harness();
    manager.start();
    sources[0]?.open();
    sources[0]?.emit(
      'job.updated',
      JSON.stringify({
        seq: 3,
        boot: '9',
        type: 'job.updated',
        at: '2026-09-30T10:00:00Z',
        subject: 'job_1',
        status: 'failed',
        exit_code: 1,
        ref: '',
        message: '',
      }),
    );
    expect(manager.snapshot().state).toBe('live');
    expect(events[0]).toMatchObject({ type: 'job.updated', subject: 'job_1', status: 'failed', exit_code: 1 });
  });

  it('reconnects from idle when health stays online', () => {
    const { manager, sources } = harness();
    manager.setOffline(false);
    expect(sources).toHaveLength(1);
    sources[0]?.open();
    expect(manager.snapshot().state).toBe('live');
  });

  it('reconnects after an offline stretch', () => {
    const { manager, sources } = harness();
    manager.start();
    sources[0]?.open();
    manager.setOffline(true);
    expect(manager.snapshot().state).toBe('offline');
    manager.setOffline(false);
    expect(sources).toHaveLength(2);
    sources[1]?.open();
    expect(manager.snapshot().state).toBe('live');
  });
});
