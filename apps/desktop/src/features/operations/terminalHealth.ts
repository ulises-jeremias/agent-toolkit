import type { ProviderInfo } from '../../lib/api';
import type { PtySessionInfo } from '../../types/electron';

export interface TerminalHealth {
  tone: 'ok' | 'warn' | 'err';
  headline: string;
  detail: string;
}

/**
 * Doctor's terminal row, from real Desktop state only: the PTY host's
 * live session list (exitCode null means the process is still running)
 * and backend runner discovery. Nothing here is estimated — if the PTY
 * bridge is absent the row says so instead of inventing health.
 */
export function summarizeTerminalHealth(
  hostAvailable: boolean,
  sessions: PtySessionInfo[],
  providers: ProviderInfo[],
): TerminalHealth {
  const running = sessions.filter((session) => session.exitCode === null);
  const exited = sessions.length - running.length;
  const runners = providers.filter((provider) => provider.available && provider.id !== 'skeleton');
  const runnerText =
    runners.length > 0
      ? `Runners detected: ${runners.map((provider) => provider.id).join(', ')}`
      : 'No runner detected';
  const sessionText =
    sessions.length === 0
      ? 'No terminal sessions open'
      : `${running.length} running · ${exited} exited of ${sessions.length} open`;

  if (!hostAvailable) {
    return {
      tone: 'err',
      headline: 'PTY host unavailable',
      detail: `The Desktop terminal bridge is not present in this window, so sessions cannot start. ${runnerText}.`,
    };
  }
  if (runners.length === 0) {
    return {
      tone: 'warn',
      headline: 'Terminal ready, no runner',
      detail: `${sessionText}. ${runnerText} — install or configure a coding-agent CLI to start Person sessions.`,
    };
  }
  return {
    tone: 'ok',
    headline: 'Terminal healthy',
    detail: `${sessionText}. ${runnerText}.`,
  };
}
