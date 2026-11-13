import { describe, expect, it, vi } from 'vitest';
import type { FocusBridge, FocusEvent, FocusEventBody, FocusLiveUpdate, FocusThread } from '../types/focus';
import { FocusStore } from './focus';

const thread = (id: string, patch: Partial<FocusThread> = {}): FocusThread => ({
  id,
  title: id,
  workspace: '/ws',
  projectName: 'demo',
  cwd: '/ws/demo',
  provider: 'claude',
  model: null,
  resolvedModel: null,
  permissionMode: 'ask',
  providerSessionId: null,
  status: 'idle',
  createdAt: '2026-11-12T00:00:00.000Z',
  updatedAt: '2026-11-12T00:00:00.000Z',
  turns: 0,
  lastError: null,
  usage: { inputTokens: 0, cachedInputTokens: 0, outputTokens: 0, costUsd: null },
  ...patch,
});

const event = (seq: number, body: FocusEventBody): FocusEvent =>
  ({ seq, at: '2026-11-12T00:00:00.000Z', turn: 1, ...body }) as FocusEvent;

function bridge(overrides: Partial<FocusBridge> = {}): {
  bridge: FocusBridge;
  push: (update: FocusLiveUpdate) => void;
} {
  let listener: ((update: FocusLiveUpdate) => void) | null = null;
  const base: FocusBridge = {
    providers: async () => [],
    listThreads: async () => [],
    createThread: async () => ({ ok: false, error: 'unused' }),
    readThread: async () => null,
    updateThread: async () => ({ ok: false, error: 'unused' }),
    deleteThread: async () => ({ ok: true, value: true }),
    send: async () => ({ ok: true, value: true }),
    respondApproval: async () => ({ ok: true, value: true }),
    interrupt: async () => ({ ok: true, value: true }),
    onUpdate: (next) => {
      listener = next;
      return () => {
        listener = null;
      };
    },
    ...overrides,
  };
  return { bridge: base, push: (update) => listener?.(update) };
}

describe('FocusStore', () => {
  it('loads threads on connect and keeps them ordered by last activity', async () => {
    const { bridge: api, push } = bridge({
      listThreads: async () => [thread('th_a', { updatedAt: '2026-11-12T01:00:00.000Z' })],
    });
    const store = new FocusStore(api);
    const disconnect = store.connect();
    await vi.waitFor(() => expect(store.getThreadsLoaded()).toBe(true));
    push({ kind: 'thread', thread: thread('th_b', { updatedAt: '2026-11-12T02:00:00.000Z' }) });
    expect(store.getThreads().map((entry) => entry.id)).toEqual(['th_b', 'th_a']);
    push({ kind: 'removed', threadId: 'th_b' });
    expect(store.getThreads().map((entry) => entry.id)).toEqual(['th_a']);
    disconnect();
  });

  it('accumulates live text, then drops it when the item is committed', async () => {
    const { bridge: api, push } = bridge();
    const store = new FocusStore(api);
    store.connect();
    push({ kind: 'delta', threadId: 'th_a', itemId: 'i1', channel: 'assistant', text: 'Hel' });
    push({ kind: 'delta', threadId: 'th_a', itemId: 'i1', channel: 'assistant', text: 'lo' });
    await vi.waitFor(() => expect(store.getTimeline('th_a').live['i1']?.text).toBe('Hello'));
    push({ kind: 'event', threadId: 'th_a', event: event(1, { type: 'assistant', itemId: 'i1', text: 'Hello' }) });
    expect(store.getTimeline('th_a').live).toEqual({});
    expect(store.getTimeline('th_a').events).toHaveLength(1);
  });

  it('never shows the same journaled event twice', () => {
    const { bridge: api, push } = bridge();
    const store = new FocusStore(api);
    store.connect();
    const first = event(1, { type: 'user', text: 'hi' });
    push({ kind: 'event', threadId: 'th_a', event: first });
    push({ kind: 'event', threadId: 'th_a', event: first });
    expect(store.getTimeline('th_a').events).toHaveLength(1);
  });

  it('merges a snapshot with events that arrived while it was loading', async () => {
    let resolve: (value: { thread: FocusThread; events: FocusEvent[] }) => void = () => undefined;
    const { bridge: api, push } = bridge({
      readThread: () => new Promise((done) => (resolve = done)),
    });
    const store = new FocusStore(api);
    store.connect();
    store.ensureTimeline('th_a');
    push({ kind: 'event', threadId: 'th_a', event: event(2, { type: 'turn.started', model: null }) });
    resolve({ thread: thread('th_a'), events: [event(1, { type: 'user', text: 'hi' })] });
    await vi.waitFor(() => expect(store.getTimeline('th_a').loaded).toBe(true));
    expect(store.getTimeline('th_a').events.map((entry) => entry.seq)).toEqual([1, 2]);
  });

  it('keeps a session created while the list was loading', async () => {
    let resolve: (value: FocusThread[]) => void = () => undefined;
    const { bridge: api, push } = bridge({ listThreads: () => new Promise((done) => (resolve = done)) });
    const store = new FocusStore(api);
    store.connect();
    push({ kind: 'thread', thread: thread('th_new', { updatedAt: '2026-11-12T03:00:00.000Z' }) });
    resolve([thread('th_old')]);
    await vi.waitFor(() => expect(store.getThreadsLoaded()).toBe(true));
    expect(store.getThreads().map((entry) => entry.id)).toEqual(['th_new', 'th_old']);
  });

  it('clears live text when the turn ends', async () => {
    const { bridge: api, push } = bridge();
    const store = new FocusStore(api);
    store.connect();
    push({ kind: 'delta', threadId: 'th_a', itemId: 'i1', channel: 'reasoning', text: 'hmm' });
    push({
      kind: 'event',
      threadId: 'th_a',
      event: event(1, { type: 'turn.finished', outcome: 'interrupted', detail: null, durationMs: null, usage: null }),
    });
    expect(store.getTimeline('th_a').live).toEqual({});
  });

  it('is inert without a runtime', () => {
    const store = new FocusStore(undefined);
    store.connect();
    expect(store.available).toBe(false);
    expect(store.getThreadsLoaded()).toBe(true);
    expect(store.getThreads()).toEqual([]);
  });
});
