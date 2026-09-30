/**
 * Job SSE stream decoding (`GET /api/v1/jobs/{id}/events`).
 *
 * The V server emits *named* events: `status` (status word), `log` (one raw
 * line; the full log is replayed from line 0 on every connection) and `done`
 * (terminal status word), then closes the stream.
 */
export type JobStreamEvent =
  | { type: 'status'; status: string }
  | { type: 'log'; line: string }
  | { type: 'done'; status: string }
  | { type: 'unknown'; raw: string };

export const JOB_STREAM_EVENT_NAMES = ['status', 'log', 'done'] as const;
export type JobStreamEventName = (typeof JOB_STREAM_EVENT_NAMES)[number];

export function namedJobStreamEvent(type: JobStreamEventName, data: string): JobStreamEvent {
  if (type === 'status') return { type: 'status', status: data.trim() };
  if (type === 'log') return { type: 'log', line: data };
  return { type: 'done', status: data.trim() };
}

/** Unnamed frames are outside the V contract; decode defensively instead of dropping them. */
export function parseJobStreamEvent(data: string): JobStreamEvent {
  const trimmed = data.trim();
  if (trimmed.startsWith('{')) {
    try {
      const parsed = JSON.parse(trimmed) as Record<string, unknown>;
      if (typeof parsed['status'] === 'string') return { type: 'status', status: parsed['status'] };
      if (typeof parsed['line'] === 'string') return { type: 'log', line: parsed['line'] };
    } catch {
      return { type: 'unknown', raw: data };
    }
    return { type: 'unknown', raw: data };
  }
  return { type: 'log', line: data };
}
