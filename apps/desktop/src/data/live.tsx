import { useQueryClient } from '@tanstack/react-query';
import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { applyLiveEvent } from '../lib/live/applyEvent';
import { JobStreamManager, type EventSourceLike, type LiveSnapshot } from '../lib/live/jobStreams';
import { useBackend, useHealth } from './backend';
import { activeJobIds, useJobs } from './jobs';

export type ConnectionState = 'connecting' | 'online' | 'offline';

export interface LiveStatus {
  /** HTTP backend reachability from the health poll. */
  connection: ConnectionState;
  /** Job event streams. */
  streams: LiveSnapshot;
  /** Epoch ms of the last successful health answer; what "stale since" means. */
  lastHealthyAt: number | null;
}

const IDLE: LiveSnapshot = { state: 'idle', streams: 0, nextRetryAt: null };

const LiveContext = createContext<LiveStatus>({ connection: 'connecting', streams: IDLE, lastHealthyAt: null });

export function useLiveStatus(): LiveStatus {
  return useContext(LiveContext);
}

function defaultSource(url: string): EventSourceLike {
  return new EventSource(url);
}

/**
 * Mounted once in the shell. Streams every active job into the Query cache
 * regardless of which destination is open, so Office, Operations and the
 * dock read the same live state.
 */
export function LiveProvider({
  children,
  createSource = defaultSource,
}: {
  children: ReactNode;
  createSource?: (url: string) => EventSourceLike;
}) {
  const queryClient = useQueryClient();
  const { client } = useBackend();
  const health = useHealth();
  const jobs = useJobs();
  const [streams, setStreams] = useState<LiveSnapshot>(IDLE);

  const manager = useMemo(() => {
    if (!client) return null;
    return new JobStreamManager({
      urlFor: (id) => client.jobEventsUrl(id),
      createSource,
      onEvent: (event) => applyLiveEvent(queryClient, event),
      onSnapshot: setStreams,
    });
  }, [client, createSource, queryClient]);

  useEffect(() => {
    if (!manager) return;
    return () => {
      manager.dispose();
      setStreams(IDLE);
    };
  }, [manager]);

  const connection: ConnectionState = health.isError ? 'offline' : health.isSuccess ? 'online' : 'connecting';

  useEffect(() => {
    manager?.setOffline(connection === 'offline');
  }, [manager, connection]);

  const activeKey = activeJobIds(jobs.data).sort().join('\n');
  useEffect(() => {
    manager?.sync(activeKey === '' ? [] : activeKey.split('\n'));
  }, [manager, activeKey]);

  const lastHealthyAt = health.dataUpdatedAt > 0 ? health.dataUpdatedAt : null;
  const value = useMemo<LiveStatus>(
    () => ({ connection, streams, lastHealthyAt }),
    [connection, streams, lastHealthyAt],
  );

  return <LiveContext.Provider value={value}>{children}</LiveContext.Provider>;
}
