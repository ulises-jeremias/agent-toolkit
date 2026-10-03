import type { Tone } from '../../ui';

export function sessionState(exitCode: number | null, exitReason?: 'time-budget'): { tone: Tone; label: string } {
  if (exitCode === null) return { tone: 'ok', label: 'running' };
  if (exitReason === 'time-budget') return { tone: 'warn', label: 'time limit reached' };
  return exitCode === 0 ? { tone: 'idle', label: 'exited 0' } : { tone: 'err', label: `exited ${exitCode}` };
}
