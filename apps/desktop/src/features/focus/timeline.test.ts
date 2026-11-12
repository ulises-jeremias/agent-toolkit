import { describe, expect, it } from 'vitest';
import type { FocusEvent, FocusEventBody } from '../../types/focus';
import { buildTimeline, formatDuration, formatTokens, pendingApproval } from './timeline';

function journal(bodies: Array<FocusEventBody & { turn?: number }>): FocusEvent[] {
  return bodies.map(
    (body, index) => ({ seq: index + 1, at: '2026-11-12T00:00:00.000Z', turn: body.turn ?? 1, ...body }) as FocusEvent,
  );
}

const tool = (itemId: string, parentItemId: string | null = null): FocusEventBody => ({
  type: 'tool.started',
  itemId,
  name: 'Edit',
  kind: 'edit',
  title: 'math.js',
  input: {},
  parentItemId,
});

describe('buildTimeline', () => {
  it('merges a tool call, its approval and its result into one item', () => {
    const turns = buildTimeline(
      journal([
        { type: 'user', text: 'fix it' },
        { type: 'turn.started', model: null },
        tool('t1'),
        {
          type: 'approval.requested',
          requestId: 'r1',
          itemId: 't1',
          tool: 'Edit',
          kind: 'edit',
          title: 'math.js',
          input: {},
          canAllowForSession: true,
        },
      ]),
    );
    expect(turns).toHaveLength(1);
    expect(turns[0]?.open).toBe(true);
    expect(pendingApproval(turns)).toMatchObject({ itemId: 't1', state: 'awaiting-approval' });

    const done = buildTimeline(
      journal([
        { type: 'user', text: 'fix it' },
        { type: 'turn.started', model: null },
        tool('t1'),
        {
          type: 'approval.requested',
          requestId: 'r1',
          itemId: 't1',
          tool: 'Edit',
          kind: 'edit',
          title: 'math.js',
          input: {},
          canAllowForSession: true,
        },
        { type: 'approval.resolved', requestId: 'r1', decision: 'allow', by: 'user' },
        { type: 'tool.finished', itemId: 't1', ok: true, output: 'updated', truncated: false },
        { type: 'assistant', itemId: 'a1', text: 'Fixed.' },
        { type: 'turn.finished', outcome: 'completed', detail: null, durationMs: 1200, usage: null },
      ]),
    );
    expect(done[0]?.items.map((item) => item.kind)).toEqual(['user', 'tool', 'assistant', 'turn-end']);
    expect(done[0]?.items[1]).toMatchObject({
      state: 'ok',
      output: 'updated',
      approval: { state: 'allow', by: 'user' },
    });
    expect(pendingApproval(done)).toBeNull();
  });

  it('shows a denied call as denied even though the provider reports a tool error', () => {
    const turns = buildTimeline(
      journal([
        { type: 'turn.started', model: null },
        tool('t1'),
        {
          type: 'approval.requested',
          requestId: 'r1',
          itemId: 't1',
          tool: 'Edit',
          kind: 'edit',
          title: 'math.js',
          input: {},
          canAllowForSession: false,
        },
        { type: 'approval.resolved', requestId: 'r1', decision: 'deny', by: 'user' },
        { type: 'tool.finished', itemId: 't1', ok: false, output: 'The user denied this action.', truncated: false },
      ]),
    );
    expect(turns[0]?.items[0]).toMatchObject({ state: 'denied' });
  });

  it('never leaves a tool spinning after its turn ended', () => {
    const turns = buildTimeline(
      journal([
        { type: 'turn.started', model: null },
        tool('t1'),
        tool('t2', 't1'),
        { type: 'turn.finished', outcome: 'interrupted', detail: 'Stopped by you.', durationMs: null, usage: null },
      ]),
    );
    const parent = turns[0]?.items[0];
    expect(parent).toMatchObject({ state: 'cancelled' });
    expect(parent?.kind === 'tool' && parent.children[0]?.state).toBe('cancelled');
    expect(turns[0]?.open).toBe(false);
  });

  it('nests subagent calls under the call that started them', () => {
    const turns = buildTimeline(
      journal([{ type: 'turn.started', model: null }, tool('agent'), tool('child', 'agent')]),
    );
    expect(turns[0]?.items).toHaveLength(1);
    const parent = turns[0]?.items[0];
    expect(parent?.kind === 'tool' && parent.children.map((child) => child.itemId)).toEqual(['child']);
  });

  it('appends live text to the open turn and drops it once the item is committed', () => {
    const events = journal([
      { type: 'user', text: 'hi' },
      { type: 'turn.started', model: null },
    ]);
    const streaming = buildTimeline(events, { live1: { channel: 'assistant', text: 'Hel' } });
    expect(streaming[0]?.items.at(-1)).toMatchObject({ kind: 'assistant', key: 'live1', text: 'Hel', streaming: true });

    const committed = buildTimeline(
      [
        ...events,
        ...journal([{ type: 'assistant', itemId: 'live1', text: 'Hello' }]).map((event) => ({ ...event, seq: 3 })),
      ],
      { live1: { channel: 'assistant', text: 'Hel' } },
    );
    expect(committed[0]?.items.filter((item) => item.kind === 'assistant')).toEqual([
      { kind: 'assistant', key: 'live1', text: 'Hello', streaming: false },
    ]);
  });

  it('ignores live text when no turn is open', () => {
    const turns = buildTimeline(
      journal([
        { type: 'turn.started', model: null },
        { type: 'turn.finished', outcome: 'completed', detail: null, durationMs: 5, usage: null },
      ]),
      { stale: { channel: 'assistant', text: 'ghost' } },
    );
    expect(turns[0]?.items.map((item) => item.kind)).toEqual(['turn-end']);
  });

  it('keeps turns separate', () => {
    const turns = buildTimeline(
      journal([
        { type: 'user', text: 'one' },
        { type: 'turn.started', model: null },
        { type: 'turn.finished', outcome: 'completed', detail: null, durationMs: 5, usage: null },
        { type: 'user', text: 'two', turn: 2 },
        { type: 'turn.started', model: null, turn: 2 },
      ]),
    );
    expect(turns.map((turn) => [turn.turn, turn.open])).toEqual([
      [1, false],
      [2, true],
    ]);
  });
});

describe('formatting', () => {
  it('formats durations and token counts compactly', () => {
    expect(formatDuration(null)).toBe('');
    expect(formatDuration(450)).toBe('450 ms');
    expect(formatDuration(12_400)).toBe('12s');
    expect(formatDuration(125_000)).toBe('2m 05s');
    expect(formatTokens(856)).toBe('856');
    expect(formatTokens(1_250)).toBe('1.3k');
    expect(formatTokens(135_859)).toBe('136k');
    expect(formatTokens(2_400_000)).toBe('2.4M');
  });
});
