/**
 * Response shapes the OpenAPI contract does not document yet, mirrored from
 * the V server. Each is used only as the `Fallback` of `ResponseOf`, so a
 * schema that starts documenting the route takes over automatically.
 */

/** modules/agent_toolkit_server/server.veb.v `health` / `version`. */
export interface VersionResponse {
  ok: boolean;
  version: string;
  commit?: string;
  uptime_s?: number;
}

export type SelfcheckStatus = 'ok' | 'warn' | 'err';

export interface SelfcheckCheck {
  name: string;
  status: SelfcheckStatus;
  detail: string;
}

/** server.veb.v `selfcheck`. */
export interface SelfcheckResponse {
  ok: boolean;
  version: string;
  commit: string;
  checks: SelfcheckCheck[];
}

/** modules/agent_toolkit_server/jobs.v: `is_terminal` covers completed/failed/canceled/rejected. */
export type JobStatus = 'queued' | 'running' | 'completed' | 'failed' | 'canceled' | 'rejected';

const TERMINAL_JOB_STATUSES: ReadonlySet<string> = new Set(['completed', 'failed', 'canceled', 'rejected']);

export function isTerminalJobStatus(status: string): boolean {
  return TERMINAL_JOB_STATUSES.has(status);
}

/** jobs.v `Job`. `status` stays open: an unknown word is shown verbatim, never coerced. */
export interface Job {
  id: string;
  cmd: string;
  args: string[];
  status: JobStatus | (string & {});
  started_at: string;
  ended_at: string;
  exit_code: number;
  workspace: string;
}

/** `GET /api/v1/jobs` returns the registry keyed by job id. */
export type JobRegistry = Record<string, Job>;

/** server.veb.v `JobCreateReq`. */
export interface JobCreateRequest {
  cmd: string;
  args?: string[];
  workspace?: string;
}

/** server.veb.v `MsgResp`. */
export interface MessageResponse {
  ok: boolean;
  message: string;
}

/** OpenAPI `MemoryEntry` (list omits body). */
export interface MemoryEntry {
  id: string;
  kind: string;
  title: string;
  snippet: string;
  body: string;
  tags: string[];
  provenance: {
    file: string;
    author: string;
    timestamp: string;
    project: string;
    agent: string;
  };
}

export interface MemoryListResponse {
  ok: boolean;
  entries: MemoryEntry[];
}

/** OpenAPI `ApiEvent.type` on GET /api/v1/events. */
export type ApiEventType =
  | 'backend.ready'
  | 'backend.resync'
  | 'job.created'
  | 'job.updated'
  | 'job.deleted'
  | 'loop.started'
  | 'loop.finished'
  | 'swarm.changed'
  | 'memory.changed'
  | 'install.started'
  | 'install.finished';

export interface ApiEvent {
  seq: number;
  boot: string;
  type: ApiEventType | (string & {});
  at: string;
  subject: string;
  status: string;
  exit_code: number;
  ref: string;
  message: string;
}
