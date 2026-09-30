import type { BackendState } from '../types/electron';

/**
 * Banner copy for a non-ready backend. Prefers the supervisor's `detail`
 * (path, version, "too old", spawn error) over a generic "crashed".
 */
export function backendBannerCopy(backend: BackendState): string {
  if (backend.status === 'starting') {
    return backend.detail
      ? `Starting the Agent Toolkit backend… ${backend.detail}`
      : 'Starting the Agent Toolkit backend…';
  }
  if (backend.detail) return backend.detail;
  switch (backend.status) {
    case 'version-mismatch':
      return `Backend version ${backend.version ?? 'unknown'} does not match this Desktop build. Some actions may fail.`;
    case 'crashed':
      return 'Backend crashed.';
    case 'failed':
      return 'Backend failed to start.';
    case 'stopped':
      return 'Backend is stopped.';
    default:
      return backend.status;
  }
}

export function backendCanRestart(backend: BackendState): boolean {
  return backend.status === 'crashed' || backend.status === 'failed' || backend.status === 'stopped';
}

/**
 * Plain-language cause for a non-ready backend. Uses the supervisor's
 * `problem` code so Settings can name binary-rejected separately from crash.
 */
export function backendProblemCopy(backend: BackendState): string | null {
  switch (backend.problem) {
    case 'no-backend':
      return 'No agent-toolkit binary was found. Stage or install one, or set ATK_BACKEND_BIN.';
    case 'binary-rejected':
      return 'Candidates existed but none passed the serve probe. Desktop did not spawn a stale binary.';
    case 'spawn-error':
      return 'The operating system refused to launch the selected binary.';
    case 'exited-during-start':
      return 'Serve exited before it answered a health check.';
    case 'health-timeout':
      return 'Serve started but never answered /api/v1/health.';
    case 'major-mismatch':
      return 'The running backend reports a different major version than this Desktop build.';
    case 'desktop-gate-missing':
      return 'This backend predates the X-Atk-Desktop first-party gate, so Desktop mutations are refused.';
    case 'exited':
      return 'Serve exited after it was ready.';
    case 'port':
      return 'No free localhost port was available for serve.';
    default:
      return null;
  }
}
