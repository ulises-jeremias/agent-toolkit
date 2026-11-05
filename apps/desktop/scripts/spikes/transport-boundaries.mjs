// #1669: hermetic transport-boundary comparison, NOT a provider adapter.
// Both shapes feed the same app-owned projection. No provider capabilities inferred.
import { SessionProjection } from './session-projection.mjs';

const terminalStatuses = new Set(['root_completed', 'root_failed', 'cancelled', 'interrupted']);

function requireTerminal(projection) {
  if (!terminalStatuses.has(projection.status)) throw new Error('transport ended before root terminal event');
  return projection;
}

export async function consumePull({ events, ids, signal }) {
  const projection = new SessionProjection(ids);
  for await (const event of events) {
    if (signal?.aborted) throw new Error('transport cancelled');
    projection.apply(event);
  }
  if (signal?.aborted) throw new Error('transport cancelled');
  return requireTerminal(projection);
}

// Push sources must have a close/error signal; silence is NOT completion.
// subscribe(onEvent, onEnd, onError) returns an unsubscribe function.
export function consumePush({ subscribe, ids, signal }) {
  return new Promise((resolve, reject) => {
    const projection = new SessionProjection(ids);
    let settled = false;
    let unsubscribe = () => {};
    let pendingUnsubscribe = false;
    const cleanup = () => {
      signal?.removeEventListener('abort', onAbort);
      if (pendingUnsubscribe) unsubscribe();
      else pendingUnsubscribe = true;
    };
    const finish = (error) => {
      if (settled) return;
      settled = true;
      cleanup();
      if (error) reject(error);
      else {
        try { resolve(requireTerminal(projection)); } catch (incomplete) { reject(incomplete); }
      }
    };
    const onAbort = () => finish(new Error('transport cancelled'));
    if (signal?.aborted) return finish(new Error('transport cancelled'));
    signal?.addEventListener('abort', onAbort, { once: true });
    try {
      const teardown = subscribe(
        event => {
          if (settled) return;
          try { projection.apply(event); } catch (error) { finish(error); }
        },
        () => finish(),
        error => finish(error instanceof Error ? error : new Error('transport error'))
      );
      if (typeof teardown !== 'function') throw new Error('unsubscribe required');
      unsubscribe = teardown;
      if (pendingUnsubscribe) unsubscribe();
    } catch (error) {
      finish(error);
    }
  });
}
