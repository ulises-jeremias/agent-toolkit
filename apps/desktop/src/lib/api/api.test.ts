import { afterEach, describe, expect, it, vi } from 'vitest';
import { normalizeLoopback } from '../query/client';
import {
  ApiClient,
  ApiError,
  envelopeText,
  namedJobStreamEvent,
  parseJobStreamEvent,
  recoveryHint,
  requireOk,
  toEnvelope,
} from './index';

describe('toEnvelope', () => {
  it('recovers data spread at the top level (V result_to_http shape)', () => {
    expect(toEnvelope({ ok: true, message: 'done', tools: '7', missing: '2' })).toEqual({
      ok: true,
      message: 'done',
      data: { tools: '7', missing: '2' },
    });
  });

  it('stringifies non-string fields instead of dropping them', () => {
    expect(toEnvelope({ ok: false, message: 'nope', count: 3 }).data).toEqual({ count: '3' });
  });

  it('rejects non-object bodies', () => {
    expect(() => toEnvelope(null)).toThrow(ApiError);
    expect(() => toEnvelope('oops')).toThrow(ApiError);
  });

  it('merges the nested CmdResp data map instead of stringifying it', () => {
    const envelope = toEnvelope({ ok: true, message: 'm', data: { tool: 'matrix', days: 7 } });
    expect(envelope.data).toEqual({ tool: 'matrix', days: '7' });
  });
});

describe('requireOk', () => {
  it('passes successful envelopes through', () => {
    const envelope = toEnvelope({ ok: true, message: 'fine' });
    expect(requireOk(envelope)).toBe(envelope);
  });

  it('turns ok:false into a command error carrying the server message', () => {
    expect(() => requireOk(toEnvelope({ ok: false, message: 'workspace not found' }))).toThrow(
      expect.objectContaining({ kind: 'command', message: 'workspace not found' }),
    );
  });
});

describe('envelopeText', () => {
  it('unwraps a JSON payload whose text lives under report', () => {
    const envelope = toEnvelope({ ok: true, message: JSON.stringify({ tool: 'all', report: 'Total: 3 sessions' }) });
    expect(envelopeText(envelope)).toBe('Total: 3 sessions');
  });

  it('returns plain messages unchanged', () => {
    expect(envelopeText(toEnvelope({ ok: true, message: '{not json' }))).toBe('{not json');
  });
});

describe('recoveryHint', () => {
  it('explains the pre-gate backend 403 instead of echoing it', () => {
    expect(recoveryHint(new ApiError('denied', 403, 'cross-site request forbidden'))).toMatch(/older than the Desktop/);
  });

  it('points a missing workspace at a real action', () => {
    expect(recoveryHint(new ApiError('command', 200, 'workspace not found. Set AGENT_TOOLKIT_WORKSPACE'))).toMatch(
      /workspace folder/,
    );
  });
});

describe('normalizeLoopback', () => {
  it('rewrites localhost to the CSP-allowlisted 127.0.0.1', () => {
    expect(normalizeLoopback('http://localhost:3847')).toBe('http://127.0.0.1:3847');
    expect(normalizeLoopback('http://127.0.0.1:3847')).toBe('http://127.0.0.1:3847');
    expect(normalizeLoopback('not a url')).toBe('not a url');
  });
});

describe('job stream decoding', () => {
  it('maps V named SSE events', () => {
    expect(namedJobStreamEvent('status', 'running')).toEqual({ type: 'status', status: 'running' });
    expect(namedJobStreamEvent('log', 'agent-toolkit 1.35.0')).toEqual({ type: 'log', line: 'agent-toolkit 1.35.0' });
    expect(namedJobStreamEvent('done', 'failed\n')).toEqual({ type: 'done', status: 'failed' });
  });

  it('decodes unnamed frames defensively', () => {
    expect(parseJobStreamEvent('{"status":"running"}')).toEqual({ type: 'status', status: 'running' });
    expect(parseJobStreamEvent('{"line":"hello"}')).toEqual({ type: 'log', line: 'hello' });
    expect(parseJobStreamEvent('plain output')).toEqual({ type: 'log', line: 'plain output' });
    expect(parseJobStreamEvent('{oops').type).toBe('unknown');
  });
});

