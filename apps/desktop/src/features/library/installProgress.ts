import { errorMessage } from '../../lib/api/errors';

export interface TargetApplyProgress {
  total: number;
  done: string[];
  failed: { target: string; message: string }[];
  current: string | null;
}

/**
 * Applies a reviewed installation one target at a time so progress is a
 * real, determinate signal: each settled target is a completed backend
 * transaction with its own receipt. A failed target never blocks the
 * rest; every outcome is reported, nothing is retried implicitly.
 */
export async function applyInstallTargets(
  targets: readonly string[],
  applyOne: (target: string) => Promise<void>,
  onProgress: (progress: TargetApplyProgress) => void,
): Promise<TargetApplyProgress> {
  const progress: TargetApplyProgress = { total: targets.length, done: [], failed: [], current: null };
  onProgress({ ...progress });
  for (const target of targets) {
    progress.current = target;
    onProgress({ ...progress, done: [...progress.done], failed: [...progress.failed] });
    try {
      await applyOne(target);
      progress.done = [...progress.done, target];
    } catch (error) {
      progress.failed = [...progress.failed, { target, message: errorMessage(error) }];
    }
  }
  progress.current = null;
  onProgress({ ...progress, done: [...progress.done], failed: [...progress.failed] });
  return progress;
}
