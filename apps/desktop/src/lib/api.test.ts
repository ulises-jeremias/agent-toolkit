import { afterEach, describe, expect, it, vi } from 'vitest';
import { ApiClient, ApiError, namedJobStreamEvent, parseJobStreamEvent, toEnvelope } from './api';
import { normalizeLoopback } from './query';

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
    // Wire shape of matrix/insights/:sub routes: {ok, message, data: {...}}.
    const envelope = toEnvelope({ ok: true, message: 'm', data: { tool: 'matrix', days: 7 } });
    expect(envelope.data).toEqual({ tool: 'matrix', days: '7' });
  });

  it('keeps top-level spread fields for raw-map routes', () => {
    const envelope = toEnvelope({ id: 'j1', status: 'running' });
    expect(envelope.data).toEqual({ id: 'j1', status: 'running' });
  });
});

describe('normalizeLoopback', () => {
  it('rewrites localhost to the CSP-allowlisted 127.0.0.1', () => {
    expect(normalizeLoopback('http://localhost:3847')).toBe('http://127.0.0.1:3847');
    expect(normalizeLoopback('http://127.0.0.1:3847')).toBe('http://127.0.0.1:3847');
    expect(normalizeLoopback('not a url')).toBe('not a url');
  });
});

describe('parseJobStreamEvent', () => {
  it('parses JSON status payloads', () => {
    expect(parseJobStreamEvent('{"status":"running"}')).toEqual({ type: 'status', status: 'running' });
  });

  it('parses JSON log lines', () => {
    expect(parseJobStreamEvent('{"line":"hello"}')).toEqual({ type: 'log', line: 'hello' });
  });

  it('parses done payloads with either exit key', () => {
    expect(parseJobStreamEvent('{"exit_code":1}')).toEqual({ type: 'done', exitCode: 1 });
    expect(parseJobStreamEvent('{"exitCode":0}')).toEqual({ type: 'done', exitCode: 0 });
  });

  it('falls back to plain-text log lines', () => {
    expect(parseJobStreamEvent('plain output')).toEqual({ type: 'log', line: 'plain output' });
  });

  it('marks malformed JSON as unknown', () => {
    const event = parseJobStreamEvent('{oops');
    expect(event.type).toBe('unknown');
  });
});

describe('namedJobStreamEvent', () => {
  it('maps V named SSE events (server emits event: status/log/done, never onmessage)', () => {
    expect(namedJobStreamEvent('status', 'running')).toEqual({ type: 'status', status: 'running' });
    expect(namedJobStreamEvent('log', 'agent-toolkit 1.35.0')).toEqual({
      type: 'log',
      line: 'agent-toolkit 1.35.0',
    });
    expect(namedJobStreamEvent('done', 'completed')).toEqual({ type: 'done', exitCode: 0 });
    expect(namedJobStreamEvent('done', 'failed')).toEqual({ type: 'done', exitCode: 1 });
  });
});

describe('ApiError', () => {
  it('carries kind, status, and message', () => {
    const error = new ApiError('not-found', 404, 'missing');
    expect(error).toBeInstanceOf(Error);
    expect(error.kind).toBe('not-found');
    expect(error.status).toBe(404);
    expect(error.message).toBe('missing');
  });
});

describe('ApiClient job lifecycle', () => {
  const calls: Array<{ url: string; init?: RequestInit }> = [];
  const stubFetch = (body: unknown, status = 200) => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async (url: string, init?: RequestInit) => {
        calls.push({ url, init });
        return {
          ok: status >= 200 && status < 300,
          status,
          json: async () => body,
        } as Response;
      }),
    );
  };

  afterEach(() => {
    vi.unstubAllGlobals();
    calls.length = 0;
  });

  it('jobsCancel POSTs to the cancel route with the desktop header', async () => {
    stubFetch({ id: 'job_x', status: 'canceled' });
    const job = await new ApiClient('http://127.0.0.1:9').jobsCancel('job_x');
    expect(job.status).toBe('canceled');
    expect(calls).toHaveLength(1);
    const [first] = calls;
    expect(first?.url).toBe('http://127.0.0.1:9/api/v1/jobs/job_x/cancel');
    expect(first?.init?.method).toBe('POST');
    expect((first?.init?.headers as Record<string, string>)['x-atk-desktop']).toBe('1');
  });

  it('jobsDelete sends DELETE, adding ?force=true only when forced', async () => {
    stubFetch({ ok: true, message: 'deleted job_x' });
    const client = new ApiClient('http://127.0.0.1:9');
    await client.jobsDelete('job_x');
    await client.jobsDelete('job_y', true);
    expect(calls.map((call) => call.url)).toEqual([
      'http://127.0.0.1:9/api/v1/jobs/job_x',
      'http://127.0.0.1:9/api/v1/jobs/job_y?force=true',
    ]);
    expect(calls.every((call) => call.init?.method === 'DELETE')).toBe(true);
  });

  it('maps 409 from cancel to a conflict error', async () => {
    stubFetch({ ok: false, error: 'job already completed: job_x' }, 409);
    await expect(new ApiClient('http://127.0.0.1:9').jobsCancel('job_x')).rejects.toMatchObject({
      kind: 'conflict',
      status: 409,
    });
  });
});
