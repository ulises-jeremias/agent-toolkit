import type { PtyExitEvent, PtySessionInfo } from '../types/electron';

export type TerminalPersonSessionEnd = 'completed' | 'failed' | 'interrupted' | 'stopped' | 'timed_out';

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
