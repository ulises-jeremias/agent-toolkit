import type { PtyExitEvent, PtySessionInfo } from '../types/electron';

export type TerminalPersonSessionEnd = 'completed' | 'failed' | 'interrupted' | 'stopped' | 'timed_out';

/** Keep API enum values machine-readable while showing plain language in the inspector. */
export function personSessionStatusLabel(status: string): string {
  switch (status) {
    case 'launching':
      return 'Starting';
    case 'running':
      return 'Running';
    case 'completed':
      return 'Completed';
    case 'failed':
      return 'Failed';
    case 'stopped':
      return 'Stopped';
    case 'timed_out':
      return 'Timed out';
    case 'interrupted':
      return 'Interrupted';
    default:
      return 'Unknown';
  }
}

/** Translate only process exit evidence into a terminal PersonSession state. */
export function personSessionEndStatus(
  exitCode: number,
  exitReason: PtyExitEvent['exitReason'] | PtySessionInfo['exitReason'],
): TerminalPersonSessionEnd {
  if (exitReason === 'app-shutdown') return 'interrupted';
  if (exitReason === 'user-stop') return 'stopped';
  if (exitReason === 'time-budget') return 'timed_out';
  return exitCode === 0 ? 'completed' : 'failed';
}
