import { describe, expect, it } from 'vitest';
import type { ApiEvent } from '../api';
import { EventBusManager, type BusSnapshot } from './eventBus';
import type { EventSourceLike } from './jobStreams';

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
  const snapshots: BusSnapshot[] = [];
  const timers: Array<{ callback: () => void; ms: number; cleared: boolean }> = [];
  const manager = new EventBusManager({
    urlFor: (since) => `http://backend/api/v1/events?types=job.,backend.${since === null ? '' : `&since=${since}`}`,
    createSource: (url) => {
      const source = new FakeSource(url);
      sources.push(source);
      return source;
    },
    onEvent: (event) => events.push(event),
    onSnapshot: (snapshot) => snapshots.push(snapshot),
    backoff: { baseMs: 1_000, maxMs: 8_000, jitter: 0 },
    now: () => 0,
    giveUpAfter: 2,
    setTimer: (callback, ms) => {
      const timer = { callback, ms, cleared: false };
      timers.push(timer);
      return timer;
    },
    clearTimer: (handle) => {
      (handle as { cleared: boolean }).cleared = true;
    },
  });
  const fire = () => {
    const timer = timers.find((candidate) => !candidate.cleared);
    if (!timer) throw new Error('no pending timer');
    timer.cleared = true;
    timer.callback();
  };
  return { manager, sources, events, snapshots, timers, fire };
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

  it('resumes with since= last seq after a drop', () => {
    const { manager, sources, fire } = harness();
    manager.start();
    sources[0]?.open();
    sources[0]?.emit('job.created', JSON.stringify({ seq: 4, boot: '9', type: 'job.created', subject: 'job_1' }));
    sources[0]?.fail();
    expect(manager.snapshot().state).toBe('reconnecting');
    fire();
    expect(sources[1]?.url).toContain('since=4');
  });

  it('marks the bus unavailable if it never opens', () => {
    const { manager, sources, fire } = harness();
    manager.start();
    sources[0]?.fail();
    fire();
    sources[1]?.fail();
    expect(manager.snapshot().state).toBe('unavailable');
  });
});
