import { useCallback, useRef, useState } from 'react';
import type { ProviderSignInId } from '../../types/electron';

export interface ProviderSignInSession {
  provider: ProviderSignInId;
  sessionId: string;
}

/** Own the temporary PTY lifecycle shared by onboarding and Focus. */
export function useProviderSignIn(onRefresh: () => void | Promise<void>) {
  const [session, setSession] = useState<ProviderSignInSession | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [starting, setStarting] = useState<ProviderSignInId | null>(null);
  const startingRef = useRef(false);
  const bridge = window.atk;

  const start = useCallback(async (provider: ProviderSignInId) => {
    if (!window.atk || startingRef.current) return;
    startingRef.current = true;
    setError(null);
    setStarting(provider);
    try {
      const result = await window.atk.providerSignInStart(provider);
      if (!result.ok) {
        setError(
          result.error === 'unavailable'
            ? 'This provider sign-in is not available on this machine.'
            : 'Could not launch the sign-in process.',
        );
        return;
      }
      setSession({ provider, sessionId: result.sessionId });
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not start provider sign-in.');
    } finally {
      startingRef.current = false;
      setStarting(null);
    }
  }, []);

  const close = useCallback(
    async (candidate: ProviderSignInSession | null) => {
      if (!candidate) return;
      try {
        await bridge?.providerSignInFinish(candidate.sessionId);
        setSession((current) => (current?.sessionId === candidate.sessionId ? null : current));
        await onRefresh();
      } catch (cause) {
        setError(cause instanceof Error ? cause.message : 'Could not verify provider sign-in.');
      }
    },
    [bridge, onRefresh],
  );

  return { session, error, starting, start, close };
}
