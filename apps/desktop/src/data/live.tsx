import { useQueryClient } from '@tanstack/react-query';
import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { applyBusEvent, applyLiveEvent } from '../lib/live/applyEvent';
import { EventBusManager } from '../lib/live/eventBus';
import { JobStreamManager, type EventSourceLike, type LiveSnapshot } from '../lib/live/jobStreams';
import { useBackend, useHealth } from './backend';
import { activeJobIds, useJobs } from './jobs';

export type ConnectionState = 'connecting' | 'online' | 'offline';

export interface LiveStatus {
  /** HTTP backend reachability from the health poll. */
  connection: ConnectionState;
  /** Per-job log streams (`GET /api/v1/jobs/{id}/events`). */
  streams: LiveSnapshot;
  /** Global bus (`GET /api/v1/events`). */
  bus: LiveSnapshot;
  /** Epoch ms of the last successful health answer; what "stale since" means. */
  lastHealthyAt: number | null;
}

const IDLE: LiveSnapshot = { state: 'idle', streams: 0, nextRetryAt: null };

const LiveContext = createContext<LiveStatus>({
  connection: 'connecting',
  streams: IDLE,
  bus: IDLE,
  lastHealthyAt: null,
});

export function useLiveStatus(): LiveStatus {
  return useContext(LiveContext);
}

function defaultSource(url: string): EventSourceLike {
  return new EventSource(url);
}

/** Operations-relevant families; memory.changed is not this destination's concern. */
const BUS_TYPES = 'backend.,job.,loop.,swarm.,install.';

/**
 * Mounted once in the shell. Streams every active job into the Query cache
 * and keeps one GET /api/v1/events bus so Office, Operations and the dock
 * read the same live state.
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
  const [bus, setBus] = useState<LiveSnapshot>(IDLE);

  const jobManager = useMemo(() => {
    if (!client) return null;
    return new JobStreamManager({
      urlFor: (id) => client.jobEventsUrl(id),
      createSource,
      onEvent: (event) => applyLiveEvent(queryClient, event),
      onSnapshot: setStreams,
    });
  }, [client, createSource, queryClient]);

  const busManager = useMemo(() => {
    if (!client) return null;
    return new EventBusManager({
      url: client.eventsUrl({ types: BUS_TYPES }),
      createSource,
      onEvent: (event) => applyBusEvent(queryClient, event),
      onSnapshot: setBus,
    });
  }, [client, createSource, queryClient]);

  useEffect(() => {
    if (!jobManager) return;
    return () => {
      jobManager.dispose();
      setStreams(IDLE);
    };
  }, [jobManager]);

  useEffect(() => {
    if (!busManager) return;
    busManager.start();
    return () => {
      busManager.dispose();
      setBus(IDLE);
    };
  }, [busManager]);

  const connection: ConnectionState = health.isError ? 'offline' : health.isSuccess ? 'online' : 'connecting';

  useEffect(() => {
    jobManager?.setOffline(connection === 'offline');
    busManager?.setOffline(connection === 'offline');
  }, [jobManager, busManager, connection]);

  const activeKey = activeJobIds(jobs.data).sort().join('\n');
  useEffect(() => {
    jobManager?.sync(activeKey === '' ? [] : activeKey.split('\n'));
  }, [jobManager, activeKey]);

  const lastHealthyAt = health.dataUpdatedAt > 0 ? health.dataUpdatedAt : null;
  const value = useMemo<LiveStatus>(
    () => ({ connection, streams, bus, lastHealthyAt }),
    [connection, streams, bus, lastHealthyAt],
  );

  return <LiveContext.Provider value={value}>{children}</LiveContext.Provider>;
}
