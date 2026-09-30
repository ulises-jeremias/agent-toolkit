import type { Job } from './api';

function parse(iso: string): number | null {
  if (!iso) return null;
  const ms = Date.parse(iso);
  return Number.isNaN(ms) ? null : ms;
}

/** "14:02" today, "Sep 28 14:02" otherwise; the raw value when unparseable. */
export function formatWhen(iso: string, now: number = Date.now()): string {
  const ms = parse(iso);
  if (ms === null) return iso || '—';
  const date = new Date(ms);
  const time = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  if (new Date(now).toDateString() === date.toDateString()) return time;
  return `${date.toLocaleDateString([], { month: 'short', day: 'numeric' })} ${time}`;
}

export function formatDuration(ms: number): string {
  if (ms < 1_000) return `${Math.max(0, Math.round(ms))} ms`;
  const seconds = Math.round(ms / 1_000);
  if (seconds < 60) return `${seconds} s`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes} min ${seconds % 60} s`;
  return `${Math.floor(minutes / 60)} h ${minutes % 60} min`;
}

/** Wall time of a job; running jobs measure up to `now`. Null when start is unknown. */
export function jobDuration(job: Job, now: number = Date.now()): number | null {
  const start = parse(job.started_at);
  if (start === null) return null;
  const end = parse(job.ended_at) ?? now;
  return end - start;
}

/** The command as the user would type it. The V registry stores the subcommand again as args[0]. */
export function jobCommandLine(job: Job): string {
  const args = job.args[0] === job.cmd ? job.args.slice(1) : job.args;
  return ['agent-toolkit', job.cmd, ...args].join(' ');
}
