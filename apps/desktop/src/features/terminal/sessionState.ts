import type { Tone } from '../../ui';

export function sessionState(exitCode: number | null): { tone: Tone; label: string } {
  if (exitCode === null) return { tone: 'ok', label: 'running' };
  return exitCode === 0 ? { tone: 'idle', label: 'exited 0' } : { tone: 'err', label: `exited ${exitCode}` };
}
