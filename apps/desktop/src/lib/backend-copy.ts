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
