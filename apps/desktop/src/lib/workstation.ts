export interface WorkstationSession {
  id: string;
  agent: string;
  cwd: string;
}

export interface SessionRun {
  run: string;
}

/** How the world (or any inspector) asks to focus the workstation. */
export interface WorkstationFocus {
  /** Electron PTY id. Wins over identity. Unknown ids match nothing. */
  pty?: string;
  agent?: string;
  run?: string;
  /** Resolved harness / session cwd. */
  cwd?: string;
}

/**
 * Pick a real PTY. Never invents a session: a miss is null.
 * `pty` is exact. Identity is agent + run + cwd together when no `pty`
 * is given — cwd alone is not a focus request (workspace is always in the URL).
 */
export function matchWorkstationSession(
  sessions: readonly WorkstationSession[],
  extras: Readonly<Record<string, SessionRun>>,
  focus: WorkstationFocus,
): WorkstationSession | null {
  const pty = focus.pty?.trim();
  if (pty) return sessions.find((session) => session.id === pty) ?? null;

  const agent = focus.agent?.trim();
  const run = focus.run?.trim();
  const cwd = focus.cwd?.trim();
  if (!agent && !run) return null;

  return (
    sessions.find((session) => {
      if (agent && session.agent !== agent) return false;
      if (run && (extras[session.id]?.run ?? '') !== run) return false;
      if (cwd && session.cwd !== cwd) return false;
      return true;
    }) ?? null
  );
}
