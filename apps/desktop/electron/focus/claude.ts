import { spawn, type ChildProcessWithoutNullStreams } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import readline from 'node:readline';
import type { FocusApprovalDecision, FocusModelOption, FocusPermissionMode } from '../../src/types/focus';
import {
  clipInput,
  clipOutput,
  describeTool,
  isSafeModelId,
  isSafeSessionId,
  needsShell,
  stringifyToolResult,
  type AdapterSink,
  type AdapterStartOptions,
  type ProviderSession,
} from './adapter';

/**
 * Claude Code adapter (ADR-044). Drives the user's installed `claude` CLI in
 * its bidirectional stream-json mode: NDJSON on stdin/stdout, with tool
 * permission prompts delivered as `control_request` frames. No API key and no
 * bundled SDK: the session uses whatever account the CLI is signed in with.
 *
 * Protocol facts below were measured against claude 2.1.322 (see
 * docs/desktop/RESCUE.md); unknown frames are ignored, never guessed at.
 */

const PERMISSION_MODE: Record<FocusPermissionMode, string> = {
  // `default` may auto-allow tools based on Claude Code's own heuristics or
  // settings. Focus's Ask mode promises an explicit user decision, so use the
  // CLI's manual mode and route every prompt through the stdio approval bridge.
  ask: 'manual',
  'accept-edits': 'acceptEdits',
  plan: 'plan',
  bypass: 'bypassPermissions',
};

/** Variables set by a parent Claude Code process; a child session must not inherit them. */
const INHERITED_SESSION_ENV = [
  'CLAUDECODE',
  'CLAUDE_CODE_ENTRYPOINT',
  'CLAUDE_CODE_SSE_PORT',
  'CLAUDE_CODE_SESSION_ID',
  'CLAUDE_CODE_EXECPATH',
];

export function claudeArgs(
  options: Pick<AdapterStartOptions, 'model' | 'permissionMode' | 'resumeSessionId'>,
): string[] {
  const args = [
    '-p',
    '--output-format',
    'stream-json',
    '--input-format',
    'stream-json',
    '--verbose',
    '--include-partial-messages',
    '--permission-prompt-tool',
    'stdio',
    '--permission-mode',
    PERMISSION_MODE[options.permissionMode],
  ];
  // Only identifier-shaped values reach argv, so neither can be read as a flag.
  if (options.model && isSafeModelId(options.model)) args.push('--model', options.model);
  if (options.resumeSessionId && isSafeSessionId(options.resumeSessionId)) {
    args.push('--resume', options.resumeSessionId);
  }
  return args;
}

type Json = Record<string, unknown>;

function asRecord(value: unknown): Json | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? (value as Json) : null;
}

function asString(value: unknown): string | null {
  return typeof value === 'string' ? value : null;
}

/** "For this session" must never write a rule that outlives the session. */
function sessionScoped(suggestions: unknown): unknown[] {
  if (!Array.isArray(suggestions)) return [];
  return suggestions.filter((entry) => asRecord(entry)?.['destination'] === 'session');
}

interface PendingApproval {
  input: unknown;
  sessionRules: unknown[];
}

interface LiveItem {
  itemId: string;
  channel: 'assistant' | 'reasoning';
}

export class ClaudeSession implements ProviderSession {
  private readonly child: ChildProcessWithoutNullStreams;
  private readonly approvals = new Map<string, PendingApproval>();
  /** Stream blocks (by API message id + index) awaiting their committed message. */
  private readonly liveByBlock = new Map<string, LiveItem>();
  private readonly liveQueue: LiveItem[] = [];
  private stderrTail = '';
  private disposed = false;
  private exited = false;
  private interruptRequested = false;
  private sessionId: string | null = null;

