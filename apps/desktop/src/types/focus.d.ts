/**
 * Focus session model (ADR-044). One canonical thread/turn/event vocabulary
 * shared by the Electron session runtime and the renderer. Provider adapters
 * normalise their native streams into these events; the journal on disk is
 * the only source of truth for history.
 *
 * Declaration-only module: it is imported by both the commonjs Electron
 * build (whose rootDir is electron/) and the renderer bundle.
 */

export type FocusProviderId = 'claude' | 'codex' | 'opencode';

/** How much the agent may do without asking. Mapped per provider. */
export type FocusPermissionMode = 'ask' | 'accept-edits' | 'plan' | 'bypass';

export type FocusThreadStatus = 'idle' | 'running' | 'awaiting-approval' | 'interrupted' | 'error';

export interface FocusModelOption {
  id: string;
  label: string;
  description?: string;
}

export interface FocusProviderCapabilities {
  /** Structured Focus sessions are implemented for this provider. */
  sessions: boolean;
  approvals: boolean;
  interrupt: boolean;
  resume: boolean;
  modelSwitch: boolean;
}

export interface FocusProviderStatus {
  id: FocusProviderId;
  label: string;
  installed: boolean;
  binary: string | null;
  version: string | null;
  /** `ready` only when the provider's own CLI reports a signed-in account. */
  auth: 'ready' | 'signed-out' | 'unknown';
  /** Human-readable, never contains account identifiers. */
  authDetail: string;
  /** Command the user can run to sign in, when signed out. */
  signInHint: string | null;
  /** Permission modes reported by the installed CLI; omitted for adapters without this probe. */
  permissionModes?: FocusPermissionMode[];
  models: FocusModelOption[];
  capabilities: FocusProviderCapabilities;
  checkedAt: string;
}

export interface FocusUsage {
  /** Fresh input tokens (including cache writes). */
  inputTokens: number;
  /** Input tokens served from the provider's prompt cache. */
  cachedInputTokens: number;
  outputTokens: number;
  /** Provider-reported API-equivalent cost; null when the provider reports none. */
  costUsd: number | null;
}

export interface FocusThread {
  id: string;
  title: string;
  /** Durable workspace Person identity when this thread was started from People. */
  personId?: string | null;
  workspace: string;
  projectName: string | null;
  cwd: string;
  provider: FocusProviderId;
  /** The model the user picked; null means the provider's default. */
  model: string | null;
  /** The model the provider reported it is actually using. */
  resolvedModel: string | null;
  permissionMode: FocusPermissionMode;
  /** Provider-native session/thread id used for resume; null until the provider reports one. */
  providerSessionId: string | null;
  status: FocusThreadStatus;
  createdAt: string;
  updatedAt: string;
  turns: number;
  lastError: string | null;
  usage: FocusUsage;
}

export type FocusToolKind = 'command' | 'edit' | 'read' | 'search' | 'web' | 'agent' | 'other';

export type FocusApprovalDecision = 'allow' | 'allow-session' | 'deny';

export type FocusEventBody =
  | { type: 'user'; text: string }
  | { type: 'turn.started'; model: string | null }
  | { type: 'assistant'; itemId: string; text: string }
  | { type: 'reasoning'; itemId: string; text: string }
  | {
      type: 'tool.started';
      itemId: string;
      name: string;
      kind: FocusToolKind;
      title: string;
      input: unknown;
      /** Set when the call was made by a provider-native subagent. */
      parentItemId: string | null;
    }
  | { type: 'tool.finished'; itemId: string; ok: boolean; output: string; truncated: boolean }
  | {
      type: 'approval.requested';
      requestId: string;
      itemId: string | null;
      tool: string;
      kind: FocusToolKind;
      title: string;
      input: unknown;
      canAllowForSession: boolean;
    }
  | {
      type: 'approval.resolved';
      requestId: string;
      decision: FocusApprovalDecision;
      by: 'user' | 'interrupt' | 'shutdown';
    }
  | {
      type: 'turn.finished';
      outcome: 'completed' | 'interrupted' | 'failed';
      detail: string | null;
      durationMs: number | null;
      usage: FocusUsage | null;
    }
  | { type: 'notice'; level: 'info' | 'warning' | 'error'; text: string };

export type FocusEvent = { seq: number; at: string; turn: number } & FocusEventBody;

export interface FocusThreadSnapshot {
  thread: FocusThread;
  events: FocusEvent[];
}

/** Pushed from main to the renderer. Deltas are live-only and never journaled. */
export type FocusLiveUpdate =
  | { kind: 'event'; threadId: string; event: FocusEvent }
  | { kind: 'delta'; threadId: string; itemId: string; channel: 'assistant' | 'reasoning'; text: string }
  | { kind: 'thread'; thread: FocusThread }
  | { kind: 'removed'; threadId: string };

export interface FocusCreateThreadInput {
  cwd: string;
  projectName: string | null;
  personId?: string | null;
  provider: FocusProviderId;
  model: string | null;
  permissionMode: FocusPermissionMode;
  title?: string;
}

export interface FocusThreadPatch {
  title?: string;
  model?: string | null;
  permissionMode?: FocusPermissionMode;
}

export type FocusResult<T> = { ok: true; value: T } | { ok: false; error: string };

export interface FocusBridge {
  providers: (options?: { refresh?: boolean }) => Promise<FocusProviderStatus[]>;
  listThreads: () => Promise<FocusThread[]>;
  createThread: (input: FocusCreateThreadInput) => Promise<FocusResult<FocusThread>>;
  readThread: (id: string) => Promise<FocusThreadSnapshot | null>;
  updateThread: (id: string, patch: FocusThreadPatch) => Promise<FocusResult<FocusThread>>;
  deleteThread: (id: string) => Promise<FocusResult<true>>;
  send: (id: string, text: string) => Promise<FocusResult<true>>;
  respondApproval: (id: string, requestId: string, decision: FocusApprovalDecision) => Promise<FocusResult<true>>;
  interrupt: (id: string) => Promise<FocusResult<true>>;
  onUpdate: (listener: (update: FocusLiveUpdate) => void) => () => void;
}
