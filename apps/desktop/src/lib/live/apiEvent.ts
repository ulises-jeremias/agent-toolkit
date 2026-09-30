import type { ApiEvent } from '../api';

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function asNumber(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

/** Decode one `data:` JSON frame from GET /api/v1/events. Unknown shapes are dropped. */
export function parseApiEvent(data: string): ApiEvent | null {
  try {
    const parsed: unknown = JSON.parse(data);
    if (!isRecord(parsed)) return null;
    const type = asString(parsed['type']);
    if (!type) return null;
    return {
      seq: asNumber(parsed['seq']),
      boot: asString(parsed['boot']),
      type,
      at: asString(parsed['at']),
      subject: asString(parsed['subject']),
      status: asString(parsed['status']),
      exit_code: asNumber(parsed['exit_code']),
      ref: asString(parsed['ref']),
      message: asString(parsed['message']),
    };
  } catch {
    return null;
  }
}

export const BUS_EVENT_NAMES = [
  'backend.ready',
  'backend.resync',
  'job.created',
  'job.updated',
  'job.deleted',
] as const;

export type BusEventName = (typeof BUS_EVENT_NAMES)[number];
