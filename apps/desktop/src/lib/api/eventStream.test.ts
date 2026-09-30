import { describe, expect, it } from 'vitest';
import { parseApiEvent } from './eventStream';

describe('parseApiEvent', () => {
  it('reads a named SSE frame', () => {
    expect(
      parseApiEvent(
        JSON.stringify({
          seq: 4,
          boot: 'b1',
          type: 'job.updated',
          at: '2026-09-30T12:00:00Z',
          subject: 'job_1',
          status: 'failed',
          exit_code: 1,
          ref: '',
          message: '',
        }),
        'job.updated',
      ),
    ).toMatchObject({ type: 'job.updated', subject: 'job_1', status: 'failed', exit_code: 1 });
  });

  it('prefers the SSE event name when JSON type is missing', () => {
    expect(parseApiEvent('{"seq":1,"boot":"b","subject":"serve"}', 'backend.resync')?.type).toBe('backend.resync');
  });

  it('returns null for unknown types instead of inventing one', () => {
    expect(parseApiEvent('{"type":"attention.created"}')).toBeNull();
    expect(parseApiEvent('not-json', 'job.updated')).toBeNull();
  });
});
