import { API_EVENT_TYPES, parseApiEvent, type ApiEvent } from '../api';
import { backoffDelay, type BackoffOptions } from './backoff';
import type { EventSourceLike, LiveSnapshot, LiveState } from './jobStreams';

/**
 * One EventSource on GET /api/v1/events. Reconnects with the same backoff
 * as job streams. The browser sends Last-Event-ID on reconnect; a
 * backend.resync from the server is applied as an event, not invented here.
 */

export interface EventBusManagerOptions {
  url: string;
  createSource: (url: string) => EventSourceLike;
  onEvent: (event: ApiEvent) => void;
  onSnapshot: (snapshot: LiveSnapshot) => void;
  backoff?: BackoffOptions;
  now?: () => number;
  setTimer?: (callback: () => void, ms: number) => unknown;
  clearTimer?: (handle: unknown) => void;
}

export class EventBusManager {
  private source: EventSourceLike | null = null;
  private phase: 'idle' | 'connecting' | 'open' | 'waiting' = 'idle';
  private attempt = 0;
  private timer: unknown = null;
  private retryAt: number | null = null;
  private offline = false;
  private disposed = false;
  private lastSnapshot: LiveSnapshot = { state: 'idle', streams: 0, nextRetryAt: null };

  constructor(private readonly options: EventBusManagerOptions) {}

  snapshot(): LiveSnapshot {
    return this.lastSnapshot;
  }

  start(): void {
    if (this.disposed || this.phase === 'open' || this.phase === 'connecting') return;
    if (this.offline) {
      this.phase = 'waiting';
      this.publish();
      return;
    }
    this.connect();
  }

  setOffline(offline: boolean): void {
    if (this.disposed || offline === this.offline) return;
    this.offline = offline;
    if (offline) {
      this.clearTimer();
      this.source?.close();
      this.source = null;
      this.phase = 'waiting';
      this.retryAt = null;
    } else if (this.phase === 'waiting' && this.timer === null) {
      this.connect();
    }
    this.publish();
  }

  dispose(): void {
    this.clearTimer();
    this.source?.close();
    this.source = null;
    this.disposed = true;
  }

  private connect(): void {
    this.clearTimer();
    this.retryAt = null;
    this.phase = 'connecting';
    const source = this.options.createSource(this.options.url);
    this.source = source;

    source.onopen = () => {
      if (this.source !== source) return;
      this.phase = 'open';
      this.attempt = 0;
      this.publish();
    };
    for (const name of API_EVENT_TYPES) {
      source.addEventListener(name, (message) => {
        if (this.source !== source) return;
        const event = parseApiEvent(message.data ?? '', name);
        if (event) this.options.onEvent(event);
      });
    }
    source.onmessage = (message) => {
      if (this.source !== source) return;
      const event = parseApiEvent(message.data ?? '');
      if (event) this.options.onEvent(event);
    };
    source.onerror = () => {
      if (this.source !== source) return;
      source.close();
      this.source = null;
      this.scheduleReconnect();
      this.publish();
    };
    this.publish();
  }

  private scheduleReconnect(): void {
    if (this.offline || this.disposed) {
      this.phase = 'waiting';
      return;
    }
    const delay = backoffDelay(this.attempt, this.options.backoff);
    this.attempt += 1;
    this.phase = 'waiting';
    this.retryAt = this.now() + delay;
    this.timer = this.setTimer(() => {
      this.connect();
      this.publish();
    }, delay);
  }

  private clearTimer(): void {
    if (this.timer !== null) {
      (this.options.clearTimer ?? ((handle) => clearTimeout(handle as ReturnType<typeof setTimeout>)))(this.timer);
      this.timer = null;
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
    let state: LiveState;
    if (this.offline) state = 'offline';
    else if (this.phase === 'idle') state = 'idle';
    else if (this.phase === 'waiting') state = 'reconnecting';
    else if (this.phase === 'connecting') state = 'connecting';
    else state = 'live';
    const next: LiveSnapshot = {
      state,
      streams: this.phase === 'idle' ? 0 : 1,
      nextRetryAt: this.retryAt,
    };
    const prev = this.lastSnapshot;
    if (prev.state === next.state && prev.streams === next.streams && prev.nextRetryAt === next.nextRetryAt) return;
    this.lastSnapshot = next;
    this.options.onSnapshot(next);
  }
}
