import { useCallback, useMemo } from 'react';
import { useNavigate, useSearchParams, type To } from 'react-router';
import { contextSearch, patchContext, readContext, type ShellContextValue } from '../lib/context';

export interface ShellContext extends ShellContextValue {
  /** Update context params in place (current destination, other params kept). */
  setContext: (patch: Partial<ShellContextValue>) => void;
  /** A link target to another destination that carries the context along. */
  linkTo: (pathname: string, extra?: Record<string, string>) => To;
  /** Navigate to another destination carrying the context along. */
  goTo: (pathname: string, extra?: Record<string, string>) => void;
}

export function useShellContext(): ShellContext {
  const [params, setParams] = useSearchParams();
  const navigate = useNavigate();
  const context = useMemo(() => readContext(params), [params]);

  const setContext = useCallback(
    (patch: Partial<ShellContextValue>) => setParams((current) => patchContext(current, patch)),
    [setParams],
  );

  const linkTo = useCallback(
    (pathname: string, extra?: Record<string, string>): To => {
      const search = new URLSearchParams(contextSearch(context));
      for (const [key, value] of Object.entries(extra ?? {})) search.set(key, value);
      const text = search.toString();
      return { pathname, search: text ? `?${text}` : '' };
    },
    [context],
  );

  const goTo = useCallback(
    (pathname: string, extra?: Record<string, string>) => navigate(linkTo(pathname, extra)),
    [navigate, linkTo],
  );

  return { ...context, setContext, linkTo, goTo };
}
