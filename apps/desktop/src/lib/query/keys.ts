import type { ReportKind, SubBody, SubCommand, SubFamily } from '../api';

/**
 * Query-key factory. Every key starts with its domain so a mutation can
 * invalidate a whole domain (`qk.domain('skills')`) without touching others.
 * Keys that depend on request scope (workspace, filters) carry the body, so
 * switching workspace never serves another workspace's cached answer.
 */
export type Domain = 'backend' | 'jobs' | 'inventory' | 'doctor' | 'matrix' | 'diff' | 'insights' | SubFamily;

export const qk = {
  domain: (domain: Domain) => [domain] as const,

  backend: {
    health: () => ['backend', 'health'] as const,
    version: () => ['backend', 'version'] as const,
    selfcheck: () => ['backend', 'selfcheck'] as const,
    help: () => ['backend', 'help'] as const,
  },

  jobs: {
    list: () => ['jobs', 'list'] as const,
    log: (id: string) => ['jobs', 'log', id] as const,
    /** Lines received over SSE for one job; written only by the live bridge. */
    live: (id: string) => ['jobs', 'live', id] as const,
  },

  report: (kind: ReportKind) => [kind, 'report'] as const,

  sub: <F extends SubFamily>(family: F, sub: SubCommand<F>, body?: SubBody<F>) =>
    [family, 'sub', sub, body ?? {}] as const,
};
