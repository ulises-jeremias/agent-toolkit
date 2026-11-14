import { useQuery } from '@tanstack/react-query';
import { createContext, useContext, useEffect, useMemo, useSyncExternalStore, type ReactNode } from 'react';
import type { LiveText } from '../features/focus/timeline';
import type { FocusBridge, FocusEvent, FocusLiveUpdate, FocusProviderStatus, FocusThread } from '../types/focus';
import { useBackend } from './backend';

/**
 * Renderer-side projection of Focus sessions. The Electron session runtime
 * owns the truth (ADR-044); this store mirrors threads and journaled events
 * and holds live-only text deltas until their item is committed.
 */

export interface ThreadTimeline {
  loaded: boolean;
  events: readonly FocusEvent[];
  live: Readonly<Record<string, LiveText>>;
}

const EMPTY_TIMELINE: ThreadTimeline = { loaded: false, events: [], live: {} };
const NO_THREADS: readonly FocusThread[] = [];

export class FocusStore {
  private threads: readonly FocusThread[] = NO_THREADS;
  private threadsLoaded = false;
  private readonly timelines = new Map<string, ThreadTimeline>();
  private readonly drafts = new Map<string, string>();
  private readonly loading = new Set<string>();
  private readonly listeners = new Set<() => void>();
  private pendingDeltas: Array<Extract<FocusLiveUpdate, { kind: 'delta' }>> = [];
  private flushHandle: ReturnType<typeof setTimeout> | null = null;
  private touchedDuringReload: Set<string> | null = null;
  private reloadGeneration = 0;

  constructor(private readonly bridge: FocusBridge | undefined) {}

  get available(): boolean {
    return this.bridge !== undefined;
  }

  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  };

  getThreads = (): readonly FocusThread[] => this.threads;

  getThreadsLoaded = (): boolean => this.threadsLoaded;

  getDraft(threadId: string): string {
    return this.drafts.get(threadId) ?? '';
  }

  setDraft(threadId: string, text: string): void {
    if (text) this.drafts.set(threadId, text);
    else this.drafts.delete(threadId);
  }

  getTimeline(id: string | null): ThreadTimeline {
    return (id && this.timelines.get(id)) || EMPTY_TIMELINE;
  }

  /** Connect to the runtime. Returns the disconnect function. */
  connect(): () => void {
    if (!this.bridge) {
      this.threadsLoaded = true;
      return () => undefined;
    }
    const off = this.bridge.onUpdate((update) => this.apply(update));
    void this.reload();
    return () => {
      off();
      if (this.flushHandle) clearTimeout(this.flushHandle);
      this.flushHandle = null;
    };
  }

  /** Re-read the thread list, e.g. after the workspace changed. */
  async reload(): Promise<void> {
    if (!this.bridge) return;
    const generation = ++this.reloadGeneration;
    // Anything the runtime pushes while the list is in flight is newer than the list.
    const touched = new Set<string>();
    this.touchedDuringReload = touched;
    const listed = await this.bridge.listThreads();
    // Workspace changes and connect can overlap. A superseded response must not
    // replace the thread list or clear a newer reload's live-update set.
    if (generation !== this.reloadGeneration) return;
    if (this.touchedDuringReload === touched) this.touchedDuringReload = null;
    const listedIds = new Set(listed.map((thread) => thread.id));
    const newer = this.threads.filter((thread) => touched.has(thread.id));
    const newerIds = new Set(newer.map((thread) => thread.id));
    this.threads = [...newer, ...listed.filter((thread) => !newerIds.has(thread.id))].sort((a, b) =>
      b.updatedAt.localeCompare(a.updatedAt),
    );
    this.threadsLoaded = true;
    for (const id of [...this.timelines.keys()]) {
      if (!listedIds.has(id) && !touched.has(id)) this.timelines.delete(id);
    }
    this.notify();
  }

  ensureTimeline(id: string): void {
    if (!this.bridge || this.loading.has(id) || this.timelines.get(id)?.loaded) return;
    this.loading.add(id);
    void this.bridge.readThread(id).then((snapshot) => {
      this.loading.delete(id);
      if (!snapshot) return;
      // Events that arrived while the snapshot was in flight are newer than it.
      const arrived = this.timelines.get(id);
      const seen = new Set(snapshot.events.map((event) => event.seq));
      const extra = (arrived?.events ?? []).filter((event) => !seen.has(event.seq));
      this.timelines.set(id, { loaded: true, events: [...snapshot.events, ...extra], live: arrived?.live ?? {} });
      this.upsertThread(snapshot.thread);
      this.notify();
    });
  }

  apply(update: FocusLiveUpdate): void {
    this.touchedDuringReload?.add(update.kind === 'thread' ? update.thread.id : update.threadId);
    switch (update.kind) {
      case 'delta':
        this.pendingDeltas.push(update);
        // Coalesce token-sized deltas into one paint per frame.
        this.flushHandle ??= setTimeout(() => this.flushDeltas(), 32);
        return;
      case 'thread':
        this.upsertThread(update.thread);
        break;
      case 'removed':
        this.threads = this.threads.filter((thread) => thread.id !== update.threadId);
        this.timelines.delete(update.threadId);
        this.drafts.delete(update.threadId);
        break;
      case 'event': {
        this.flushDeltas(false);
        const current = this.timelines.get(update.threadId) ?? EMPTY_TIMELINE;
        const event = update.event;
        let live = current.live;
        if (event.type === 'assistant' || event.type === 'reasoning') {
          const rest = { ...live };
          delete rest[event.itemId];
          live = rest;
        } else if (event.type === 'turn.finished') {
          live = {};
        }
        if (current.events.some((existing) => existing.seq === event.seq)) return;
        this.timelines.set(update.threadId, { loaded: current.loaded, events: [...current.events, event], live });
        break;
      }
    }
    this.notify();
  }

  private flushDeltas(notify = true): void {
    if (this.flushHandle) clearTimeout(this.flushHandle);
    this.flushHandle = null;
    if (this.pendingDeltas.length === 0) return;
    const pending = this.pendingDeltas;
    this.pendingDeltas = [];
    for (const delta of pending) {
      const current = this.timelines.get(delta.threadId) ?? EMPTY_TIMELINE;
      const previous = current.live[delta.itemId];
      this.timelines.set(delta.threadId, {
        ...current,
        live: {
          ...current.live,
          [delta.itemId]: { channel: delta.channel, text: (previous?.text ?? '') + delta.text },
        },
      });
    }
    if (notify) this.notify();
  }

  private upsertThread(thread: FocusThread): void {
    const others = this.threads.filter((existing) => existing.id !== thread.id);
    this.threads = [thread, ...others].sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}

