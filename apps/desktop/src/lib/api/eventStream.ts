import { API_EVENT_TYPES, type ApiEvent, type ApiEventType } from './contracts';

const EVENT_TYPE_SET = new Set<string>(API_EVENT_TYPES);

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function asInt(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

export function isApiEventType(value: string): value is ApiEventType {
  return EVENT_TYPE_SET.has(value);
}

/** Decode one GET /api/v1/events frame. Named SSE `event:` is preferred over JSON `type`. */
export function parseApiEvent(data: string, namedType?: string): ApiEvent | null {
  try {
    const parsed: unknown = JSON.parse(data);
    if (!isRecord(parsed)) return null;
    const fromJson = asString(parsed['type']);
    const type = namedType && isApiEventType(namedType) ? namedType : fromJson;
    if (!isApiEventType(type)) return null;
    return {
      seq: asInt(parsed['seq']),
      boot: asString(parsed['boot']),
      type,
      at: asString(parsed['at']),
      subject: asString(parsed['subject']),
      status: asString(parsed['status']),
      exit_code: asInt(parsed['exit_code']),
      ref: asString(parsed['ref']),
      message: asString(parsed['message']),
    };
  } catch {
    return null;
  }
}
