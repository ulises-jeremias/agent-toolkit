import type { ConnectionState } from '../../data/live';
import { isTerminalJobStatus, type Job, type SelfcheckCheck, type SelfcheckResponse } from '../../lib/api';
import { backendBannerCopy } from '../../lib/backend-copy';
import { jobCommandLine } from '../../lib/format';
import type { BackendState } from '../../types/electron';

export type HrefFn = (path: string, extra?: Record<string, string | undefined>) => string;

/** Stable destination the semantic world opens as an inspector, not as home. */
export const INSPECTOR_PATH = '/office';

/** Query key world/palette use to focus one attention item. */
export const INSPECT_PARAM = 'inspect';

/** Open the attention inspector, optionally focused on one item key. */
export function inspectorHref(href: HrefFn, inspect?: string): string {
  return inspect ? href(INSPECTOR_PATH, { [INSPECT_PARAM]: inspect }) : href(INSPECTOR_PATH);
}

/** True when `inspect` (from the URL) names this row. Accepts item keys or a raw job id. */
export function matchesInspect(key: string, inspect: string | null | undefined): boolean {
  if (!inspect) return false;
  if (key === inspect) return true;
  const keyTail = inspectTail(key);
  const inspectTailValue = inspectTail(inspect);
  return keyTail === inspect || inspectTailValue === key || keyTail === inspectTailValue;
}

function inspectTail(value: string): string {
  for (const prefix of ['job-', 'failed-', 'running-', 'check-']) {
    if (value.startsWith(prefix)) return value.slice(prefix.length);
  }
  return value;
}

export type AttentionKind = 'crash' | 'mismatch' | 'offline' | 'harness' | 'failed-job' | 'selfcheck';

export interface AttentionItem {
  key: string;
  kind: AttentionKind;
  tone: 'err' | 'warn';
  title: string;
  detail: string;
  href: string;
  label: string;
}

export type NeedsMeKind = 'crash' | 'mismatch' | 'failed-job' | 'running-job' | 'completed-review';

export interface NeedsMeTarget {
  key: string;
  kind: NeedsMeKind;
  href: string;
}

export type QueryStatus = 'pending' | 'success' | 'error';

/**
 * TanStack Query keeps last `data` after a failed refetch. isError must win,
 * or an empty retained list looks like a proven-clear desk.
 */
export function queryAttentionStatus(isError: boolean, hasData: boolean, isPending: boolean): QueryStatus {
  if (isError) return 'error';
  if (hasData) return 'success';
  if (isPending) return 'pending';
  return 'error';
}

export interface AttentionInput {
  backend: BackendState | null;
  connection: ConnectionState;
  jobs: readonly Job[] | undefined;
  jobsStatus: QueryStatus;
  selfcheck: SelfcheckResponse | undefined;
  selfcheckStatus: QueryStatus;
  href: HrefFn;
}

const FAILED_STATUSES = new Set(['failed', 'rejected']);

export function isFailedJob(job: Job): boolean {
  return FAILED_STATUSES.has(job.status);
}

export function runningJobs(jobs: readonly Job[]): Job[] {
  return jobs.filter((job) => !isTerminalJobStatus(job.status));
}

export function failedJobs(jobs: readonly Job[]): Job[] {
  return jobs.filter(isFailedJob);
}

export function completedJobs(jobs: readonly Job[]): Job[] {
  return jobs.filter((job) => job.status === 'completed');
}

export function finishedJobs(jobs: readonly Job[]): Job[] {
  return jobs.filter((job) => isTerminalJobStatus(job.status) && !isFailedJob(job));
}

/**
 * Completed work that still needs a person. Approvals / review flags are
 * Phase 2 PR E — without them we cannot distinguish "needs review" from
 * "finished", so this stays empty rather than inventing a queue.
 */
export function completedNeedingReview(_jobs: readonly Job[]): Job[] {
  return [];
}

export function backendNeedsYou(backend: BackendState | null, connection: ConnectionState): boolean {
  if (!backend) return connection === 'offline';
  return (
    backend.status === 'crashed' ||
    backend.status === 'failed' ||
    backend.status === 'stopped' ||
    backend.status === 'version-mismatch' ||
    connection === 'offline'
  );
}