const FocusContext = createContext<FocusStore | null>(null);

export function FocusProvider({ children, store }: { children: ReactNode; store?: FocusStore }) {
  const { backend } = useBackend();
  const owned = useMemo(
    () => store ?? new FocusStore(typeof window !== 'undefined' ? window.atk?.focus : undefined),
    [store],
  );
  useEffect(() => owned.connect(), [owned]);
  // Threads are journaled per workspace; follow the workspace the backend runs in.
  const workspace = backend?.harness?.path ?? null;
  useEffect(() => {
    if (workspace) void owned.reload();
  }, [owned, workspace]);
  return <FocusContext.Provider value={owned}>{children}</FocusContext.Provider>;
}

export function useFocusStore(): FocusStore {
  const store = useContext(FocusContext);
  if (!store) throw new Error('useFocusStore must be used inside <FocusProvider>');
  return store;
}

export function useFocusBridge(): FocusBridge | undefined {
  return typeof window !== 'undefined' ? window.atk?.focus : undefined;
}

export function useFocusThreads(): { threads: readonly FocusThread[]; loaded: boolean } {
  const store = useFocusStore();
  const threads = useSyncExternalStore(store.subscribe, store.getThreads);
  const loaded = useSyncExternalStore(store.subscribe, store.getThreadsLoaded);
  return { threads, loaded };
}

export function useFocusTimeline(id: string | null): ThreadTimeline {
  const store = useFocusStore();
  useEffect(() => {
    if (id) store.ensureTimeline(id);
  }, [store, id]);
  return useSyncExternalStore(store.subscribe, () => store.getTimeline(id));
}

/** Installed and signed-in state of each coding provider, straight from its CLI. */
export function useFocusProviders() {
  const bridge = useFocusBridge();
  return useQuery<FocusProviderStatus[]>({
    queryKey: ['focus', 'providers'],
    queryFn: () => (bridge ? bridge.providers() : Promise.resolve([])),
    staleTime: 60_000,
  });
}
