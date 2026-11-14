import { useEffect, useMemo, useRef, type ReactNode } from 'react';
import { useLocation, useNavigate } from 'react-router';
import { useBackend } from '../data/backend';
import { currentDesktopPreferences, rememberRoute } from './desktopPreferences';
import { HOME_PATH } from './home';

const KNOWN = new Set([
  '/world',
  '/focus',
  '/projects',
  '/people',
  '/library',
  '/context',
  '/operations',
  '/settings',
  '/terminal',
  '/office',
  '/attention',
  '/insights',
]);

/** Restores internal navigation per workspace, while the supervised backend remains authoritative. */
export function NavigationContinuity({ children }: { children: ReactNode }) {
  const { backend } = useBackend();
  const workspace = backend?.harness?.path ?? '';
  const location = useLocation();
  const navigate = useNavigate();
  const previousWorkspace = useRef<string | null>(null);
  const params = useMemo(() => new URLSearchParams(location.search), [location.search]);
  const storedWorkspace = params.get('workspace');
  const workspaceChanged = previousWorkspace.current !== null && previousWorkspace.current !== workspace;
  const needsRestore = Boolean(workspace) && (location.pathname === '/' || workspaceChanged);
  const staleScope = Boolean(workspace && storedWorkspace && storedWorkspace !== workspace);

  useEffect(() => {
    if (!workspace) return;
    previousWorkspace.current = workspace;
    if (needsRestore) {
      const saved = currentDesktopPreferences().routes[workspace];
      const path = saved && KNOWN.has(saved.pathname) ? saved.pathname : HOME_PATH;
      const restored = new URLSearchParams(saved?.search ?? '');
      restored.set('workspace', workspace);
      navigate({ pathname: path, search: restored.toString() }, { replace: true });
      return;
    }
    const next = new URLSearchParams(location.search);
    if (staleScope) {
      next.delete('project');
      next.delete('thread');
      next.delete('pty');
    }
    next.set('workspace', workspace);
    const search = next.toString();
    if (staleScope || search !== params.toString()) {
      navigate({ pathname: location.pathname, search }, { replace: true });
      return;
    }
    const safe = new URLSearchParams();
    for (const key of ['project', 'thread'] as const) {
      const value = params.get(key);
      if (value && /^[\w.@-]{1,256}$/.test(value)) safe.set(key, value);
    }
    const current = currentDesktopPreferences().routes[workspace];
    const focusThread = location.pathname === '/focus' ? (params.get('thread') ?? undefined) : current?.focusThread;
    rememberRoute(workspace, {
      pathname: KNOWN.has(location.pathname) ? location.pathname : HOME_PATH,
      search: `?${safe.toString()}`,
      ...(focusThread && /^[\w.@-]{1,256}$/.test(focusThread) ? { focusThread } : {}),
    });
  }, [workspace, location.pathname, location.search, staleScope, needsRestore, navigate, params]);

  // Keep stale project/session views from flashing under a newly selected workspace.
  if (needsRestore || staleScope)
    return (
      <div role="status" aria-live="polite">
        Opening workspace…
      </div>
    );
  return children;
}
