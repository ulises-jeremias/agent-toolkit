import type {
  AgentsResponse,
  Job,
  JobCreateRequest,
  JobRegistry,
  InstallPreviewResponse,
  LoopListResponse,
  LoopStatusResponse,
  LoopHistoryResponse,
  LoopAuditResponse,
  LoopCostResponse,
  MemoryListResponse,
  MemoryReadResponse,
  MemorySearchResponse,
  MemoryWriteResponse,
  McpProvidersResponse,
  MessageResponse,
  ModelsResponse,
  PeopleResponse,
  PersonResponse,
  Person,
  ProvidersResponse,
  SelfcheckResponse,
  SwarmActionResponse,
  SwarmListResponse,
  SwarmRecipesResponse,
  SwarmRunResponse,
  ToolsResponse,
  VersionResponse,
  WorkspaceFileListResponse,
  WorkspaceFileReadResponse,
  WorkspaceFileSearchResponse,
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
    method: 'GET' | 'POST' | 'PUT' | 'DELETE',
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
    method: 'GET' | 'POST' | 'PUT' | 'DELETE',
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

  async installPreview(): Promise<InstallPreviewResponse> {
    return this.json<InstallPreviewResponse>('GET', '/api/v1/install/preview' satisfies PathWith<'get'>);
  }

  async uninstallPreview(): Promise<InstallPreviewResponse> {
    return this.json<InstallPreviewResponse>('GET', '/api/v1/uninstall/preview' satisfies PathWith<'get'>);
  }

  mcpProviders(): Promise<ResponseOf<OperationOf<'/api/v1/mcp/providers', 'get'>, McpProvidersResponse>> {
    return this.json('GET', '/api/v1/mcp/providers' satisfies PathWith<'get'>);
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

  jobs(): Promise<ResponseOf<OperationOf<'/api/v1/jobs', 'get'>, JobRegistry>> {
    return this.json('GET', '/api/v1/jobs' satisfies PathWith<'get'>);
  }

  job(id: string): Promise<ResponseOf<OperationOf<'/api/v1/jobs/{id}', 'get'>, Job>> {
    return this.json('GET', fillPath('/api/v1/jobs/{id}' satisfies PathWith<'get'>, { id }));
  }

  createJob(request: JobCreateRequest): Promise<Job> {
    return this.json('POST', '/api/v1/jobs' satisfies PathWith<'post'>, { body: request });
  }

  getJob(id: string): Promise<Job> {
    return this.json('GET', fillPath('/api/v1/jobs/{id}' satisfies PathWith<'get'>, { id }));
  }

  cancelJob(id: string): Promise<Job> {
    return this.json('POST', fillPath('/api/v1/jobs/{id}/cancel' satisfies PathWith<'post'>, { id }));
  }

  retryJob(id: string): Promise<ResponseOf<OperationOf<'/api/v1/jobs/{id}/retry', 'post'>, Job>> {
    return this.json('POST', fillPath('/api/v1/jobs/{id}/retry' satisfies PathWith<'post'>, { id }));
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

  /** Global bus (`GET /api/v1/events`). EventSource sends Last-Event-ID; `since`/`after` for our reopen. */
  eventsUrl(options: { types?: string; since?: number; after?: string } = {}): string {
    const path = '/api/v1/events' satisfies PathWith<'get'>;
    const query = new URLSearchParams();
    if (options.types) query.set('types', options.types);
    if (options.since !== undefined) query.set('since', String(options.since));
    if (options.after) query.set('after', options.after);
    const suffix = query.toString();
    return suffix ? `${this.baseUrl}${path}?${suffix}` : `${this.baseUrl}${path}`;
  }

  listMemory(query?: { workspace?: string }): Promise<MemoryListResponse> {
    return this.json('GET', '/api/v1/memory' satisfies PathWith<'get'>, {
      query: query?.workspace ? { workspace: query.workspace } : undefined,
    });
  }

  searchMemory(q: string, query?: { workspace?: string }): Promise<MemorySearchResponse> {
    return this.json('GET', '/api/v1/memory/hits' satisfies PathWith<'get'>, {
      query: {
        q,
        ...(query?.workspace ? { workspace: query.workspace } : {}),
      },
    });
  }

  readMemoryFile(path: string, query?: { workspace?: string }): Promise<MemoryReadResponse> {
    return this.json('GET', '/api/v1/memory/file' satisfies PathWith<'get'>, {
      query: {
        path,
        ...(query?.workspace ? { workspace: query.workspace } : {}),
      },
    });
  }

  addMemoryFile(body: {
    entry_type: string;
    title?: string;
    content: string;
    workspace?: string;
  }): Promise<MemoryWriteResponse> {
    return this.json('POST', '/api/v1/memory/file' satisfies PathWith<'post'>, { body });
  }

  editMemoryFile(body: { path: string; content: string; workspace?: string }): Promise<MemoryWriteResponse> {
    // OpenAPI documents PUT; PathWith<'get'> anchors the template until put is in PathWith.
    return this.json('PUT', '/api/v1/memory/file', { body });
  }

  archiveMemoryFile(body: { path: string; workspace?: string }): Promise<MemoryWriteResponse> {
    return this.json('POST', '/api/v1/memory/file/archive' satisfies PathWith<'post'>, { body });
  }

  listFiles(query?: {
    path?: string;
    depth?: string;
    workspace?: string;
    project?: string;
  }): Promise<WorkspaceFileListResponse> {
    const params: Record<string, string> = {};
    if (query?.path) params.path = query.path;
    if (query?.depth) params.depth = query.depth;
    if (query?.workspace) params.workspace = query.workspace;
    if (query?.project) params.project = query.project;
    return this.json('GET', '/api/v1/files' satisfies PathWith<'get'>, {
      query: Object.keys(params).length ? params : undefined,
    });
  }

  searchFiles(q: string, query?: { workspace?: string; project?: string }): Promise<WorkspaceFileSearchResponse> {
    return this.json('GET', '/api/v1/files/hits' satisfies PathWith<'get'>, {
      query: {
        q,
        ...(query?.workspace ? { workspace: query.workspace } : {}),
        ...(query?.project ? { project: query.project } : {}),
      },
    });
  }

  readFile(path: string, query?: { workspace?: string; project?: string }): Promise<WorkspaceFileReadResponse> {
    return this.json('GET', '/api/v1/files/content' satisfies PathWith<'get'>, {
      query: {
        path,
        ...(query?.workspace ? { workspace: query.workspace } : {}),
        ...(query?.project ? { project: query.project } : {}),
      },
    });
  }

  async loopStatus(name: string): Promise<CommandEnvelope> {
    return toEnvelope(
      await this.json<unknown>('GET', fillPath('/api/v1/loops/{name}/status' satisfies PathWith<'get'>, { name })),
    );
  }

  loops(): Promise<ResponseOf<OperationOf<'/api/v1/loops', 'get'>, LoopListResponse>> {
    return this.json('GET', '/api/v1/loops' satisfies PathWith<'get'>);
  }

  loopStatusTyped(
    name: string,
  ): Promise<ResponseOf<OperationOf<'/api/v1/loops/{name}/status', 'get'>, LoopStatusResponse>> {
    return this.json('GET', fillPath('/api/v1/loops/{name}/status' satisfies PathWith<'get'>, { name }));
  }

  loopHistory(
    name: string,
  ): Promise<ResponseOf<OperationOf<'/api/v1/loops/{name}/history', 'get'>, LoopHistoryResponse>> {
    return this.json('GET', fillPath('/api/v1/loops/{name}/history' satisfies PathWith<'get'>, { name }));
  }

  loopAudit(name: string): Promise<ResponseOf<OperationOf<'/api/v1/loops/{name}/audit', 'get'>, LoopAuditResponse>> {
    return this.json('GET', fillPath('/api/v1/loops/{name}/audit' satisfies PathWith<'get'>, { name }));
  }

  loopCost(name: string): Promise<ResponseOf<OperationOf<'/api/v1/loops/{name}/cost', 'get'>, LoopCostResponse>> {
    return this.json('GET', fillPath('/api/v1/loops/{name}/cost' satisfies PathWith<'get'>, { name }));
  }

  runLoop(name: string): Promise<Job> {
    return this.json('POST', fillPath('/api/v1/loops/{name}/run' satisfies PathWith<'post'>, { name }));
  }

  async scheduleLoop(name: string): Promise<CommandEnvelope> {
    return toEnvelope(
      await this.json<unknown>('POST', fillPath('/api/v1/loops/{name}/schedule' satisfies PathWith<'post'>, { name })),
    );
  }

  agents(): Promise<ResponseOf<OperationOf<'/api/v1/agents', 'get'>, AgentsResponse>> {
    return this.json('GET', '/api/v1/agents' satisfies PathWith<'get'>);
  }

  people(workspace: string): Promise<PeopleResponse> {
    return this.json('GET', '/api/v1/people' satisfies PathWith<'get'>, { query: { workspace } });
  }

  person(workspace: string, id: string): Promise<PersonResponse> {
    return this.json('GET', fillPath('/api/v1/people/{id}' satisfies PathWith<'get'>, { id }), {
      query: { workspace },
    });
  }

  createPerson(workspace: string, person: Person): Promise<PersonResponse> {
    return this.json('POST', '/api/v1/people' satisfies PathWith<'post'>, { body: { workspace, person } });
  }

  updatePerson(workspace: string, person: Person): Promise<PersonResponse> {
    return this.json('PUT', fillPath('/api/v1/people/{id}' satisfies PathWith<'put'>, { id: person.id }), {
      body: { workspace, person },
    });
  }

  archivePerson(workspace: string, id: string): Promise<PersonResponse> {
    return this.json('POST', fillPath('/api/v1/people/{id}/archive' satisfies PathWith<'post'>, { id }), {
      body: { workspace },
    });
  }

  tools(): Promise<ResponseOf<OperationOf<'/api/v1/tools', 'get'>, ToolsResponse>> {
    return this.json('GET', '/api/v1/tools' satisfies PathWith<'get'>);
  }

  providers(): Promise<ResponseOf<OperationOf<'/api/v1/providers', 'get'>, ProvidersResponse>> {
    return this.json('GET', '/api/v1/providers' satisfies PathWith<'get'>);
  }

  models(): Promise<ResponseOf<OperationOf<'/api/v1/models', 'get'>, ModelsResponse>> {
    return this.json('GET', '/api/v1/models' satisfies PathWith<'get'>);
  }

  swarms(): Promise<ResponseOf<OperationOf<'/api/v1/swarms', 'get'>, SwarmListResponse>> {
    return this.json('GET', '/api/v1/swarms' satisfies PathWith<'get'>);
  }

  swarmRecipes(): Promise<ResponseOf<OperationOf<'/api/v1/swarms/recipes', 'get'>, SwarmRecipesResponse>> {
    return this.json('GET', '/api/v1/swarms/recipes' satisfies PathWith<'get'>);
  }

  swarmRun(id: string): Promise<ResponseOf<OperationOf<'/api/v1/swarms/runs/{id}', 'get'>, SwarmRunResponse>> {
    return this.json('GET', fillPath('/api/v1/swarms/runs/{id}' satisfies PathWith<'get'>, { id }));
  }

  approveSwarm(
    id: string,
  ): Promise<ResponseOf<OperationOf<'/api/v1/swarms/runs/{id}/approve', 'post'>, SwarmActionResponse>> {
    return this.json('POST', fillPath('/api/v1/swarms/runs/{id}/approve' satisfies PathWith<'post'>, { id }));
  }

  rejectSwarm(
    id: string,
  ): Promise<ResponseOf<OperationOf<'/api/v1/swarms/runs/{id}/reject', 'post'>, SwarmActionResponse>> {
    return this.json('POST', fillPath('/api/v1/swarms/runs/{id}/reject' satisfies PathWith<'post'>, { id }));
  }

  stopSwarm(
    id: string,
  ): Promise<ResponseOf<OperationOf<'/api/v1/swarms/runs/{id}/stop', 'post'>, SwarmActionResponse>> {
    return this.json('POST', fillPath('/api/v1/swarms/runs/{id}/stop' satisfies PathWith<'post'>, { id }));
  }
}
