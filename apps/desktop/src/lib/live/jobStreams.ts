import { JOB_STREAM_EVENT_NAMES, namedJobStreamEvent, parseJobStreamEvent, type JobStreamEvent } from '../api';
import { backoffDelay, type BackoffOptions } from './backoff';

/**
 * Keeps one SSE stream open per active job and reconnects with backoff when
 * a stream drops before its `done` event. Framework-free: React only feeds
 * it the active job ids and renders its state.
 *
 * This is the transport the Desktop has today. When `GET /api/v1/events`
 * (global bus) lands, a bus source replaces the per-job fan-out behind the
 * same `LiveEvent` output and `LiveSnapshot` state; consumers do not change.
 */

/** Minimal EventSource surface, so tests can supply a fake. */
export interface EventSourceLike {
  addEventListener(type: string, listener: (event: MessageEvent<string>) => void): void;
  onopen: ((event: Event) => void) | null;
  onerror: ((event: Event) => void) | null;
  onmessage: ((event: MessageEvent<string>) => void) | null;
  close(): void;
}

export type LiveEvent =
  | { jobId: string; event: JobStreamEvent }
  /** The stream (re)connected; the server replays the full log, so drop buffered lines. */
  | { jobId: string; event: { type: 'reset' } };

export type LiveState = 'idle' | 'connecting' | 'live' | 'reconnecting' | 'offline';

export interface LiveSnapshot {
  state: LiveState;
  /** Streams currently open or scheduled to reopen. */
  streams: number;
  /** Epoch ms of the next scheduled reconnect, when reconnecting. */
  nextRetryAt: number | null;
}

export interface JobStreamManagerOptions {
  urlFor: (jobId: string) => string;
  createSource: (url: string) => EventSourceLike;
  onEvent: (event: LiveEvent) => void;
  onSnapshot: (snapshot: LiveSnapshot) => void;
  backoff?: BackoffOptions;
  now?: () => number;
  setTimer?: (callback: () => void, ms: number) => unknown;
  clearTimer?: (handle: unknown) => void;
}

interface StreamEntry {
  source: EventSourceLike | null;
  phase: 'connecting' | 'open' | 'waiting';
  attempt: number;
  timer: unknown;
  retryAt: number | null;
}

export class JobStreamManager {
  private readonly streams = new Map<string, StreamEntry>();
  private offline = false;
  private disposed = false;
  private lastSnapshot: LiveSnapshot = { state: 'idle', streams: 0, nextRetryAt: null };

  constructor(private readonly options: JobStreamManagerOptions) {}

  snapshot(): LiveSnapshot {
    return this.lastSnapshot;
  }

  /** Reconcile open streams with the jobs the cache currently reports as active. */
  sync(activeJobIds: Iterable<string>): void {
    if (this.disposed) return;
    const wanted = new Set(activeJobIds);
    for (const id of [...this.streams.keys()]) {
      if (!wanted.has(id)) this.drop(id);
    }
    for (const id of wanted) {
      if (!this.streams.has(id)) this.open(id, 0);
    }
    this.publish();
  }

  /** While offline no stream is opened; going online reopens everything still wanted. */
  setOffline(offline: boolean): void {
    if (this.disposed || offline === this.offline) return;
    this.offline = offline;
    if (offline) {
      for (const entry of this.streams.values()) {
        this.clearTimer(entry);
        entry.source?.close();
        entry.source = null;
        entry.phase = 'waiting';
        entry.retryAt = null;
      }
    } else {
      for (const [id, entry] of this.streams) {
        if (entry.phase === 'waiting' && entry.timer === null) this.connect(id, entry);
      }
    }
    this.publish();
  }

  dispose(): void {
    for (const id of [...this.streams.keys()]) this.drop(id);
    this.disposed = true;
  }

  /** Track a wanted job; while offline it waits and connects when `setOffline(false)` arrives. */
  private open(id: string, attempt: number): void {
    const entry: StreamEntry = { source: null, phase: 'waiting', attempt, timer: null, retryAt: null };
    this.streams.set(id, entry);
    if (!this.offline) this.connect(id, entry);
  }

  private connect(id: string, entry: StreamEntry): void {
    entry.timer = null;
    entry.retryAt = null;
    entry.phase = 'connecting';
    const source = this.options.createSource(this.options.urlFor(id));
    entry.source = source;
    let finished = false;

    source.onopen = () => {
      if (entry.source !== source) return;
      entry.phase = 'open';
      entry.attempt = 0;
      this.options.onEvent({ jobId: id, event: { type: 'reset' } });
      this.publish();
    };
    for (const name of JOB_STREAM_EVENT_NAMES) {
      source.addEventListener(name, (message) => {
        if (entry.source !== source) return;
        const event = namedJobStreamEvent(name, message.data ?? '');
        this.options.onEvent({ jobId: id, event });
        if (event.type === 'done') {
          finished = true;
          this.drop(id);
          this.publish();
        }
      });
    }
    source.onmessage = (message) => {
      if (entry.source !== source) return;
      this.options.onEvent({ jobId: id, event: parseJobStreamEvent(message.data ?? '') });
    };
    source.onerror = () => {
      // EventSource also reports a normal server-side close as an error;
      // `done` has already dropped the entry in that case.
      if (finished || entry.source !== source) return;
      source.close();
      entry.source = null;
      this.scheduleReconnect(id, entry);
      this.publish();
    };
    this.publish();
  }

  private scheduleReconnect(id: string, entry: StreamEntry): void {
    if (this.offline || this.disposed) {
      entry.phase = 'waiting';
      return;
    }
    const delay = backoffDelay(entry.attempt, this.options.backoff);
    entry.attempt += 1;
    entry.phase = 'waiting';
    entry.retryAt = this.now() + delay;
    entry.timer = this.setTimer(() => {
      if (this.streams.get(id) === entry) {
        this.connect(id, entry);
        this.publish();
      }
    }, delay);
  }

  private drop(id: string): void {
    const entry = this.streams.get(id);
    if (!entry) return;
    this.clearTimer(entry);
    entry.source?.close();
    entry.source = null;
    this.streams.delete(id);
  }

  private clearTimer(entry: StreamEntry): void {
    if (entry.timer !== null) {
      (this.options.clearTimer ?? ((handle) => clearTimeout(handle as ReturnType<typeof setTimeout>)))(entry.timer);
      entry.timer = null;
    }
  }

  private setTimer(callback: () => void, ms: number): unknown {
    return (this.options.setTimer ?? ((cb, delay) => setTimeout(cb, delay)))(callback, ms);
  }

  private now(): number {
    return (this.options.now ?? Date.now)();
  }

  private publish(): void {
    if (this.disposed) return;
    const entries = [...this.streams.values()];
    const retries = entries.map((entry) => entry.retryAt).filter((at): at is number => at !== null);
    let state: LiveState;
    if (this.offline) state = 'offline';
    else if (entries.length === 0) state = 'idle';
    else if (entries.some((entry) => entry.phase === 'waiting')) state = 'reconnecting';
    else if (entries.some((entry) => entry.phase === 'connecting')) state = 'connecting';
    else state = 'live';
    const next: LiveSnapshot = {
      state,
      streams: entries.length,
      nextRetryAt: retries.length > 0 ? Math.min(...retries) : null,
    };
    const prev = this.lastSnapshot;
    if (prev.state === next.state && prev.streams === next.streams && prev.nextRetryAt === next.nextRetryAt) return;
    this.lastSnapshot = next;
    this.options.onSnapshot(next);
  }
}
