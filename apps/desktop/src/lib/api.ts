/**
 * Typed client for the `agent-toolkit serve` HTTP API.
 *
 * The V backend is authoritative for all domain state. This module owns only
 * transport + envelope decoding + typed errors. Route/response shapes follow
 * docs/surface/openapi.json and modules/agent_toolkit_server/*.v.
 */

/**
 * Command envelope. The V server (`result_to_http` in
 * modules/agent_toolkit_server/read.v) spreads data fields at the TOP level
 * of the JSON body — there is no nested `data` object. This normalizer
 * recovers `{ok, message, data}` from the wire shape.
 */
export interface CommandEnvelope {
  ok: boolean;
  message: string;
  data: Record<string, string>;
}

export function toEnvelope(wire: unknown): CommandEnvelope {
  if (typeof wire !== 'object' || wire === null) {
    throw new ApiError('server', 200, 'backend returned a non-object envelope');
  }
  const record = wire as Record<string, unknown>;
  const ok = record['ok'] === true;
  const message = typeof record['message'] === 'string' ? record['message'] : '';
  const data: Record<string, string> = {};
  const mergeFields = (obj: Record<string, unknown>): void => {
    for (const [key, value] of Object.entries(obj)) {
      if (key === 'ok' || key === 'message' || key === 'data') continue;
      data[key] = typeof value === 'string' ? value : JSON.stringify(value);
    }
  };
  mergeFields(record);
  // CmdResp routes (matrix, insights, :sub proxies) nest the payload under
  // `data`; merge it so callers see fields, not one stringified blob.
  // Nested wins on key conflict: it is the structured server payload.
  const nested = record['data'];
  if (typeof nested === 'object' && nested !== null && !Array.isArray(nested)) {
    mergeFields(nested as Record<string, unknown>);
  }
  return { ok, message, data };
}

export interface VersionResponse {
  ok: boolean;
  version: string;
  commit?: string;
  uptime_s?: number;
}

export interface SelfcheckCheck {
  name: string;
  status: 'ok' | 'warn' | 'err';
  detail: string;
}

export interface SelfcheckResponse {
  ok: boolean;
  version: string;
  commit: string;
  checks: SelfcheckCheck[];
}

/** Terminal states per modules/agent_toolkit_server/jobs.v: completed/failed (plus canceled/rejected guards). */
export type JobStatus = 'queued' | 'running' | 'completed' | 'failed';

export interface Job {
  id: string;
  cmd: string;
  args: string[];
  status: JobStatus | string;
  started_at: string;
  ended_at: string;
  exit_code: number;
  workspace: string;
}

export interface JobCreateRequest {
  cmd: string;
  args?: string[];
  workspace?: string;
}

export interface DenyError {
  ok: false;
  error: string;
}

export type ApiErrorKind = 'network' | 'denied' | 'not-found' | 'conflict' | 'rate-limited' | 'invalid' | 'server';

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

