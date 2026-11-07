// Gate 1 hermetic spike: transport-neutral session journal, NOT a provider adapter.
// No auth, process supervision, or provider capabilities are implied by this contract.
export class SessionJournal {
  constructor(threadId) {
    if (!threadId || typeof threadId !== 'string') throw new TypeError('threadId required');
    this.threadId = threadId;
    this.events = [];
    this.run = null;
    this.status = 'idle';
    this.nativeCursor = null;
  }
  append(event) {
    if (!event || typeof event !== 'object' || Array.isArray(event)) throw new TypeError('event object required');
    const { type, runId } = event;
    if (!['start', 'output', 'approval_required', 'cancel_requested', 'cancelled', 'completed', 'failed', 'interrupted'].includes(type)) throw new Error('unknown event type');
    if (typeof runId !== 'string' || !runId) throw new TypeError('runId required');
    if (this.run === null) {
      if (type !== 'start') throw new Error('run must start first');
      this.run = runId;
    } else if (this.run !== runId) throw new Error('cross-run event rejected');
    if (this.status === 'idle' && type !== 'start') throw new Error('run must start first');
    if (['completed', 'failed', 'cancelled', 'interrupted'].includes(this.status)) throw new Error('terminal run cannot accept more events');
    const allowed = {
      idle: ['start'],
      running: ['output', 'approval_required', 'cancel_requested', 'completed', 'failed', 'interrupted'],
      awaiting_approval: ['output', 'cancel_requested', 'failed', 'interrupted'],
      cancelling: ['output', 'cancelled', 'failed', 'interrupted'],
    };
    if (!allowed[this.status]?.includes(type)) throw new Error(`invalid transition ${this.status} -> ${type}`);
    if (type === 'output' && typeof event.text !== 'string') throw new TypeError('output text required');
    if (type === 'start' && event.nativeCursor !== undefined && typeof event.nativeCursor !== 'string') throw new TypeError('invalid native cursor');
    const entry = Object.freeze({ ...event, sequence: this.events.length + 1, threadId: this.threadId });
    this.events.push(entry);
    if (type === 'start') { this.status = 'running'; this.nativeCursor = event.nativeCursor ?? null; }
    if (type === 'approval_required') this.status = 'awaiting_approval';
    if (type === 'cancel_requested') this.status = 'cancelling';
    if (['cancelled', 'completed', 'failed', 'interrupted'].includes(type)) this.status = type;
    return entry;
  }
  // Explicitly model an approval answer; no permission is granted by the journal.
  approvalObserved(runId, approved) {
    if (this.status !== 'awaiting_approval' || this.run !== runId || typeof approved !== 'boolean') throw new Error('invalid approval observation');
    this.status = 'running';
    return this.append({ type: 'output', runId, text: approved ? '[approval observed]' : '[denial observed]' });
  }
  snapshot() { return { threadId: this.threadId, runId: this.run, status: this.status, nativeCursor: this.nativeCursor, events: this.events.map(e => ({ ...e })) }; }
  static replay(threadId, entries) {
    const journal = new SessionJournal(threadId);
    for (const entry of entries) {
      if (entry.threadId !== threadId || entry.sequence !== journal.events.length + 1) throw new Error('corrupt event ordering');
      if (journal.status === 'awaiting_approval' && entry.type === 'output' && /^\\[approval observed\\]|^\\[denial observed\\]/.test(entry.text)) journal.status = 'running';
      journal.append(entry);
    }
    return journal;
  }
}
// Sidecar and in-process are intentionally the same *wire contract* here.
// This proves boundary neutrality only; it does not prove provider fidelity.
export function projectTransport(transport, journal) {
  if (!transport || typeof transport[Symbol.asyncIterator] !== 'function') throw new TypeError('async event transport required');
  return (async () => { for await (const event of transport) journal.append(event); return journal.snapshot(); })();
}