  constructor(
    private readonly options: AdapterStartOptions,
    private readonly sink: AdapterSink,
    /** Tests run a scripted stand-in through `node`; production passes nothing. */
    argsPrefix: readonly string[] = [],
  ) {
    const env = { ...options.env };
    for (const name of INHERITED_SESSION_ENV) delete env[name];
    this.child = spawn(options.binary, [...argsPrefix, ...claudeArgs(options)], {
      cwd: options.cwd,
      env,
      stdio: ['pipe', 'pipe', 'pipe'],
      // Its own process group on POSIX, so stopping the session also stops what its tools started.
      detached: process.platform !== 'win32',
      shell: needsShell(options.binary),
      windowsHide: true,
    });
    this.child.stderr.on('data', (chunk: Buffer) => {
      this.stderrTail = (this.stderrTail + chunk.toString('utf8')).slice(-4_000);
    });
    this.child.stdin.on('error', () => undefined);
    readline.createInterface({ input: this.child.stdout }).on('line', (line) => {
      try {
        this.onLine(line);
      } catch (error) {
        // One bad frame or a failed journal write must not take the app down.
        console.error('Focus: dropped a provider frame:', error);
      }
    });
    this.child.on('error', (error) => {
      this.stderrTail = `${this.stderrTail}\n${error.message}`.trim();
      this.onClose(null, null);
    });
    // `close` (not `exit`) fires after stdout and stderr are drained: the final
    // result frame and the error text are delivered before the exit is reported.
    this.child.on('close', (code, signal) => this.onClose(code, signal));
    this.write({ type: 'control_request', request_id: randomUUID(), request: { subtype: 'initialize', hooks: null } });
  }

  get alive(): boolean {
    return !this.exited && !this.disposed;
  }

  send(text: string): void {
    this.write({
      type: 'user',
      message: { role: 'user', content: [{ type: 'text', text }] },
      parent_tool_use_id: null,
      session_id: this.sessionId ?? '',
    });
  }

  respondApproval(requestId: string, decision: FocusApprovalDecision): boolean {
    const pending = this.approvals.get(requestId);
    if (!pending) return false;
    this.approvals.delete(requestId);
    const response: Json =
      decision === 'deny'
        ? { behavior: 'deny', message: 'The user denied this action.' }
        : { behavior: 'allow', updatedInput: pending.input };
    if (decision === 'allow-session' && pending.sessionRules.length > 0) {
      response['updatedPermissions'] = pending.sessionRules;
    }
    this.write({ type: 'control_response', response: { subtype: 'success', request_id: requestId, response } });
    return true;
  }

  interrupt(): void {
    if (!this.alive) return;
    this.interruptRequested = true;
    // Pending prompts die with the turn; answer them so the CLI is not left waiting.
    for (const requestId of [...this.approvals.keys()]) this.respondApproval(requestId, 'deny');
    this.write({ type: 'control_request', request_id: randomUUID(), request: { subtype: 'interrupt' } });
  }

  dispose(now = false): void {
    if (this.disposed) return;
    this.disposed = true;
    if (this.exited) return;
    if (now) {
      this.kill('SIGTERM');
      return;
    }
    try {
      this.child.stdin.end();
    } catch {
      // Already closed.
    }
    setTimeout(() => {
      if (!this.exited) this.kill('SIGTERM');
    }, 1_500).unref();
    setTimeout(() => {
      if (!this.exited) this.kill('SIGKILL');
    }, 5_000).unref();
  }

  private kill(signal: NodeJS.Signals): void {
    const pid = this.child.pid;
    try {
      if (pid !== undefined && process.platform !== 'win32') process.kill(-pid, signal);
      else this.child.kill(signal);
    } catch {
      // Already gone.
    }
  }

  private write(frame: Json): void {
    if (this.exited || this.child.stdin.destroyed) return;
    this.child.stdin.write(`${JSON.stringify(frame)}\n`);
  }