describe('ApiClient', () => {
  const calls: Array<{ url: string; init?: RequestInit }> = [];
  const client = (body: unknown, status = 200) =>
    new ApiClient('http://127.0.0.1:9', async (input, init) => {
      calls.push({ url: String(input), init });
      return new Response(typeof body === 'string' ? body : JSON.stringify(body), { status });
    });

  afterEach(() => {
    calls.length = 0;
    vi.restoreAllMocks();
  });

  it('sends every request with the first-party desktop header', async () => {
    await client({ id: 'job_x', status: 'canceled' }).cancelJob('job_x');
    const [first] = calls;
    expect(first?.url).toBe('http://127.0.0.1:9/api/v1/jobs/job_x/cancel');
    expect(first?.init?.method).toBe('POST');
    expect((first?.init?.headers as Record<string, string>)['x-atk-desktop']).toBe('1');
  });

  it('uses the typed read-only installer preview endpoint', async () => {
    const envelope = await client({ ok: true, message: 'DRY RUN', data: { dry_run: 'true' } }).installPreview();
    expect(envelope.data).toEqual({ dry_run: 'true' });
    expect(calls[0]?.url).toBe('http://127.0.0.1:9/api/v1/install/preview');
    expect(calls[0]?.init?.method).toBe('GET');
    expect(calls[0]?.init?.body).toBeUndefined();
  });

  it('reads project rows from the typed workspace roster endpoint', async () => {
    const response = await client({
      ok: true,
      projects: [{ name: 'demo', target: '../repos/demo', status: 'ok' }],
    }).projects('/workspace with spaces');
    expect(response.projects).toEqual([{ name: 'demo', target: '../repos/demo', status: 'ok' }]);
    expect(calls[0]?.url).toBe('http://127.0.0.1:9/api/v1/projects?workspace=%2Fworkspace+with+spaces');
    expect(calls[0]?.init?.method).toBe('GET');
  });

  it('reviews explicit installation targets and applies only that selection', async () => {
    const api = client({ ok: true, message: 'reviewed', data: { targets: 'cursor,opencode' } });
    await api.installPreview(['cursor', 'opencode']);
    expect(calls[0]?.url).toBe('http://127.0.0.1:9/api/v1/install/preview?tools=cursor%2Copencode');
    await api.installReviewed(['cursor', 'opencode']);
    expect(calls[1]?.url).toBe('http://127.0.0.1:9/api/v1/install/reviewed');
    expect(calls[1]?.init?.method).toBe('POST');
    expect(calls[1]?.init?.body).toBe('{"tools":["cursor","opencode"]}');
  });

  it('reviews and installs Copilot instructions only for a linked project', async () => {
    const payload = {
      ok: true,
      message: 'reviewed',
      project: 'demo',
      path: '.github/copilot-instructions.md',
      status: 'ready',
      review_token: 'snapshot',
      files_written: 0,
    };
    const api = client(payload);
    await api.copilotProjectInstallPreview('/workspace', 'demo', 'remove');
    expect(calls[0]?.url).toBe(
      'http://127.0.0.1:9/api/v1/install/copilot-project/preview?workspace=%2Fworkspace&project=demo&action=remove',
    );
    expect(calls[0]?.init?.method).toBe('GET');
    await api.copilotProjectInstallReviewed('/workspace', 'demo', 'remove', 'snapshot');
    expect(calls[1]?.url).toBe('http://127.0.0.1:9/api/v1/install/copilot-project/reviewed');
    expect(calls[1]?.init?.method).toBe('POST');
    expect(calls[1]?.init?.body).toBe(
      '{"workspace":"/workspace","project":"demo","action":"remove","review_token":"snapshot"}',
    );
  });

  it('reads installation evidence from the receipt endpoint', async () => {
    const response = await client({ ok: true, receipts: [] }).installReceipts();
    expect(response.receipts).toEqual([]);
    expect(calls[0]?.url).toBe('http://127.0.0.1:9/api/v1/install/receipts');
    expect(calls[0]?.init?.method).toBe('GET');
  });

  it('uses typed Person session history and lifecycle routes', async () => {
    const session = {
      id: 'session_1',
      person_id: 'lina',
      person: 'Lina',
      role: 'reviewer',
      project_id: 'agent-toolkit',
      cwd: '/workspace/projects/agent-toolkit',
      provider: 'opencode',
      model: '',
      status: 'launching',
      started_at: '2026-10-06T00:00:00Z',
      ended_at: '',
      exit_code: -1,
    };
    const api = client({ ok: true, sessions: [session], session });
    await api.personSessions('/workspace with space');
    await api.createPersonSession({
      workspace: '/workspace',
      person_id: 'lina',
      project_id: 'agent-toolkit',
      provider: 'opencode',
      model: '',
    });
    await api.updatePersonSession('/workspace', 'session_1', 'running');
    expect(calls.map((call) => [call.init?.method, call.url])).toEqual([
      ['GET', 'http://127.0.0.1:9/api/v1/sessions?workspace=%2Fworkspace+with+space'],
      ['POST', 'http://127.0.0.1:9/api/v1/sessions'],
      ['POST', 'http://127.0.0.1:9/api/v1/sessions/session_1/status'],
    ]);
    expect(calls[1]?.init?.body).toBe(
      '{"workspace":"/workspace","person_id":"lina","project_id":"agent-toolkit","provider":"opencode","model":""}',
    );
    expect(calls[2]?.init?.body).toBe('{"workspace":"/workspace","status":"running","exit_code":-1}');
  });

  it('loads MCP provider catalogue state from its typed endpoint', async () => {
    const response = await client({
      ok: true,
      message: '',
      config_path: '/home/test/.config/agent-toolkit/mcp-config.json',
      providers: [],
    }).mcpProviders();
    expect(response.config_path).toContain('mcp-config.json');
    expect(calls[0]?.url).toBe('http://127.0.0.1:9/api/v1/mcp/providers');
    expect(calls[0]?.init?.method).toBe('GET');
  });

  it('deletes with ?force=true only when forced', async () => {
    const api = client({ ok: true, message: 'deleted' });
    await api.deleteJob('job_x');
    await api.deleteJob('job_y', true);
    expect(calls.map((call) => call.url)).toEqual([
      'http://127.0.0.1:9/api/v1/jobs/job_x',
      'http://127.0.0.1:9/api/v1/jobs/job_y?force=true',
    ]);
    expect(calls.every((call) => call.init?.method === 'DELETE')).toBe(true);
  });

  it('routes a typed subcommand to /api/v1/<family>/<sub> with a JSON body', async () => {
    const envelope = await client({ ok: true, message: 'ctx' }).sub('workspace', 'context');
    expect(envelope.message).toBe('ctx');
    expect(calls[0]?.url).toBe('http://127.0.0.1:9/api/v1/workspace/context');
    expect(calls[0]?.init?.body).toBe('{}');
  });

  it('maps HTTP failures to typed errors with the server message', async () => {
    await expect(client({ ok: false, error: 'job already completed' }, 409).cancelJob('job_x')).rejects.toMatchObject({
      kind: 'conflict',
      status: 409,
      message: 'job already completed',
    });
    await expect(
      client({ ok: false, error: 'Unknown subcommand: info' }, 404).sub('plugin', 'check'),
    ).rejects.toMatchObject({ kind: 'not-found' });
  });

  it('reports an unreachable backend as a network error', async () => {
    const api = new ApiClient('http://127.0.0.1:9', async () => {
      throw new TypeError('Failed to fetch');
    });
    await expect(api.health()).rejects.toMatchObject({ kind: 'network', status: 0 });
  });

  it('builds the job events URL on the same origin', () => {
    expect(client({}).jobEventsUrl('job_1')).toBe('http://127.0.0.1:9/api/v1/jobs/job_1/events');
  });

  it('lists jobs with GET and retries with POST', async () => {
    const api = client({ id: 'job_y', status: 'queued', retry_of: 'job_x' });
    await api.jobs();
    await api.job('job_x');
    await api.retryJob('job_x');
    expect(calls.map((call) => `${call.init?.method} ${call.url}`)).toEqual([
      'GET http://127.0.0.1:9/api/v1/jobs',
      'GET http://127.0.0.1:9/api/v1/jobs/job_x',
      'POST http://127.0.0.1:9/api/v1/jobs/job_x/retry',
    ]);
  });

  it('builds the global events URL with a type filter', () => {
    const url = new URL(client({}).eventsUrl({ types: 'job.,loop.' }));
    expect(url.pathname).toBe('/api/v1/events');
    expect(url.searchParams.get('types')).toBe('job.,loop.');
  });

  it('reads the typed agents and tools catalogs', async () => {
    const api = client({ ok: true, agents: [], tools: [] });
    await api.agents();
    await api.tools();
    expect(calls.map((call) => call.url)).toEqual([
      'http://127.0.0.1:9/api/v1/agents',
      'http://127.0.0.1:9/api/v1/tools',
    ]);
  });

  it('reads typed loop definitions, status, history, audit, and cost by encoded name', async () => {
    const api = client({ ok: true, loops: [] });
    await api.loops();
    await api.loopStatusTyped('qa check');
    await api.loopHistory('qa check');
    await api.loopAudit('qa check');
    await api.loopCost('qa check');
    expect(calls.map((call) => `${call.init?.method} ${new URL(call.url).pathname}`)).toEqual([
      'GET /api/v1/loops',
      'GET /api/v1/loops/qa%20check/status',
      'GET /api/v1/loops/qa%20check/history',
      'GET /api/v1/loops/qa%20check/audit',
      'GET /api/v1/loops/qa%20check/cost',
    ]);
  });

  it('reads typed catalog GETs without wrapping them as envelopes', async () => {
    const api = client({ ok: true, tools: [{ id: 'cursor', enabled: 'unknown', detected: true }] });
    const tools = await api.tools();
    expect(tools.tools[0]?.enabled).toBe('unknown');
    expect(calls[0]?.url).toBe('http://127.0.0.1:9/api/v1/tools');
    expect(calls[0]?.init?.method).toBe('GET');
  });

  it('reads the typed skill catalog with target compatibility and dependencies', async () => {
    const api = client({ ok: true, count: 0, message: 'catalog metadata', skills: [] });
    const catalog = await api.librarySkills();
    expect(catalog.count).toBe(0);
    expect(calls[0]?.url).toBe('http://127.0.0.1:9/api/v1/skills/catalog');
    expect(calls[0]?.init?.method).toBe('GET');
  });

  it('lists swarm runs and posts typed run actions', async () => {
    const api = client({ ok: true, runs: [], message: 'ok', run_id: 'run_1', status: 'stopped' });
    await api.swarms();
    await api.swarmRun('run_1');
    await api.approveSwarm('run_1');
    await api.rejectSwarm('run_1');
    await api.stopSwarm('run_1');
    expect(calls.map((call) => `${call.init?.method} ${call.url}`)).toEqual([
      'GET http://127.0.0.1:9/api/v1/swarms',
      'GET http://127.0.0.1:9/api/v1/swarms/runs/run_1',
      'POST http://127.0.0.1:9/api/v1/swarms/runs/run_1/approve',
      'POST http://127.0.0.1:9/api/v1/swarms/runs/run_1/reject',
      'POST http://127.0.0.1:9/api/v1/swarms/runs/run_1/stop',
    ]);
  });

  it('reads canonical swarm recipe topology through the typed catalog route', async () => {
    const api = client({ ok: true, recipes: [], backends: [] });
    await api.swarmRecipes();
    expect(calls.map((call) => `${call.init?.method} ${new URL(call.url).pathname}`)).toEqual([
      'GET /api/v1/swarms/recipes',
    ]);
  });
});
