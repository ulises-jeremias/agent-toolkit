import test from 'node:test';
import assert from 'node:assert/strict';
import { SessionJournal } from '../../scripts/spikes/1669-session-journal.mjs';

test('large replay validates ordered entries without reading cloned history per entry', () => {
  const journal = new SessionJournal('large-thread');
  journal.append({ type: 'start', runId: 'large-run' });
  for (let i = 0; i < 1500; i++) {
    journal.append({ type: 'output', runId: 'large-run', text: String(i) });
  }
  journal.append({ type: 'completed', runId: 'large-run' });
  const entries = journal.snapshot().events;
  const restored = SessionJournal.replay('large-thread', entries);
  assert.deepEqual(restored.snapshot(), journal.snapshot());

  const corrupt = structuredClone(entries);
  corrupt[1200].sequence = 1199;
  assert.throws(() => SessionJournal.replay('large-thread', corrupt), /corrupt event ordering/);
});