  private onClose(code: number | null, signal: string | null): void {
    if (this.exited) return;
    this.exited = true;
    this.sink.exited({
      code,
      signal,
      stderr: this.stderrTail.trim(),
      expected: this.disposed,
      beforeSession: this.sessionId === null,
    });
  }

  private onLine(line: string): void {
    let frame: Json | null;
    try {
      frame = asRecord(JSON.parse(line));
    } catch {
      return;
    }
    if (!frame) return;
    switch (frame['type']) {
      case 'system':
        this.onSystem(frame);
        return;
      case 'control_response':
        this.onControlResponse(frame);
        return;
      case 'control_request':
        this.onControlRequest(frame);
        return;
      case 'control_cancel_request':
        this.onControlCancel(frame);
        return;
      case 'stream_event':
        this.onStreamEvent(frame);
        return;
      case 'assistant':
        this.onAssistant(frame);
        return;
      case 'user':
        this.onUser(frame);
        return;
      case 'result':
        this.onResult(frame);
        return;
      default:
        return;
    }
  }

  private onSystem(frame: Json): void {
    if (frame['subtype'] !== 'init') return;
    const sessionId = asString(frame['session_id']);
    if (!sessionId) return;
    this.sessionId = sessionId;
    this.sink.session(sessionId, asString(frame['model']));
  }

  private onControlResponse(frame: Json): void {
    const response = asRecord(asRecord(frame['response'])?.['response']);
    const models = response?.['models'];
    if (!Array.isArray(models)) return;
    const options: FocusModelOption[] = [];
    for (const entry of models) {
      const model = asRecord(entry);
      const id = asString(model?.['value']);
      if (!model || !id || !isSafeModelId(id)) continue;
      const option: FocusModelOption = { id, label: asString(model['displayName']) ?? id };
      const description = asString(model['description']);
      if (description) option.description = description;
      options.push(option);
    }
    if (options.length > 0) this.sink.models(options);
  }

  private onControlRequest(frame: Json): void {
    const requestId = asString(frame['request_id']);
    const request = asRecord(frame['request']);
    if (!requestId || !request) return;
    if (request['subtype'] !== 'can_use_tool') {
      // Unknown host callbacks must be answered or the CLI waits forever.
      this.write({
        type: 'control_response',
        response: { subtype: 'error', request_id: requestId, error: 'Unsupported control request' },
      });
      return;
    }
    const tool = asString(request['tool_name']) ?? 'tool';
    const input = request['input'];
    const sessionRules = sessionScoped(request['permission_suggestions']);
    this.approvals.set(requestId, { input, sessionRules });
    const described = describeTool(tool, input, this.options.cwd);
    this.sink.approval({
      type: 'approval.requested',
      requestId,
      itemId: asString(request['tool_use_id']),
      tool,
      kind: described.kind,
      title: described.title,
      input: clipInput(input),
      canAllowForSession: sessionRules.length > 0,
    });
  }

  private onControlCancel(frame: Json): void {
    const requestId = asString(frame['request_id']);
    if (!requestId || !this.approvals.delete(requestId)) return;
    this.sink.approvalCancelled(requestId);
  }

  private onStreamEvent(frame: Json): void {
    // Subagent streams are summarised by their tool calls, not streamed inline.
    if (frame['parent_tool_use_id']) return;
    const event = asRecord(frame['event']);
    if (!event) return;
    const key = `${asString(frame['api_message_id']) ?? ''}:${String(event['index'])}`;
    if (event['type'] === 'content_block_start') {
      const blockType = asRecord(event['content_block'])?.['type'];
      const channel = blockType === 'text' ? 'assistant' : blockType === 'thinking' ? 'reasoning' : null;
      if (!channel) return;
      const live: LiveItem = { itemId: `live_${randomUUID()}`, channel };
      this.liveByBlock.set(key, live);
      this.liveQueue.push(live);
      return;
    }
    if (event['type'] !== 'content_block_delta') return;
    const live = this.liveByBlock.get(key);
    const delta = asRecord(event['delta']);
    if (!live || !delta) return;
    const text = delta['type'] === 'text_delta' ? asString(delta['text']) : asString(delta['thinking']);
    if (text) this.sink.delta(live.itemId, live.channel, text);
  }

