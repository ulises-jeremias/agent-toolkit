import { describe, expect, it } from 'vitest';
import { basename, EMPTY_CONTEXT, readContext, withContext, writeContext } from './sessionContext';

describe('readContext', () => {
  it('reads workspace, agent and run and ignores other params', () => {
    const params = new URLSearchParams('workspace=/home/u/.ai-workspace&agent=architect&run=run-1&job=job_1');
    expect(readContext(params)).toEqual({
      workspace: '/home/u/.ai-workspace',
      agent: 'architect',
      run: 'run-1',
    });
  });

  it('treats missing keys as empty', () => {
    expect(readContext(new URLSearchParams())).toEqual(EMPTY_CONTEXT);
  });
});

describe('writeContext', () => {
  it('sets, replaces and clears without dropping unrelated params', () => {
    const start = new URLSearchParams('job=job_1&agent=old');
    const next = writeContext(start, { agent: 'architect', workspace: '/ws', run: '' });
    expect(next.get('job')).toBe('job_1');
    expect(next.get('agent')).toBe('architect');
    expect(next.get('workspace')).toBe('/ws');
    expect(next.has('run')).toBe(false);
  });
});

describe('withContext', () => {
  it('builds a destination href that later screens can keep', () => {
    expect(withContext('/operations', { workspace: '/ws', agent: 'a', run: '' }, { job: 'j1' })).toBe(
      '/operations?workspace=%2Fws&agent=a&job=j1',
    );
  });

  it('omits the query when nothing is in scope', () => {
    expect(withContext('/office', EMPTY_CONTEXT)).toBe('/office');
  });
});

describe('basename', () => {
  it('returns the last path segment', () => {
    expect(basename('/home/u/.ai-workspace/')).toBe('.ai-workspace');
  });
});
