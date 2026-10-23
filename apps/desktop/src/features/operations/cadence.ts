/**
 * Cadence contract mirrored from the backend (`cadence_to_cron`):
 * `<N>m` 1-59, `<N>h` 1-24, `<N>d`, `1w`. The server re-validates on
 * save; this module exists so the editor can validate and preview
 * without a round trip. Preview times are interval estimates from
 * now — an installed OS schedule may align its fires differently.
 */
const UNIT_SECONDS: Record<string, number> = { m: 60, h: 3_600, d: 86_400, w: 604_800 };

export function cadenceIntervalSeconds(cadence: string): number | null {
  const c = cadence.trim();
  if (c.length < 2) return null;
  const unit = c[c.length - 1] ?? '';
  const numPart = c.slice(0, -1);
  if (!/^\d+$/.test(numPart)) return null;
  const num = Number(numPart);
  if (!Number.isFinite(num) || num <= 0) return null;
  if (unit === 'm' && num > 59) return null;
  if (unit === 'h' && num > 24) return null;
  const seconds = UNIT_SECONDS[unit];
  if (seconds === undefined) return null;
  return num * seconds;
}

export function nextCadenceRuns(cadence: string, from: Date, count = 5): Date[] {
  const interval = cadenceIntervalSeconds(cadence);
  if (interval === null) return [];
  const start = from.getTime();
  return Array.from({ length: count }, (_, i) => new Date(start + interval * 1000 * (i + 1)));
}
