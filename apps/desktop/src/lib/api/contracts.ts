/**
 * Response shapes the OpenAPI contract does not document yet, mirrored from
 * the V server. Each is used only as the `Fallback` of `ResponseOf`, so a
 * schema that starts documenting the route takes over automatically.
 */
import type { components } from '../api-schema';

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
const RETRYABLE_JOB_STATUSES: ReadonlySet<string> = new Set(['failed', 'canceled']);

export function isTerminalJobStatus(status: string): boolean {
  return TERMINAL_JOB_STATUSES.has(status);
}

/** POST /api/v1/jobs/{id}/retry accepts only failed or canceled jobs (409 otherwise). */
export function isRetryableJobStatus(status: string): boolean {
  return RETRYABLE_JOB_STATUSES.has(status);
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
  /** Empty unless this run was created by POST /api/v1/jobs/{id}/retry. */
  retry_of: string;
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

/** OpenAPI `MemoryHit` from GET /api/v1/memory/hits. */
export interface MemoryHit {
  path: string;
  line: number;
  snippet: string;
  kind: string;
}

export interface MemorySearchResponse {
  ok: boolean;
  query: string;
  hits: MemoryHit[];
}

export interface MemoryReadResponse {
  ok: boolean;
  entry: MemoryEntry;
}

export interface MemoryWriteResponse {
  ok: boolean;
  message: string;
  path: string;
}

/** OpenAPI `WorkspaceFileNode` from GET /api/v1/files. */
export interface WorkspaceFileNode {
  name: string;
  path: string;
  kind: 'file' | 'dir';
  size: number;
  depth: number;
  masked: boolean;
}

export interface WorkspaceFileListResponse {
  ok: boolean;
  root: string;
  nodes: WorkspaceFileNode[];
}

export interface WorkspaceFileReadResponse {
  ok: boolean;
  path: string;
  name: string;
  content: string;
  size: number;
  binary: boolean;
  truncated: boolean;
  masked: boolean;
}

export interface WorkspaceFileHit {
  path: string;
  line: number;
  snippet: string;
}

export interface WorkspaceFileSearchResponse {
  ok: boolean;
  query: string;
  hits: WorkspaceFileHit[];
}

/** OpenAPI `ApiEvent.type` on GET /api/v1/events. Unknown types stay verbatim. */
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

export type AgentsResponse = components['schemas']['AgentsResponse'];
export type AgentInfo = components['schemas']['AgentInfo'];
export type ToolsResponse = components['schemas']['ToolsResponse'];
export type ToolInfo = components['schemas']['ToolInfo'];
export type ToolEnabled = ToolInfo['enabled'];
export type ProvidersResponse = components['schemas']['ProvidersResponse'];
export type ProviderInfo = components['schemas']['ProviderInfo'];
export type ModelsResponse = components['schemas']['ModelsResponse'];
export type ModelInfo = components['schemas']['ModelInfo'];
export type SwarmListResponse = components['schemas']['SwarmListResponse'];
export type SwarmRunInfo = components['schemas']['SwarmRunInfo'];
export type SwarmRunResponse = components['schemas']['SwarmRunResponse'];
export type SwarmActionResponse = components['schemas']['SwarmActionResponse'];

export const API_EVENT_TYPES: readonly ApiEventType[] = [
  'backend.ready',
  'backend.resync',
  'job.created',
  'job.updated',
  'job.deleted',
  'loop.started',
  'loop.finished',
  'swarm.changed',
  'memory.changed',
  'install.started',
  'install.finished',
] as const;
