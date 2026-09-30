export type ApiErrorKind =
  | 'network'
  | 'denied'
  | 'not-found'
  | 'conflict'
  | 'rate-limited'
  | 'invalid'
  | 'server'
  /** HTTP succeeded but the command reported `ok: false`. */
  | 'command';

export class ApiError extends Error {
  readonly kind: ApiErrorKind;
  readonly status: number;

  constructor(kind: ApiErrorKind, status: number, message: string) {
    super(message);
    this.name = 'ApiError';
    this.kind = kind;
    this.status = status;
  }
}

export function kindForStatus(status: number): ApiErrorKind {
  if (status === 401 || status === 403) return 'denied';
  if (status === 404) return 'not-found';
  if (status === 409) return 'conflict';
  if (status === 429) return 'rate-limited';
  if (status === 400 || status === 422) return 'invalid';
  return 'server';
}

export function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

/** Best next action for a failed request, phrased for people rather than status codes. */
export function recoveryHint(error: unknown): string {
  if (!(error instanceof ApiError)) return 'Try again. If it keeps failing, restart the backend from Settings.';
  switch (error.kind) {
    case 'network':
      return 'The backend is not answering. Wait for it to restart, or restart it from Settings.';
    case 'denied':
      // The released 1.35.0 backend predates the X-Atk-Desktop first-party gate.
      if (/cross-site/i.test(error.message)) {
        return 'This backend is older than the Desktop build and rejects its requests. Update agent-toolkit.';
      }
      return 'The backend refused this request. Check that the path is inside the active workspace.';
    case 'not-found':
      return 'This backend does not provide that resource. It may be older than this Desktop build.';
    case 'conflict':
      return 'The resource changed state first. Refresh to see its current state.';
    case 'rate-limited':
      return 'The backend is busy. Wait for running work to finish, then try again.';
    case 'invalid':
      return 'The request was rejected as invalid. Adjust the input and try again.';
    case 'server':
      return 'The backend failed while handling this. Try again, or check Doctor in Insights.';
    case 'command':
      if (/workspace not found/i.test(error.message)) {
        return 'No workspace is active. Start the backend from inside a workspace folder.';
      }
      return 'The command ran and reported a failure. Its output is shown above.';
  }
}
