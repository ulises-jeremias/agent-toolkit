import type {
  Job,
  JobCreateRequest,
  JobRegistry,
  MemoryListResponse,
  MessageResponse,
  SelfcheckResponse,
  VersionResponse,
} from './contracts';
import { toEnvelope, type CommandEnvelope } from './envelope';
import { ApiError, kindForStatus } from './errors';
import type { OperationOf, PathWith, ResponseOf, SubBody, SubCommand, SubFamily } from './schema';

/**
 * Typed client for `agent-toolkit serve`. V owns all domain state; this
 * module owns transport, envelope decoding and typed errors only.
 */

/** GET report routes that answer with a command envelope. */
export const REPORT_PATHS = {
  inventory: '/api/v1/inventory',
  doctor: '/api/v1/doctor',
  matrix: '/api/v1/matrix',
  diff: '/api/v1/diff',
  insights: '/api/v1/insights',
  loops: '/api/v1/loops',
  swarms: '/api/v1/swarms',
} as const satisfies Record<string, PathWith<'get'>>;

export type ReportKind = keyof typeof REPORT_PATHS;

/** POST routes that run a whole-toolkit operation and answer with an envelope. */
export const OPERATION_PATHS = {
  install: '/api/v1/install',
  update: '/api/v1/update',
  uninstall: '/api/v1/uninstall',
  build: '/api/v1/build',
  doctorFix: '/api/v1/doctor/fix',
} as const satisfies Record<string, PathWith<'post'>>;

export type OperationKind = keyof typeof OPERATION_PATHS;

type Fetch = typeof fetch;

function fillPath(template: string, params: Record<string, string>): string {
  return template.replace(/\{(\w+)\}/g, (_match, name: string) => {
    const value = params[name];
    if (value === undefined) throw new Error(`missing path parameter ${name} for ${template}`);
    return encodeURIComponent(value);
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

export class ApiClient {
  constructor(
    private readonly baseUrl: string,
    private readonly fetchImpl: Fetch = (...args) => fetch(...args),
  ) {}

  get url(): string {
    return this.baseUrl;
  }

  private async send(
    method: 'GET' | 'POST' | 'DELETE',
    path: string,
    options: { body?: unknown; query?: Record<string, string> } = {},
  ): Promise<Response> {
    const query = options.query ? `?${new URLSearchParams(options.query).toString()}` : '';
    let response: Response;
    try {
      response = await this.fetchImpl(`${this.baseUrl}${path}${query}`, {
        method,
        headers: {
          // First-party non-browser client mark (V is_first_party_mutation):
          // browsers cannot send it cross-origin without a preflight the
          // server never answers, so loopback mutations stay first-party.
          'x-atk-desktop': '1',
          'content-type': 'application/json',
        },
        body: options.body === undefined ? undefined : JSON.stringify(options.body),
      });
    } catch (error) {
      throw new ApiError(
        'network',
        0,
        `backend unreachable at ${this.baseUrl}: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
    if (!response.ok) {
      throw new ApiError(kindForStatus(response.status), response.status, await this.errorMessage(response));
    }
    return response;
  }

  private async json<T>(
    method: 'GET' | 'POST' | 'DELETE',
    path: string,
    options?: { body?: unknown; query?: Record<string, string> },
  ): Promise<T> {
    const response = await this.send(method, path, options);
    return (await response.json()) as T;
  }

  private async errorMessage(response: Response): Promise<string> {
    try {
      const body = (await response.json()) as unknown;
      if (isRecord(body)) {
        if (typeof body['error'] === 'string') return body['error'];
        if (typeof body['message'] === 'string') return body['message'];
      }
    } catch {
      // Non-JSON error body: fall through to the status line.
    }
    return `request failed with HTTP ${response.status}`;
  }

  health(): Promise<ResponseOf<OperationOf<'/api/v1/health', 'get'>, VersionResponse>> {
    return this.json('GET', '/api/v1/health' satisfies PathWith<'get'>);
  }

  version(): Promise<ResponseOf<OperationOf<'/api/v1/version', 'get'>, VersionResponse>> {
    return this.json('GET', '/api/v1/version' satisfies PathWith<'get'>);
  }

  selfcheck(): Promise<ResponseOf<OperationOf<'/api/v1/selfcheck', 'get'>, SelfcheckResponse>> {
    return this.json('GET', '/api/v1/selfcheck' satisfies PathWith<'get'>);
  }

  async help(): Promise<string> {
    const response = await this.send('GET', '/api/v1/help' satisfies PathWith<'get'>);
    return response.text();
  }

  async report(kind: ReportKind): Promise<CommandEnvelope> {
    return toEnvelope(await this.json<unknown>('GET', REPORT_PATHS[kind]));
  }

  async operation(kind: OperationKind): Promise<CommandEnvelope> {
    return toEnvelope(await this.json<unknown>('POST', OPERATION_PATHS[kind]));
  }

  /**
   * Run an allowlisted subcommand of a command family. `sub` and `body` are
   * typed from the OpenAPI enum and request DTO for that family; the server
   * rejects unknown subcommands (404) and invalid fields (400).
   */
  async sub<F extends SubFamily>(family: F, sub: SubCommand<F>, body?: SubBody<F>): Promise<CommandEnvelope> {
    const path = fillPath('/api/v1/{family}/{sub}', { family, sub: String(sub) });
    return toEnvelope(await this.json<unknown>('POST', path, { body: body ?? {} }));
  }

  jobs(): Promise<JobRegistry> {
    // V serves GET /api/v1/jobs (jobs_list), but openapi.json only documents
    // the POST on this path; anchor to that until the contract lists both.
    return this.json('GET', '/api/v1/jobs' satisfies PathWith<'post'>);
  }

  createJob(request: JobCreateRequest): Promise<Job> {
    return this.json('POST', '/api/v1/jobs' satisfies PathWith<'post'>, { body: request });
  }

  cancelJob(id: string): Promise<Job> {
    return this.json('POST', fillPath('/api/v1/jobs/{id}/cancel' satisfies PathWith<'post'>, { id }));
  }

  deleteJob(id: string, force = false): Promise<MessageResponse> {
    return this.json('DELETE', fillPath('/api/v1/jobs/{id}' satisfies PathWith<'delete'>, { id }), {
      query: force ? { force: 'true' } : undefined,
    });
  }

  async jobLog(id: string): Promise<string> {
    const response = await this.send('GET', fillPath('/api/v1/jobs/{id}/log' satisfies PathWith<'get'>, { id }));
    return response.text();
  }

  jobEventsUrl(id: string): string {
    return `${this.baseUrl}${fillPath('/api/v1/jobs/{id}/events' satisfies PathWith<'get'>, { id })}`;
  }

  /** Global bus (`GET /api/v1/events`). Prefer for world presence; job logs stay on jobEventsUrl. */
  eventsUrl(query?: { types?: string; after?: string }): string {
    const params = new URLSearchParams();
    if (query?.types) params.set('types', query.types);
    if (query?.after) params.set('after', query.after);
    const suffix = params.toString();
    return `${this.baseUrl}${'/api/v1/events' satisfies PathWith<'get'>}${suffix ? `?${suffix}` : ''}`;
  }

  listMemory(): Promise<MemoryListResponse> {
    return this.json('GET', '/api/v1/memory' satisfies PathWith<'get'>);
  }
}
