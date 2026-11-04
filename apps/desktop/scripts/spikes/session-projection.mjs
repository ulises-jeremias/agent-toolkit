// Gate 1 (#1669): transport-independent, hermetic session projection spike.
// No provider integration or real-provider acceptance is implied.
export class SessionProjection {
  constructor({ threadId, runId }) {
    if (!threadId || !runId) throw new Error('app-owned ids required');
    this.threadId = threadId;
    this.runId = runId;
    this.status = 'created';
    this.lastSequence = 0;
    this.events = [];
    this.nodes = new Map();
    this.providerCursor = null;
  }

  apply(event) {
    if (!event || !Number.isSafeInteger(event.sequence) || event.sequence < 1)
      throw new Error('invalid event sequence');
    if (event.threadId !== this.threadId || event.runId !== this.runId)
      throw new Error('cross-session event rejected');
    if (event.sequence <= this.lastSequence) {
      const previous = this.events.find(item => item.sequence === event.sequence);
      if (previous && JSON.stringify(previous) === JSON.stringify(event)) return false;
      throw new Error('conflicting or stale event');
    }
    if (event.sequence !== this.lastSequence + 1) throw new Error('event gap: replay required');
    if (!['started', 'child_started', 'child_completed', 'approval_requested',
      'approval_resolved', 'root_completed', 'root_failed', 'cancelled', 'interrupted'].includes(event.type))
      throw new Error('unsupported event type');
    if (['root_completed', 'root_failed', 'cancelled', 'interrupted'].includes(this.status))
      throw new Error('terminal run cannot be revived');
    if (event.type === 'started') {
      if (this.status !== 'created') throw new Error('run already started');
      this.status = 'running';
      this.providerCursor = event.providerCursor ?? null;
    } else {
      if (this.status === 'created') throw new Error('run not started');
      if (event.type === 'child_started') {
        if (!event.nodeId || this.nodes.has(event.nodeId)) throw new Error('invalid child identity');
        this.nodes.set(event.nodeId, 'running');
      }
      if (event.type === 'child_completed') {
        if (this.nodes.get(event.nodeId) !== 'running') throw new Error('unknown or completed child');
        this.nodes.set(event.nodeId, 'completed');
      }
      if (event.type === 'approval_requested') {
        if (!event.nodeId || this.nodes.has(event.nodeId)) throw new Error('invalid approval identity');
        this.nodes.set(event.nodeId, 'pending_approval');
        this.status = 'needs_approval';
      }
      if (event.type === 'approval_resolved') {
        if (this.nodes.get(event.nodeId) !== 'pending_approval') throw new Error('unknown approval');
        this.nodes.set(event.nodeId, event.approved === true ? 'approved' : 'denied');
        this.status = 'running';
      }
      if (event.type === 'root_completed') {
        if ([...this.nodes.values()].some(s => s === 'running' || s === 'pending_approval'))
          throw new Error('root has unfinished execution nodes');
        this.status = 'root_completed';
      }
      if (event.type === 'root_failed' || event.type === 'cancelled' || event.type === 'interrupted')
        this.status = event.type;
    }
    this.events.push(structuredClone(event));
    this.lastSequence = event.sequence;
    return true;
  }

  // After a crash a previously running process is not presumed alive.
  recovered() {
    if (['running', 'needs_approval'].includes(this.status)) this.status = 'interrupted';
    return this;
  }

  static replay(ids, events, { afterCrash = false } = {}) {
    const projection = new SessionProjection(ids);
    for (const event of events) projection.apply(event);
    return afterCrash ? projection.recovered() : projection;
  }
}