  /** The committed message supersedes its live block: reuse the id so the renderer swaps in place. */
  private commitLive(channel: 'assistant' | 'reasoning'): string {
    const index = this.liveQueue.findIndex((item) => item.channel === channel);
    if (index === -1) return `item_${randomUUID()}`;
    const [live] = this.liveQueue.splice(index, 1);
    for (const [key, item] of this.liveByBlock) if (item === live) this.liveByBlock.delete(key);
    return live?.itemId ?? `item_${randomUUID()}`;
  }

  private onAssistant(frame: Json): void {
    const content = asRecord(frame['message'])?.['content'];
    if (!Array.isArray(content)) return;
    const parent = asString(frame['parent_tool_use_id']);
    for (const entry of content) {
      const block = asRecord(entry);
      if (!block) continue;
      if (block['type'] === 'text') {
        const text = asString(block['text']) ?? '';
        if (parent) continue;
        const itemId = this.commitLive('assistant');
        if (text.trim()) this.sink.item({ type: 'assistant', itemId, text });
      } else if (block['type'] === 'thinking') {
        if (parent) continue;
        const itemId = this.commitLive('reasoning');
        const text = asString(block['thinking']) ?? '';
        if (text.trim()) this.sink.item({ type: 'reasoning', itemId, text });
      } else if (block['type'] === 'tool_use') {
        const name = asString(block['name']) ?? 'tool';
        const described = describeTool(name, block['input'], this.options.cwd);
        this.sink.item({
          type: 'tool.started',
          itemId: asString(block['id']) ?? `item_${randomUUID()}`,
          name,
          kind: described.kind,
          title: described.title,
          input: clipInput(block['input']),
          parentItemId: parent,
        });
      }
    }
  }

  private onUser(frame: Json): void {
    const content = asRecord(frame['message'])?.['content'];
    if (!Array.isArray(content)) return;
    for (const entry of content) {
      const block = asRecord(entry);
      if (!block || block['type'] !== 'tool_result') continue;
      const itemId = asString(block['tool_use_id']);
      if (!itemId) continue;
      const clipped = clipOutput(stringifyToolResult(block['content']));
      this.sink.item({ type: 'tool.finished', itemId, ok: block['is_error'] !== true, ...clipped });
    }
  }

  private onResult(frame: Json): void {
    this.liveQueue.length = 0;
    this.liveByBlock.clear();
    const usage = asRecord(frame['usage']);
    const failed = frame['is_error'] === true || frame['subtype'] !== 'success';
    const interrupted = failed && this.interruptRequested;
    // Cleared only here: the interrupted result can arrive after the user has already sent the next message.
    this.interruptRequested = false;
    const cost = frame['total_cost_usd'];
    const errors = Array.isArray(frame['errors']) ? frame['errors'].filter((e) => typeof e === 'string') : [];
    this.sink.turnFinished({
      outcome: interrupted ? 'interrupted' : failed ? 'failed' : 'completed',
      detail: interrupted
        ? 'Stopped by you.'
        : failed
          ? errors.join('\n') ||
            asString(frame['result']) ||
            String(frame['subtype'] ?? 'The provider reported an error.')
          : null,
      durationMs: typeof frame['duration_ms'] === 'number' ? frame['duration_ms'] : null,
      usage: usage
        ? {
            inputTokens: num(usage['input_tokens']) + num(usage['cache_creation_input_tokens']),
            cachedInputTokens: num(usage['cache_read_input_tokens']),
            outputTokens: num(usage['output_tokens']),
            costUsd: typeof cost === 'number' ? cost : null,
          }
        : null,
    });
  }
}

function num(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}
