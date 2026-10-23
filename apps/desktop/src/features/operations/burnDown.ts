/**
 * Burn-down math for a loop's recorded runs (#1102). Pure and honest:
 * every point comes from tokens the backend read out of the run's own
 * trace; runs whose traces recorded no usage contribute 0, and the
 * budget line is the loop's declared max_tokens — nothing is estimated.
 */
export interface BurnDownPoint {
  id: string;
  /** Tokens this run recorded. */
  spent: number;
  /** Cumulative spend including this run. */
  cumulative: number;
  /** Budget left after this run; negative once over budget. */
  left: number;
  over: boolean;
}

export function burnDownPoints(runs: readonly { id: string; tokens: number }[], maxTokens: number): BurnDownPoint[] {
  let cumulative = 0;
  return runs.map((run) => {
    cumulative += run.tokens;
    const left = maxTokens - cumulative;
    return { id: run.id, spent: run.tokens, cumulative, left, over: left < 0 };
  });
}

/** Bar height as a percentage of the budget; clamped for display only. */
export function burnDownBarPercent(point: BurnDownPoint, maxTokens: number): number {
  if (maxTokens <= 0) return 0;
  const clamped = Math.min(Math.max(point.left, 0), maxTokens);
  return (clamped / maxTokens) * 100;
}