function failingChecks(selfcheck: SelfcheckResponse | undefined): SelfcheckCheck[] {
  return (selfcheck?.checks ?? []).filter((check) => check.status !== 'ok');
}

/** Failures and blocked work a person must act on. Running work is not here. */
export function collectAttention(input: AttentionInput): AttentionItem[] {
  const items: AttentionItem[] = [];
  const { backend, connection, href } = input;

  if (backend?.status === 'crashed' || backend?.status === 'failed' || backend?.status === 'stopped') {
    items.push({
      key: 'backend-crash',
      kind: 'crash',
      tone: 'err',
      title: `Backend ${backend.status}`,
      detail: backendBannerCopy(backend),
      href: href('/settings'),
      label: 'Open backend settings',
    });
  } else if (backend?.status === 'version-mismatch') {
    items.push({
      key: 'backend-mismatch',
      kind: 'mismatch',
      tone: 'warn',
      title: 'Backend version mismatch',
      detail: backendBannerCopy(backend),
      href: href('/settings'),
      label: 'Open backend settings',
    });
  } else if (connection === 'offline') {
    items.push({
      key: 'backend-offline',
      kind: 'offline',
      tone: 'err',
      title: 'Backend not answering',
      detail: 'Jobs and self-checks cannot refresh until it answers.',
      href: href('/settings'),
      label: 'Open backend settings',
    });
  }

  if (backend?.harness?.notice) {
    items.push({
      key: 'harness',
      kind: 'harness',
      tone: 'warn',
      title: backend.harness.source === 'fallback' ? 'Harness not found' : 'Harness override ignored',
      detail: backend.harness.notice,
      href: href('/settings'),
      label: 'See harness',
    });
  }

  for (const job of failedJobs(input.jobs ?? [])) {
    items.push({
      key: `job-${job.id}`,
      kind: 'failed-job',
      tone: 'err',
      title: `${job.cmd} ${job.status}`,
      detail: `${jobCommandLine(job)} · exit ${job.exit_code}`,
      href: href('/operations', { job: job.id }),
      label: 'Review job',
    });
  }

  for (const check of failingChecks(input.selfcheck)) {
    items.push({
      key: `check-${check.name}`,
      kind: 'selfcheck',
      tone: check.status === 'err' ? 'err' : 'warn',
      title: `Self-check: ${check.name}`,
      detail: check.detail,
      href: href('/settings'),
      label: 'See self-check',
    });
  }

  return items;
}

/**
 * Palette cycle: crash/mismatch → failed jobs → running jobs → completed
 * needing review when that is distinguishable. Current harness only.
 */
export function collectNeedsMe(input: AttentionInput): NeedsMeTarget[] {
  const targets: NeedsMeTarget[] = [];
  const { backend, connection, href } = input;

  if (backend?.status === 'crashed' || backend?.status === 'failed' || backend?.status === 'stopped') {
    targets.push({ key: 'backend-crash', kind: 'crash', href: href('/settings') });
  } else if (backend?.status === 'version-mismatch') {
    targets.push({ key: 'backend-mismatch', kind: 'mismatch', href: href('/settings') });
  } else if (connection === 'offline') {
    targets.push({ key: 'backend-offline', kind: 'crash', href: href('/settings') });
  }

  for (const job of failedJobs(input.jobs ?? [])) {
    targets.push({ key: `failed-${job.id}`, kind: 'failed-job', href: href('/operations', { job: job.id }) });
  }
  for (const job of runningJobs(input.jobs ?? [])) {
    targets.push({ key: `running-${job.id}`, kind: 'running-job', href: href('/operations', { job: job.id }) });
  }
  for (const job of completedNeedingReview(input.jobs ?? [])) {
    targets.push({
      key: `review-${job.id}`,
      kind: 'completed-review',
      href: href('/operations', { job: job.id }),
    });
  }
  return targets;
}

export type AttentionVacancy = { kind: 'gathering' } | { kind: 'unknown'; reason: string } | { kind: 'clear' };

/**
 * Empty "needs you" is only allowed after we have proven the backend is up
 * and the job list loaded. A crash or a failed query is never "quiet".
 */
