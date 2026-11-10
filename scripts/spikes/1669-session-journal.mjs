// Gate 1 hermetic spike: transport-neutral session journal, NOT a provider adapter.
// No auth, process supervision, or provider capabilities are implied by this contract.
export class SessionJournal {
  #events = [];
  // Public inspection must never expose mutable journal-owned event references.
  get events() { return this.#events.map(event => structuredClone(event)); }
  constructor(threadId) {
    if (!threadId || typeof threadId !== 'string') throw new TypeError('threadId required');
    this.threadId = threadId;
    this.run = null;
    this.status = 'idle';
    this.nativeCursor = null;
  }
  append(event) {
    if (!event || typeof event !== 'object' || Array.isArray(event)) throw new TypeError('event object required');
    const { type, runId } = event;
    if (!['start', 'output', 'approval_required', 'approval_observed', 'cancel_requested', 'cancelled', 'completed', 'failed', 'interrupted'].includes(type)) throw new Error('unknown event type');
    if (typeof runId !== 'string' || !runId) throw new TypeError('runId required');
    // Never silently overwrite a provider-supplied app identity or sequence.
    // A mismatched value is evidence of a broken or spoofed transport boundary.
    if (Object.hasOwn(event, 'threadId') && event.threadId !== this.threadId) throw new Error('foreign thread event rejected');
    if (Object.hasOwn(event, 'sequence') && event.sequence !== this.#events.length + 1) throw new Error('out-of-order event rejected');
    if (this.run === null) {
      if (type !== 'start') throw new Error('run must start first');
    } else if (this.run !== runId) throw new Error('cross-run event rejected');
    if (this.status === 'idle' && type !== 'start') throw new Error('run must start first');
    if (['completed', 'failed', 'cancelled', 'interrupted'].includes(this.status)) throw new Error('terminal run cannot accept more events');
    const allowed = {
      idle: ['start'],
      running: ['output', 'approval_required', 'cancel_requested', 'completed', 'failed', 'interrupted'],
      awaiting_approval: ['approval_observed', 'cancel_requested', 'failed', 'interrupted'],
      cancelling: ['output', 'cancelled', 'failed', 'interrupted'],
    };
    if (!allowed[this.status]?.includes(type)) throw new Error(`invalid transition ${this.status} -> ${type}`);
    if (type === 'approval_observed' && typeof event.approved !== 'boolean') throw new TypeError('approval observation required');
    if (type === 'output' && typeof event.text !== 'string') throw new TypeError('output text required');
    if (type === 'start' && event.nativeCursor !== undefined && typeof event.nativeCursor !== 'string') throw new TypeError('invalid native cursor');
    // Preserve the event as observed: providers may reuse/mutate nested payload objects.
    // Cloning also prevents caller-held references from rewriting replay evidence.
    const entry = Object.freeze({ ...structuredClone(event), sequence: this.#events.length + 1, threadId: this.threadId });
    this.#events.push(entry);
    if (type === 'start') this.run = runId;
    if (type === 'start') { this.status = 'running'; this.nativeCursor = event.nativeCursor ?? null; }
    if (type === 'approval_required') this.status = 'awaiting_approval';
    if (type === 'approval_observed') this.status = 'running';
    if (type === 'cancel_requested') this.status = 'cancelling';
    if (['cancelled', 'completed', 'failed', 'interrupted'].includes(type)) this.status = type;
    // Do not expose the journal-owned nested payload through the append return value.
    return structuredClone(entry);
  }
  snapshot() { return { threadId: this.threadId, runId: this.run, status: this.status, nativeCursor: this.nativeCursor, events: this.events }; }
  static replay(threadId, entries) {
    const journal = new SessionJournal(threadId);
    for (const entry of entries) {
      if (entry.threadId !== threadId || entry.sequence !== journal.events.length + 1) throw new Error('corrupt event ordering');
      journal.append(entry);
    }
    return journal;
  }
}
// Sidecar and in-process are intentionally the same *wire contract* here.
// This proves boundary neutrality only; it does not prove provider fidelity.
export function projectTransport(transport, journal) {
  if (!transport || typeof transport[Symbol.asyncIterator] !== 'function') throw new TypeError('async event transport required');
  return (async () => {
    try {
      for await (const event of transport) journal.append(event);
    } catch (error) {
      // A broken transport is not a successful run; preserve the original error.
      if (['running', 'awaiting_approval', 'cancelling'].includes(journal.status)) {
        journal.append({ type: 'interrupted', runId: journal.run, reason: 'transport-error' });
      }
      throw error;
    }
    // EOF is not provider confirmation of completion or cancellation.
    if (['running', 'awaiting_approval', 'cancelling'].includes(journal.status)) {
      journal.append({ type: 'interrupted', runId: journal.run, reason: 'transport-eof' });
    }
    return journal.snapshot();
  })();
}
