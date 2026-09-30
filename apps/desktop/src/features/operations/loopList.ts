import type { CommandEnvelope } from '../../lib/api';

export interface LoopListEntry {
  name: string;
  meta: string;
  source: 'installed' | 'template';
}

const EMPTY_LIST = /no loops found/i;

/** Parse `loop list` / `loop templates` CLI lines. Names come from the report; nothing is invented. */
export function parseLoopNames(envelope: CommandEnvelope, source: LoopListEntry['source']): LoopListEntry[] {
  if (EMPTY_LIST.test(envelope.message)) return [];
  const entries: LoopListEntry[] = [];
  for (const raw of envelope.message.split('\n')) {
    const line = raw.trim();
    if (!line) continue;
    const [name, ...rest] = line.split('\t');
    if (!name || name.includes(' ')) continue;
    entries.push({ name, meta: rest.join('\t').trim(), source });
  }
  return entries;
}
