/**
 * The shell context (workspace, agent, run) lives in URL search params so
 * every destination, reload and copied link keeps it. Pure helpers here; the
 * React hook is in shell/context.ts.
 */

export const CONTEXT_PARAMS = ['ws', 'agent', 'run'] as const;
export type ContextParam = (typeof CONTEXT_PARAMS)[number];

export interface ShellContextValue {
  /** Workspace folder override; null means the backend's own workspace. */
  ws: string | null;
  /** Free-form agent label, e.g. "claude" or "reviewer". */
  agent: string | null;
  /** Job id in focus. */
  run: string | null;
}

export const EMPTY_CONTEXT: ShellContextValue = { ws: null, agent: null, run: null };

export function readContext(params: URLSearchParams): ShellContextValue {
  const value = (key: ContextParam) => {
    const raw = params.get(key)?.trim();
    return raw ? raw : null;
  };
  return { ws: value('ws'), agent: value('agent'), run: value('run') };
}

/** Apply a patch to params: null or empty clears a key; other params are kept. */
export function patchContext(params: URLSearchParams, patch: Partial<ShellContextValue>): URLSearchParams {
  const next = new URLSearchParams(params);
  for (const key of CONTEXT_PARAMS) {
    if (!(key in patch)) continue;
    const value = patch[key]?.trim();
    if (value) next.set(key, value);
    else next.delete(key);
  }
  return next;
}

/** `?ws=…&agent=…&run=…` for links to another destination (context only). */
export function contextSearch(context: ShellContextValue): string {
  const params = patchContext(new URLSearchParams(), context);
  const text = params.toString();
  return text ? `?${text}` : '';
}

export function hasContext(context: ShellContextValue): boolean {
  return CONTEXT_PARAMS.some((key) => context[key] !== null);
}
