import path from 'node:path';
import type {
  FocusApprovalDecision,
  FocusEventBody,
  FocusModelOption,
  FocusPermissionMode,
  FocusToolKind,
  FocusUsage,
} from '../../src/types/focus';

/** What a provider adapter reports back to the session service. */
export interface AdapterSink {
  /** Provider-native session id (for resume) and the model actually in use. */
  session(providerSessionId: string, model: string | null): void;
  models(models: FocusModelOption[]): void;
  /** Live text for an item that has not been committed yet. */
  delta(itemId: string, channel: 'assistant' | 'reasoning', text: string): void;
  /** A completed, durable item. */
  item(
    body: Extract<FocusEventBody, { type: 'assistant' | 'reasoning' | 'tool.started' | 'tool.finished' | 'notice' }>,
  ): void;
  approval(request: Extract<FocusEventBody, { type: 'approval.requested' }>): void;
  /** The provider withdrew a pending approval (for example the call was cancelled). */
  approvalCancelled(requestId: string): void;
  turnFinished(result: {
    outcome: 'completed' | 'interrupted' | 'failed';
    detail: string | null;
    durationMs: number | null;
    usage: FocusUsage | null;
  }): void;
  /**
   * The provider process ended and all of its output has been delivered.
   * `expected` is true after dispose(); `beforeSession` is true when it died
   * without ever announcing a session (for example a resume id it no longer has).
   */
  exited(info: {
    code: number | null;
    signal: string | null;
    stderr: string;
    expected: boolean;
    beforeSession: boolean;
  }): void;
}

export interface AdapterStartOptions {
  binary: string;
  cwd: string;
  model: string | null;
  permissionMode: FocusPermissionMode;
  resumeSessionId: string | null;
  env: NodeJS.ProcessEnv;
}

/** One live provider process bound to one Focus thread. */
export interface ProviderSession {
  readonly alive: boolean;
  send(text: string): void;
  respondApproval(requestId: string, decision: FocusApprovalDecision): boolean;
  interrupt(): void;
  /** Release the process. `now` stops it at once (app shutdown) instead of letting it wind down. */
  dispose(now?: boolean): void;
}

export type ProviderSessionFactory = (options: AdapterStartOptions, sink: AdapterSink) => ProviderSession;

const OUTPUT_LIMIT = 24_000;
const INPUT_STRING_LIMIT = 12_000;

/**
 * Tool inputs can carry whole files (a Write call). The journal keeps enough
 * to show what was asked, not megabytes of content per call.
 */
export function clipInput(value: unknown, depth = 0): unknown {
  if (typeof value === 'string') {
    return value.length > INPUT_STRING_LIMIT
      ? `${value.slice(0, INPUT_STRING_LIMIT)}\n… (${value.length - INPUT_STRING_LIMIT} more characters not kept)`
      : value;
  }
  if (depth > 6 || typeof value !== 'object' || value === null) return value;
  if (Array.isArray(value)) return value.slice(0, 200).map((entry) => clipInput(entry, depth + 1));
  const out: Record<string, unknown> = {};
  for (const [key, entry] of Object.entries(value)) out[key] = clipInput(entry, depth + 1);
  return out;
}

/** Values that become argv entries must look like identifiers, never like flags. */
export function isSafeModelId(value: string): boolean {
  return /^[A-Za-z0-9][A-Za-z0-9._:\[\]/-]{0,119}$/.test(value);
}

export function isSafeSessionId(value: string): boolean {
  return /^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$/.test(value);
}

/** npm installs CLIs as .cmd shims on Windows; Node refuses to spawn those without a shell. */
export function needsShell(binary: string, platform: NodeJS.Platform = process.platform): boolean {
  return platform === 'win32' && /\.(cmd|bat)$/i.test(binary);
}

export function clipOutput(text: string): { output: string; truncated: boolean } {
  if (text.length <= OUTPUT_LIMIT) return { output: text, truncated: false };
  // Keep the head and the tail: errors usually live at the end.
  const head = text.slice(0, OUTPUT_LIMIT * 0.6);
  const tail = text.slice(text.length - OUTPUT_LIMIT * 0.4);
  return { output: `${head}\n…\n${tail}`, truncated: true };
}

function relative(cwd: string, file: unknown): string {
  if (typeof file !== 'string' || !file) return '';
  if (!path.isAbsolute(file)) return file;
  const rel = path.relative(cwd, file);
  return rel && !rel.startsWith('..') ? rel : file;
}

function firstLine(value: unknown, max = 160): string {
  if (typeof value !== 'string') return '';
  const line = value.split('\n').find((part) => part.trim()) ?? '';
  return line.length > max ? `${line.slice(0, max - 1)}…` : line;
}

function field(input: unknown, key: string): unknown {
  return typeof input === 'object' && input !== null ? (input as Record<string, unknown>)[key] : undefined;
}

/** Classify a provider tool call into a small, provider-neutral vocabulary. */
export function describeTool(name: string, input: unknown, cwd: string): { kind: FocusToolKind; title: string } {
  const lower = name.toLowerCase();
  if (lower === 'bash' || lower === 'shell' || lower === 'command_execution' || lower === 'exec') {
    return { kind: 'command', title: firstLine(field(input, 'command')) || name };
  }
  if (['edit', 'write', 'multiedit', 'notebookedit', 'file_change', 'apply_patch'].includes(lower)) {
    return { kind: 'edit', title: relative(cwd, field(input, 'file_path') ?? field(input, 'path')) || name };
  }
  if (lower === 'read' || lower === 'notebookread') {
    return { kind: 'read', title: relative(cwd, field(input, 'file_path') ?? field(input, 'path')) || name };
  }
  if (lower === 'grep' || lower === 'glob' || lower === 'ls' || lower === 'toolsearch') {
    const pattern = field(input, 'pattern') ?? field(input, 'query') ?? field(input, 'path');
    return { kind: 'search', title: firstLine(pattern) || name };
  }
  if (lower === 'webfetch' || lower === 'websearch') {
    return { kind: 'web', title: firstLine(field(input, 'url') ?? field(input, 'query')) || name };
  }
  if (lower === 'task' || lower === 'agent') {
    return { kind: 'agent', title: firstLine(field(input, 'description') ?? field(input, 'prompt')) || name };
  }
  return { kind: 'other', title: firstLine(field(input, 'description')) || name };
}

export function stringifyToolResult(content: unknown): string {
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) {
    return content
      .map((part) => {
        const text = field(part, 'text');
        if (typeof text === 'string') return text;
        const type = field(part, 'type');
        return typeof type === 'string' ? `[${type}]` : '';
      })
      .filter(Boolean)
      .join('\n');
  }
  if (content === undefined || content === null) return '';
  try {
    return JSON.stringify(content, null, 2);
  } catch {
    return String(content);
  }
}
