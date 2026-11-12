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
  turnFinished(result: {
    outcome: 'completed' | 'interrupted' | 'failed';
    detail: string | null;
    durationMs: number | null;
    usage: FocusUsage | null;
  }): void;
  /** The provider process ended. `expected` is true after dispose(). */
  exited(info: { code: number | null; signal: string | null; stderr: string; expected: boolean }): void;
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
  dispose(): void;
}

export type ProviderSessionFactory = (options: AdapterStartOptions, sink: AdapterSink) => ProviderSession;

const OUTPUT_LIMIT = 24_000;

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
