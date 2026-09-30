export interface BackoffOptions {
  baseMs?: number;
  maxMs?: number;
  /** 0..1 fraction of the delay randomized downward, so clients do not reconnect in lockstep. */
  jitter?: number;
  random?: () => number;
}

/** Exponential reconnect delay: base * 2^attempt, capped, with downward jitter. */
export function backoffDelay(attempt: number, options: BackoffOptions = {}): number {
  const { baseMs = 1_000, maxMs = 30_000, jitter = 0.25, random = Math.random } = options;
  const exponential = Math.min(maxMs, baseMs * 2 ** Math.max(0, attempt));
  return Math.round(exponential * (1 - jitter * random()));
}