function kindForStatus(status: number): ApiErrorKind {
  if (status === 401 || status === 403) return 'denied';
  if (status === 404) return 'not-found';
  if (status === 409) return 'conflict';
  if (status === 429) return 'rate-limited';
  if (status === 400 || status === 422) return 'invalid';
  return 'server';
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

export class ApiClient {
  constructor(private readonly baseUrl: string) {}

  get url(): string {
    return this.baseUrl;
  }

  private async request<T>(path: string, init?: RequestInit): Promise<T> {
    let response: Response;
    try {
      response = await fetch(`${this.baseUrl}${path}`, {
        ...init,
        headers: {
          // First-party non-browser client mark (see V is_first_party_mutation):
          // browsers refuse to send custom headers cross-origin without a
          // CORS preflight the server never answers, so this restores the
          // intended same-origin-for-browsers policy for file:// Desktop.
          'x-atk-desktop': '1',
          'content-type': 'application/json',
          ...(init?.headers ?? {}),
        },
      });
    } catch (error) {
      throw new ApiError(
        'network',
        0,
        `backend unreachable at ${this.baseUrl}: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
    if (!response.ok) {
      const message = await this.errorMessage(response);
      throw new ApiError(kindForStatus(response.status), response.status, message);
    }
    return (await response.json()) as T;
  }

  private async errorMessage(response: Response): Promise<string> {
    try {
      const body = (await response.json()) as unknown;
      if (isRecord(body)) {
        const error = body['error'];
        const message = body['message'];
        if (typeof error === 'string') return error;
        if (typeof message === 'string') return message;
      }
    } catch {
      // fall through to status text
    }
    return `request failed with HTTP ${response.status}`;
  }

  health(): Promise<VersionResponse> {
    return this.request<VersionResponse>('/api/v1/health');
  }

  version(): Promise<VersionResponse> {
    return this.request<VersionResponse>('/api/v1/version');
  }

  selfcheck(): Promise<SelfcheckResponse> {
    return this.request<SelfcheckResponse>('/api/v1/selfcheck');
  }

  /** Generic read-API envelope (inventory, doctor, matrix, diff, insights, ...). */
  async readApi(
    path:
      | '/api/v1/inventory'
      | '/api/v1/doctor'
      | '/api/v1/matrix'
      | '/api/v1/diff'
      | '/api/v1/insights'
      | '/api/v1/loops'
      | '/api/v1/swarms'
      | '/api/v1/selfcheck'
      | '/api/v1/help',
  ): Promise<CommandEnvelope> {
    return toEnvelope(await this.request<unknown>(path));
  }

  /** Generic sub-resource proxy: skills/:sub, mcp/:sub, workspace/:sub, ... */
  async subApi(
    resource: 'skills' | 'mcp' | 'plugin' | 'workspace' | 'memory' | 'project' | 'loops' | 'dc' | 'swarms',
    sub: string,
    body?: unknown,
  ): Promise<CommandEnvelope> {
    const encoded = sub.split('/').map(encodeURIComponent).join('/');
    return toEnvelope(
      await this.request<unknown>(`/api/v1/${resource}/${encoded}`, {
        method: body === undefined ? 'GET' : 'POST',
        body: body === undefined ? undefined : JSON.stringify(body),
      }),
    );
  }

  async execute(
    path: '/api/v1/install' | '/api/v1/update' | '/api/v1/uninstall' | '/api/v1/build' | '/api/v1/doctor/fix',
    body?: unknown,
  ): Promise<CommandEnvelope> {
    return toEnvelope(
      await this.request<unknown>(path, {
        method: 'POST',
        body: body === undefined ? undefined : JSON.stringify(body),
      }),
    );
  }

  jobsList(): Promise<Record<string, Job>> {
    return this.request<Record<string, Job>>('/api/v1/jobs');
  }

  jobsCreate(req: JobCreateRequest): Promise<Job> {
    return this.request<Job>('/api/v1/jobs', { method: 'POST', body: JSON.stringify(req) });
  }

  async jobsLog(id: string): Promise<string> {
    const response = await fetch(`${this.baseUrl}/api/v1/jobs/${encodeURIComponent(id)}/log`);
    if (!response.ok) {
      throw new ApiError(kindForStatus(response.status), response.status, await this.errorMessage(response));
    }
    return response.text();
  }

  /**
   * Subscribe to a job's SSE stream; resolves when the stream closes.
   *
   * The V server emits *named* SSE events (`status`, `log`, `done`), which
   * never reach `EventSource.onmessage` — they require explicit listeners.
   */
  subscribeJobEvents(id: string, onEvent: (event: JobStreamEvent) => void, signal: AbortSignal): Promise<void> {
    const source = new EventSource(`${this.baseUrl}/api/v1/jobs/${encodeURIComponent(id)}/events`);
    return new Promise<void>((resolve) => {
      const done = (): void => {
        source.close();
        signal.removeEventListener('abort', done);
        resolve();
      };
      signal.addEventListener('abort', done);
      const named = (type: 'status' | 'log' | 'done') => (message: Event) => {
        onEvent(namedJobStreamEvent(type, (message as MessageEvent<string>).data ?? ''));
        if (type === 'done') done();
      };
      source.addEventListener('status', named('status'));
      source.addEventListener('log', named('log'));
      source.addEventListener('done', named('done'));
      // Unnamed frames are not part of the V contract; keep a fallback parse
      // so a future unnamed frame still surfaces instead of vanishing.
      source.onmessage = (message: MessageEvent<string>) => {
        onEvent(parseJobStreamEvent(message.data));
      };
      source.onerror = () => {
        // Error here also fires on normal stream close; treat as done.
        done();
      };
    });
  }
}

export type JobStreamEvent =
  | { type: 'status'; status: string }
  | { type: 'log'; line: string }
  | { type: 'done'; exitCode: number }
  | { type: 'unknown'; raw: string };

/**
 * Map a named SSE event from the V jobs stream to a typed client event.
 *
 * Server contract (`GET /api/v1/jobs/:id/events`): `status` carries the job
 * status word, `log` carries one raw output line, `done` carries the terminal
 * status word. The stream carries no numeric exit code — `done` reports 0
 * for `completed` and 1 otherwise; the authoritative exit code arrives via
 * the `jobs` query refetch the caller performs on `done`.
 */
export function namedJobStreamEvent(type: 'status' | 'log' | 'done', data: string): JobStreamEvent {
  if (type === 'status') return { type: 'status', status: data.trim() };
  if (type === 'log') return { type: 'log', line: data };
  if (type === 'done') return { type: 'done', exitCode: data.trim() === 'completed' ? 0 : 1 };
  return { type: 'unknown', raw: `${type}:${data}` };
}

export function parseJobStreamEvent(data: string): JobStreamEvent {
  const trimmed = data.trim();
  if (trimmed.startsWith('{')) {
    try {
      const parsed = JSON.parse(trimmed) as Record<string, unknown>;
      if (typeof parsed['status'] === 'string') return { type: 'status', status: parsed['status'] };
      if (typeof parsed['line'] === 'string') return { type: 'log', line: parsed['line'] };
      if (typeof parsed['exit_code'] === 'number' || typeof parsed['exitCode'] === 'number') {
        return { type: 'done', exitCode: Number(parsed['exit_code'] ?? parsed['exitCode']) };
      }
    } catch {
      return { type: 'unknown', raw: data };
    }
  }
  if (trimmed.startsWith('status:')) return { type: 'status', status: trimmed.slice('status:'.length).trim() };
  if (trimmed.startsWith('done')) return { type: 'done', exitCode: 0 };
  return { type: 'log', line: data };
}
