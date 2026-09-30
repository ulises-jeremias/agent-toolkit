import { ApiError } from './errors';

/**
 * Generic command envelope returned by report and `:sub` routes until they
 * gain typed response schemas. The V server (`result_to_http` in
 * modules/agent_toolkit_server/read.v) spreads data fields at the top level;
 * `CmdResp` routes nest them under `data`. Both normalize to this shape.
 */
export interface CommandEnvelope {
  ok: boolean;
  message: string;
  data: Record<string, string>;
}

export function toEnvelope(wire: unknown): CommandEnvelope {
  if (typeof wire !== 'object' || wire === null) {
    throw new ApiError('server', 200, 'backend returned a non-object envelope');
  }
  const record = wire as Record<string, unknown>;
  const ok = record['ok'] === true;
  const message = typeof record['message'] === 'string' ? record['message'] : '';
  const data: Record<string, string> = {};
  const mergeFields = (obj: Record<string, unknown>): void => {
    for (const [key, value] of Object.entries(obj)) {
      if (key === 'ok' || key === 'message' || key === 'data') continue;
      data[key] = typeof value === 'string' ? value : JSON.stringify(value);
    }
  };
  mergeFields(record);
  // Nested wins on key conflict: it is the structured server payload.
  const nested = record['data'];
  if (typeof nested === 'object' && nested !== null && !Array.isArray(nested)) {
    mergeFields(nested as Record<string, unknown>);
  }
  return { ok, message, data };
}

/** Treat a command-level failure as an error so views render it as one. */
export function requireOk(envelope: CommandEnvelope): CommandEnvelope {
  if (!envelope.ok) {
    throw new ApiError('command', 200, envelope.message || envelope.data['error'] || 'The command failed.');
  }
  return envelope;
}
