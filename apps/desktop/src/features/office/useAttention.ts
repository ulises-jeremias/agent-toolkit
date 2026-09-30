import { useMemo } from 'react';
import { useBackend, useSelfcheck } from '../../data/backend';
import { sortJobs, useJobs } from '../../data/jobs';
import { useLiveStatus } from '../../data/live';
import { useSessionContext } from '../../shell/useSessionContext';
import {
  collectAttention,
  collectNeedsMe,
  completedJobs,
  failedJobs,
  finishedJobs,
  nextActions,
  officeLede,
  queryAttentionStatus,
  runningJobs,
  type AttentionInput,
} from './attention';

export function useAttention() {
  const { backend } = useBackend();
  const { href } = useSessionContext();
  const live = useLiveStatus();
  const jobs = useJobs();
  const selfcheck = useSelfcheck();
  const list = useMemo(() => sortJobs(jobs.data), [jobs.data]);

  const input: AttentionInput = useMemo(
    () => ({
      backend,
      connection: live.connection,
      jobs: jobs.data ? list : undefined,
      jobsStatus: queryAttentionStatus(jobs.isError, Boolean(jobs.data), jobs.isPending),
      selfcheck: selfcheck.data,
      selfcheckStatus: queryAttentionStatus(selfcheck.isError, Boolean(selfcheck.data), selfcheck.isPending),
      href,
    }),
    [
      backend,
      href,
      jobs.data,
      jobs.isError,
      jobs.isPending,
      list,
      live.connection,
      selfcheck.data,
      selfcheck.isError,
      selfcheck.isPending,
    ],
  );

  const items = useMemo(() => collectAttention(input), [input]);
  const targets = useMemo(() => collectNeedsMe(input), [input]);
  const actions = useMemo(() => nextActions(input, items), [input, items]);
  const lede = useMemo(() => officeLede(input, items), [input, items]);

  return {
    input,
    items,
    targets,
    actions,
    lede,
    href,
    live,
    jobs,
    selfcheck,
    all: list,
    running: runningJobs(list),
    failed: failedJobs(list),
    completed: completedJobs(list),
    finished: finishedJobs(list),
  };
}
