import { useCallback, useEffect, useMemo } from 'react';
import { useSearchParams } from 'react-router';
import { useBackend } from '../data/backend';
import { readContext, withContext, writeContext, type SessionContext } from './sessionContext';

export interface SessionContextApi {
  context: SessionContext;
  setContext: (patch: Partial<SessionContext>) => void;
  href: (path: string, extra?: Record<string, string | undefined>) => string;
}

/**
 * URL-backed session scope. Seeds `workspace` from the harness once, then
 * leaves the URL as the source of truth so navigation never drops it.
 */
export function useSessionContext(): SessionContextApi {
  const [params, setParams] = useSearchParams();
  const { backend } = useBackend();
  const harnessPath = backend?.harness?.path ?? '';
  const workspaceParam = params.get('workspace');

  useEffect(() => {
    if (!harnessPath || workspaceParam) return;
    setParams(
      (current) => {
        if (current.get('workspace')) return current;
        return writeContext(current, { workspace: harnessPath });
      },
      { replace: true },
    );
  }, [harnessPath, workspaceParam, setParams]);

  const context = useMemo(() => readContext(params), [params]);

  const setContext = useCallback(
    (patch: Partial<SessionContext>) => {
      setParams((current) => writeContext(current, patch), { replace: true });
    },
    [setParams],
  );

  const href = useCallback(
    (path: string, extra: Record<string, string | undefined> = {}) => withContext(path, context, extra),
    [context],
  );

  return { context, setContext, href };
}
