import { describe, expect, it } from 'vitest';
import { ApiError, namedJobStreamEvent, parseJobStreamEvent, toEnvelope } from './api';

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
