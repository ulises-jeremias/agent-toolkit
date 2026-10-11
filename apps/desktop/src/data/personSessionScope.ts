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

/** Prefer the exact active PTY named by a World character deep link. */
export function selectActivePersonSession(
  sessions: readonly PtySessionInfo[],
  personId: string,
  requestedSessionId?: string | null,
): PtySessionInfo | undefined {
  const owned = sessions.filter((session) => session.personId === personId);
  return (requestedSessionId ? owned.find((session) => session.id === requestedSessionId) : undefined) ?? owned[0];
}
