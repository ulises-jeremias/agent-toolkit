import { describe, expect, it } from 'vitest';
import { backoffDelay } from './backoff';
import { JobStreamManager, type EventSourceLike, type LiveEvent, type LiveSnapshot } from './jobStreams';

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
  const events: LiveEvent[] = [];
  const snapshots: LiveSnapshot[] = [];
  const timers: Array<{ callback: () => void; ms: number; cleared: boolean }> = [];
  const manager = new JobStreamManager({
    urlFor: (id) => `http://backend/api/v1/jobs/${id}/events`,
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
  const fire = () => {
    const timer = timers.find((candidate) => !candidate.cleared);
    if (!timer) throw new Error('no pending timer');
    timer.cleared = true;
    timer.callback();
  };
  return { manager, sources, events, snapshots, timers, fire };
}

describe('backoffDelay', () => {
  it('doubles per attempt up to the cap', () => {
    const options = { baseMs: 1_000, maxMs: 30_000, jitter: 0 };
    expect([0, 1, 2, 3, 4, 5, 6].map((attempt) => backoffDelay(attempt, options))).toEqual([
      1_000, 2_000, 4_000, 8_000, 16_000, 30_000, 30_000,
    ]);
  });

  it('jitters downward only', () => {
    expect(backoffDelay(2, { baseMs: 1_000, jitter: 0.5, random: () => 1 })).toBe(2_000);
    expect(backoffDelay(2, { baseMs: 1_000, jitter: 0.5, random: () => 0 })).toBe(4_000);
  });
});

describe('JobStreamManager', () => {
  it('opens one stream per active job and closes streams for jobs no longer active', () => {
    const { manager, sources } = harness();
    manager.sync(['a', 'b']);
    expect(sources.map((source) => source.url)).toEqual([
      'http://backend/api/v1/jobs/a/events',
      'http://backend/api/v1/jobs/b/events',
    ]);
    manager.sync(['b']);
    expect(sources[0]?.closed).toBe(true);
    expect(sources[1]?.closed).toBe(false);
    manager.sync(['b']);
    expect(sources).toHaveLength(2);
  });

  it('resets the buffer on open, forwards named events, and stops at done', () => {
    const { manager, sources, events, snapshots } = harness();
    manager.sync(['a']);
    const source = sources[0];
    source?.open();
    source?.emit('status', 'running');
    source?.emit('log', 'line one');
    source?.emit('done', 'completed');
    source?.fail(); // EventSource reports the server's normal close as an error
    expect(events.map((event) => event.event)).toEqual([
      { type: 'reset' },
      { type: 'status', status: 'running' },
      { type: 'log', line: 'line one' },
      { type: 'done', status: 'completed' },
    ]);
    expect(source?.closed).toBe(true);
    expect(snapshots.at(-1)).toEqual({ state: 'idle', streams: 0, nextRetryAt: null });
  });

  it('reconnects with growing backoff while the job is still active, and resets on success', () => {
    const { manager, sources, timers, fire, snapshots } = harness();
    manager.sync(['a']);
    sources[0]?.open();
    expect(snapshots.at(-1)?.state).toBe('live');

    sources[0]?.fail();
    expect(snapshots.at(-1)).toMatchObject({ state: 'reconnecting', nextRetryAt: 1_000 });
    fire();
    sources[1]?.fail();
    fire();
    expect(timers.map((timer) => timer.ms)).toEqual([1_000, 2_000]);

    sources[2]?.open();
    sources[2]?.fail();
    expect(timers.at(-1)?.ms).toBe(1_000);
  });

  it('opens nothing while offline and reconnects everything when back online', () => {
    const { manager, sources, snapshots } = harness();
    manager.setOffline(true);
    manager.sync(['a']);
    expect(sources).toHaveLength(0);
    expect(snapshots.at(-1)?.state).toBe('offline');
    manager.setOffline(false);
    expect(sources).toHaveLength(1);
    expect(snapshots.at(-1)?.state).toBe('connecting');
  });

  it('cancels pending reconnects when the job stops being active', () => {
    const { manager, sources, timers } = harness();
    manager.sync(['a']);
    sources[0]?.fail();
    manager.sync([]);
    expect(timers[0]?.cleared).toBe(true);
  });

  it('ignores events from a replaced source', () => {
    const { manager, sources, events, fire } = harness();
    manager.sync(['a']);
    const stale = sources[0];
    stale?.fail();
    fire();
    stale?.emit('log', 'late line');
    expect(events.filter((event) => event.event.type === 'log')).toHaveLength(0);
  });
});
