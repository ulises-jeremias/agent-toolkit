import type { PtySessionInfo } from '../types/electron';

/** Active Person PTYs are workspace-owned; IDs alone are not globally unique. */
export function activePersonSessionsForWorkspace(
  sessions: readonly PtySessionInfo[],
  workspace: string,
): PtySessionInfo[] {
  if (!workspace) return [];
  return sessions.filter(
    (session) => Boolean(session.personId) && session.sessionWorkspace === workspace && session.exitCode === null,
  );
}
