import type { FocusApprovalDecision, FocusEvent, FocusToolKind, FocusUsage } from '../../types/focus';

/**
 * Pure projection from the journal (plus live-only deltas) to what Focus
 * draws. Nothing here invents state: a tool is "running" only between its
 * start event and the end of its turn, and a turn is open only until its
 * `turn.finished` event.
 */

export interface LiveText {
  channel: 'assistant' | 'reasoning';
  text: string;
}

export type ToolState = 'running' | 'awaiting-approval' | 'ok' | 'failed' | 'denied' | 'cancelled';

export interface ToolItem {
  kind: 'tool';
  key: string;
  itemId: string;
  name: string;
  toolKind: FocusToolKind;
  title: string;
  input: unknown;
  state: ToolState;
  output: string;
  truncated: boolean;
  approval: {
    requestId: string;
    state: 'pending' | FocusApprovalDecision;
    by: 'user' | 'interrupt' | 'shutdown' | null;
    canAllowForSession: boolean;
  } | null;
  /** Calls made by a provider-native subagent started by this tool. */
  children: ToolItem[];
}

export type TimelineItem =
  | { kind: 'user'; key: string; text: string; at: string }
  | { kind: 'assistant'; key: string; text: string; streaming: boolean }
  | { kind: 'reasoning'; key: string; text: string; streaming: boolean }
  | ToolItem
  | { kind: 'notice'; key: string; level: 'info' | 'warning' | 'error'; text: string }
  | {
      kind: 'turn-end';
      key: string;
      outcome: 'completed' | 'interrupted' | 'failed';
      detail: string | null;
      durationMs: number | null;
      usage: FocusUsage | null;
    };

export interface TimelineTurn {
  turn: number;
  open: boolean;
  items: TimelineItem[];
}

export function buildTimeline(
  events: readonly FocusEvent[],
  live: Readonly<Record<string, LiveText>> = {},
): TimelineTurn[] {
  const turns: TimelineTurn[] = [];
  const tools = new Map<string, ToolItem>();
  const approvals = new Map<string, ToolItem>();
  const committed = new Set<string>();

  const turnFor = (number: number): TimelineTurn => {
    const last = turns.at(-1);
    if (last && last.turn === number) return last;
    const created: TimelineTurn = { turn: number, open: false, items: [] };
    turns.push(created);
    return created;
  };

  for (const event of events) {
    const turn = turnFor(event.turn);
    const key = `e${event.seq}`;
    switch (event.type) {
      case 'user':
        turn.items.push({ kind: 'user', key, text: event.text, at: event.at });
        break;
      case 'turn.started':
        turn.open = true;
        break;
      case 'assistant':
      case 'reasoning':
        committed.add(event.itemId);
        turn.items.push({ kind: event.type, key: event.itemId, text: event.text, streaming: false });
        break;
      case 'tool.started': {
        const item: ToolItem = {
          kind: 'tool',
          key: event.itemId,
          itemId: event.itemId,
          name: event.name,
          toolKind: event.kind,
          title: event.title,
          input: event.input,
          state: 'running',
          output: '',
          truncated: false,
          approval: null,
          children: [],
        };
        tools.set(event.itemId, item);
        const parent = event.parentItemId ? tools.get(event.parentItemId) : undefined;
        if (parent) parent.children.push(item);
        else turn.items.push(item);
        break;
      }
      case 'tool.finished': {
        const item = tools.get(event.itemId);
        if (!item) break;
        item.output = event.output;
        item.truncated = event.truncated;
        item.state = item.approval?.state === 'deny' ? 'denied' : event.ok ? 'ok' : 'failed';
        break;
      }
      case 'approval.requested': {
        let item = event.itemId ? tools.get(event.itemId) : undefined;
        if (!item) {
          // The provider asked before announcing the call: draw the request on its own.
          item = {
            kind: 'tool',
            key: `approval-${event.requestId}`,
            itemId: event.itemId ?? `approval-${event.requestId}`,
            name: event.tool,
            toolKind: event.kind,
            title: event.title,
            input: event.input,
            state: 'running',
            output: '',
            truncated: false,
            approval: null,
            children: [],
          };
          tools.set(item.itemId, item);
          turn.items.push(item);
        }
        item.approval = {
          requestId: event.requestId,
          state: 'pending',
          by: null,
          canAllowForSession: event.canAllowForSession,
        };
        item.state = 'awaiting-approval';
        approvals.set(event.requestId, item);
        break;
      }
      case 'approval.resolved': {
        const item = approvals.get(event.requestId);
        if (!item?.approval) break;
        item.approval = { ...item.approval, state: event.decision, by: event.by };
        item.state = event.decision === 'deny' ? 'denied' : 'running';
        break;
      }
      case 'notice':
        turn.items.push({ kind: 'notice', key, level: event.level, text: event.text });
        break;
      case 'turn.finished': {
        turn.open = false;
        const settle = (item: TimelineItem): void => {
          if (item.kind !== 'tool') return;
          if (item.state === 'running' || item.state === 'awaiting-approval') item.state = 'cancelled';
          item.children.forEach(settle);
        };
        turn.items.forEach(settle);
        turn.items.push({
          kind: 'turn-end',
          key,
          outcome: event.outcome,
          detail: event.detail,
          durationMs: event.durationMs,
          usage: event.usage,
        });
        break;
      }
    }
  }

  const last = turns.at(-1);
  if (last?.open) {
    for (const [itemId, text] of Object.entries(live)) {
      if (committed.has(itemId) || !text.text) continue;
      last.items.push({ kind: text.channel, key: itemId, text: text.text, streaming: true });
    }
  }
  return turns;
}

/** The approval the user must answer now, if any (oldest first). */
export function pendingApproval(turns: readonly TimelineTurn[]): ToolItem | null {
  const last = turns.at(-1);
  if (!last?.open) return null;
  const find = (items: readonly TimelineItem[]): ToolItem | null => {
    for (const item of items) {
      if (item.kind !== 'tool') continue;
      if (item.approval?.state === 'pending') return item;
      const nested = find(item.children);
      if (nested) return nested;
    }
    return null;
  };
  return find(last.items);
}

export function formatDuration(ms: number | null): string {
  if (ms === null) return '';
  if (ms < 1_000) return `${ms} ms`;
  const seconds = Math.round(ms / 1_000);
  if (seconds < 60) return `${seconds}s`;
  return `${Math.floor(seconds / 60)}m ${String(seconds % 60).padStart(2, '0')}s`;
}

export function formatTokens(count: number): string {
  if (count < 1_000) return String(count);
  if (count < 1_000_000) return `${(count / 1_000).toFixed(count < 10_000 ? 1 : 0)}k`;
  return `${(count / 1_000_000).toFixed(1)}M`;
}
