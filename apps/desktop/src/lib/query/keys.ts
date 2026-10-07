import type { ReportKind, SubBody, SubCommand, SubFamily } from '../api';

/**
 * Query-key factory. Every key starts with its domain so a mutation can
 * invalidate a whole domain (`qk.domain('skills')`) without touching others.
 * Keys that depend on request scope (workspace, filters) carry the body, so
 * switching workspace never serves another workspace's cached answer.
 */
export type Domain =
  | 'backend'
  | 'jobs'
  | 'memory'
  | 'files'
  | 'inventory'
  | 'doctor'
  | 'matrix'
  | 'diff'
  | 'insights'
  | 'agents'
  | 'tools'
  | 'providers'
  | 'models'
  | 'projects'
  | SubFamily;

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

  memory: {
    list: (scope: Record<string, string> = {}) => ['memory', 'list', scope] as const,
    hits: (q: string, scope: Record<string, string> = {}) => ['memory', 'hits', q, scope] as const,
    file: (path: string, scope: Record<string, string> = {}) => ['memory', 'file', path, scope] as const,
  },

  files: {
    list: (path = '', depth = '', project = '') => ['files', 'list', project, path, depth] as const,
    hits: (q: string, project = '') => ['files', 'hits', project, q] as const,
    content: (path: string, project = '') => ['files', 'content', project, path] as const,
  },

  projects: {
    list: (workspace = '') => ['projects', 'list', workspace] as const,
  },

  report: (kind: ReportKind) => [kind, 'report'] as const,

  catalog: {
    agents: () => ['agents', 'list'] as const,
    tools: () => ['tools', 'list'] as const,
    providers: () => ['providers', 'list'] as const,
    models: () => ['models', 'list'] as const,
    mcp: () => ['mcp', 'providers'] as const,
    installReceipts: () => ['inventory', 'install-receipts'] as const,
  },

  loops: {
    list: () => ['loops', 'list'] as const,
    status: (name: string) => ['loops', 'status', name] as const,
    history: (name: string) => ['loops', 'history', name] as const,
    audit: (name: string) => ['loops', 'audit', name] as const,
    cost: (name: string) => ['loops', 'cost', name] as const,
  },

  swarms: {
    list: () => ['swarms', 'list'] as const,
    recipes: () => ['swarms', 'recipes'] as const,
    run: (id: string) => ['swarms', 'run', id] as const,
  },

  sub: <F extends SubFamily>(family: F, sub: SubCommand<F>, body?: SubBody<F>) =>
    [family, 'sub', sub, body ?? {}] as const,
};
