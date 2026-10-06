/**
 * Session continuity: workspace, agent and run live in the URL so every
 * destination, reload and shared link keeps the same scope.
 *
 * `workspace` is seeded from the supervised harness (`backend-status` IPC)
 * when the URL does not already name one. Changing it here does not restart
 * the backend — serve is cwd-rooted; a later picker can call restart.
 */

export const CONTEXT_KEYS = ['workspace', 'agent', 'run'] as const;

export type ContextKey = (typeof CONTEXT_KEYS)[number];

export interface SessionContext {
  workspace: string;
  agent: string;
  run: string;
}

export const EMPTY_CONTEXT: SessionContext = { workspace: '', agent: '', run: '' };

export function readContext(params: URLSearchParams): SessionContext {
  return {
    workspace: params.get('workspace') ?? '',
    agent: params.get('agent') ?? '',
    run: params.get('run') ?? '',
  };
}

export function writeContext(params: URLSearchParams, patch: Partial<SessionContext>): URLSearchParams {
  const next = new URLSearchParams(params);
  for (const key of CONTEXT_KEYS) {
    if (!(key in patch)) continue;
    const value = patch[key]?.trim() ?? '';
    if (value) next.set(key, value);
    else next.delete(key);
  }
  return next;
}

/** Destination path plus session context, and any extra view params (`job`, `pty`, …). */
export function withContext(
  path: string,
  context: SessionContext,
  extra: Record<string, string | undefined> = {},
): string {
  const params = new URLSearchParams();
  for (const key of CONTEXT_KEYS) {
    const value = context[key].trim();
    if (value) params.set(key, value);
  }
  for (const [key, value] of Object.entries(extra)) {
    if (value) params.set(key, value);
    else params.delete(key);
  }
  const query = params.toString();
  return query ? `${path}?${query}` : path;
}

export function basename(path: string): string {
  const trimmed = path.replace(/[/\\]+$/, '');
  const parts = trimmed.split(/[/\\]/).filter(Boolean);
  return parts[parts.length - 1] ?? path;
}

export function displayLocationName(path: string): string {
  const name = basename(path);
  return name.toLowerCase() === '.ai-workspace' ? 'AI Workspace' : name;
}

/** Prefer a compact location label at rest; focusing the field reveals its full editable path. */
export function displayWorkspacePath(path: string, harnessPath: string, isDefaultHarness: boolean): string {
  if (!path) return '';
  if (isDefaultHarness && path === harnessPath) return 'AI Workspace';
  return displayLocationName(path);
}