export function attentionVacancy(input: AttentionInput, items: readonly AttentionItem[]): AttentionVacancy {
  if (items.length > 0) return { kind: 'clear' };
  if (backendNeedsYou(input.backend, input.connection)) {
    return { kind: 'unknown', reason: 'The backend is not in a state we can call clear.' };
  }
  if (input.jobsStatus === 'pending' || input.selfcheckStatus === 'pending') return { kind: 'gathering' };
  if (input.jobsStatus === 'error') {
    return { kind: 'unknown', reason: 'The job list did not load, so failures may be hidden.' };
  }
  if (input.selfcheckStatus === 'error') {
    return { kind: 'unknown', reason: 'Self-check did not load.' };
  }
  return { kind: 'clear' };
}

export function officeLede(input: AttentionInput, items: readonly AttentionItem[]): string {
  const jobs = input.jobs ?? [];
  const running = runningJobs(jobs).length;
  const failed = failedJobs(jobs).length;
  const completed = completedJobs(jobs).length;
  const parts: string[] = [];

  if (input.backend?.status === 'crashed' || input.backend?.status === 'failed') {
    parts.push(`The backend ${input.backend.status}.`);
  } else if (input.backend?.status === 'stopped') {
    parts.push('The backend is stopped.');
  } else if (input.backend?.status === 'version-mismatch') {
    parts.push('The backend version does not match this Desktop.');
  } else if (input.connection === 'offline') {
    parts.push('The backend is not answering.');
  }

  if (input.jobsStatus === 'error' && parts.length === 0) {
    parts.push('The job list did not load.');
  }
  if (input.jobsStatus === 'success') {
    if (running) parts.push(`${running} ${running === 1 ? 'job is' : 'jobs are'} running.`);
    else parts.push('No work is running.');
    if (failed) parts.push(`${failed} ${failed === 1 ? 'job failed' : 'jobs failed'}.`);
    if (completed) parts.push(`${completed} completed.`);
  }
  if (items.length === 0 && attentionVacancy(input, items).kind === 'clear' && failed === 0) {
    parts.push('Nothing needs you. No failed jobs and every self-check passes.');
  } else if (items.length > 0 && !parts.some((part) => part.includes('failed') || part.includes('backend'))) {
    parts.unshift(`${items.length} ${items.length === 1 ? 'item needs' : 'items need'} you.`);
  }
  return parts.join(' ') || 'Checking the current harness.';
}

export interface NextAction {
  key: string;
  href: string;
  label: string;
  detail: string;
}

export function nextActions(input: AttentionInput, items: readonly AttentionItem[]): NextAction[] {
  const actions: NextAction[] = [];
  const seen = new Set<string>();
  const add = (action: NextAction) => {
    if (seen.has(action.key)) return;
    seen.add(action.key);
    actions.push(action);
  };

  for (const item of items) {
    add({ key: item.key, href: item.href, label: item.label, detail: item.title });
  }
  const running = runningJobs(input.jobs ?? []);
  if (running[0]) {
    add({
      key: `watch-${running[0].id}`,
      href: input.href('/operations', { job: running[0].id }),
      label: 'Open running job',
      detail: jobCommandLine(running[0]),
    });
  }
  add({
    key: 'start-job',
    href: input.href('/operations'),
    label: 'Start a job',
    detail: 'Run an agent-toolkit command in Operations.',
  });
  add({
    key: 'terminal',
    href: input.href('/terminal'),
    label: 'Open Terminal',
    detail: 'Work in a PTY with the current workspace.',
  });
  add({
    key: 'insights',
    href: input.href('/insights'),
    label: 'Open Insights',
    detail: 'Doctor and measured history.',
  });
  return actions.slice(0, 5);
}

let lastNeedsMeKey = '';

export function resetNeedsMeCursor(): void {
  lastNeedsMeKey = '';
}

/** Cycle through needs-me targets. First call lands on the first target. */
export function takeNextNeedsMe(targets: readonly NeedsMeTarget[]): NeedsMeTarget | null {
  if (targets.length === 0) return null;
  const index = targets.findIndex((target) => target.key === lastNeedsMeKey);
  const next = targets[(index + 1) % targets.length];
  if (!next) return null;
  lastNeedsMeKey = next.key;
  return next;
}
