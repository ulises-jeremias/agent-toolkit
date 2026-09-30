/** Command palette ranking. Pure so the ordering is testable. */

export interface PaletteEntry {
  id: string;
  label: string;
  group: string;
  /** Extra words that should match, e.g. a destination's question. */
  keywords?: readonly string[];
}

function score(entry: PaletteEntry, terms: string[]): number | null {
  const label = entry.label.toLowerCase();
  const haystack = [label, entry.group, ...(entry.keywords ?? [])].join(' ').toLowerCase();
  let total = 0;
  for (const term of terms) {
    if (label.startsWith(term)) total += 3;
    else if (new RegExp(`\\b${term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`).test(label)) total += 2;
    else if (haystack.includes(term)) total += 1;
    else return null;
  }
  return total;
}

/**
 * Every whitespace-separated term must appear. Label prefix beats word
 * start beats anywhere; ties keep the original (curated) order.
 */
export function rankEntries<T extends PaletteEntry>(entries: readonly T[], query: string): T[] {
  const terms = query.trim().toLowerCase().split(/\s+/).filter(Boolean);
  if (terms.length === 0) return [...entries];
  return entries
    .map((entry, index) => ({ entry, index, score: score(entry, terms) }))
    .filter((item): item is { entry: T; index: number; score: number } => item.score !== null)
    .sort((a, b) => b.score - a.score || a.index - b.index)
    .map((item) => item.entry);
}
