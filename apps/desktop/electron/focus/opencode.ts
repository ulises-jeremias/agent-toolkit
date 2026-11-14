import { spawn, type ChildProcessWithoutNullStreams } from 'node:child_process';
import readline from 'node:readline';
import type {
  FocusApprovalDecision,
  FocusPermissionMode,
  FocusUserInputQuestion,
} from '../../src/types/focus';
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

/** OpenCode's supported ACP v1 stdio transport, one process per Focus thread. */
type Json = Record<string, unknown>;
type RpcId = number | string;

interface PendingRequest {
  resolve: (frame: Json) => void;
  timer: NodeJS.Timeout;
}

interface PendingApproval {
  rpcId: RpcId;
  allowOnce: string;
  rejectOnce: string;
  itemId: string | null;
  tool: string;
  input: unknown;
}

interface PendingInput {
  rpcId: RpcId;
  questions: Map<string, { options: Map<string, string>; custom: boolean }>;
}

interface ActiveTool {
  name: string;
  title: string;
  kind: ReturnType<typeof describeTool>['kind'];
  parentItemId: string | null;
}

const REQUEST_TIMEOUT_MS = 30_000;
const PROMPT_TIMEOUT_MS = 15 * 60_000;

function record(value: unknown): Json | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? (value as Json) : null;
}

function string(value: unknown): string | null {
  return typeof value === 'string' ? value : null;
}

function number(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function id(value: unknown): RpcId | null {
  return (typeof value === 'string' && value.length <= 128) || (typeof value === 'number' && Number.isSafeInteger(value))
    ? value
    : null;
}

function errorText(value: unknown): string {
  const message = string(record(value)?.['message']) ?? 'OpenCode returned an unspecified error.';
  return message
    .replace(/https?:\/\/[^\s)]+/gi, '[provider link omitted]')
    .replace(/\b(?:sk-[A-Za-z0-9_-]{12,}|gh[opusr]_[A-Za-z0-9_]{20,}|Bearer\s+\S+)/gi, '[credential omitted]')
    .replace(/\b(token|api[_ -]?key|secret|authorization)(\s*[:=]\s*)\S+/gi, '$1$2[credential omitted]')
    .replace(/\b(?:work|user|account|org|team)_[A-Za-z0-9_-]{12,}\b/g, '[account reference omitted]')
    .slice(0, 1_200);
}

function toolKind(value: unknown): ReturnType<typeof describeTool>['kind'] {
  switch (value) {
    case 'read':
      return 'read';
    case 'edit':
    case 'delete':
    case 'move':
      return 'edit';
    case 'search':
      return 'search';
    case 'execute':
      return 'command';
    case 'fetch':
      return 'web';
    default:
      return 'other';
  }
}

function questionsFrom(params: Json): {
  questions: FocusUserInputQuestion[];
  keys: Map<string, { options: Map<string, string>; custom: boolean }>;
} | null {
  if (params['mode'] !== 'form') return null;
  const schema = record(params['requestedSchema']);
  const properties = record(schema?.['properties']);
  if (!schema || !properties) return null;
  const questions: FocusUserInputQuestion[] = [];
  const keys = new Map<string, { options: Map<string, string>; custom: boolean }>();
  for (const [key, raw] of Object.entries(properties)) {
    if (key.endsWith('_custom')) continue;
    const property = record(raw);
    if (!property || property['type'] !== 'string') return null;
    const choices = Array.isArray(property['oneOf'])
      ? property['oneOf']
      : Array.isArray(property['enum'])
        ? (property['enum'] as unknown[]).map((entry) => ({ const: entry }))
        : [];
    const options = new Map<string, string>();
    const labels: FocusUserInputQuestion['options'] = [];
    for (const rawChoice of choices.slice(0, 20)) {
      const choice = record(rawChoice);
      const value = string(choice?.['const']);
      if (!choice || !value) return null;
      const label = string(choice['title']) ?? value;
      if (options.has(label)) return null;
      options.set(label, value);
      labels.push({ label, description: string(choice['description']) ?? '' });
    }
    const custom = Object.hasOwn(properties, `${key}_custom`);
    const question: FocusUserInputQuestion = {
      id: key,
      header: string(property['title']) ?? key,
      question: string(property['description']) ?? string(params['message']) ?? 'Choose an answer.',
      isOther: custom,
      isSecret: false,
      options: labels,
    };
    questions.push(question);
    keys.set(key, { options, custom });
  }
  return questions.length > 0 ? { questions, keys } : null;
}

function requestsSecret(params: Json): boolean {
  const schema = record(params['requestedSchema']);
  const properties = record(schema?.['properties']);
  if (!properties) return false;
  const sensitive = /\b(password|passphrase|api[_ -]?key|access[_ -]?token|refresh[_ -]?token|credential|private[_ -]?key|recovery[_ -]?code|payment[_ -]?credential)\b/i;
  return Object.entries(properties).some(([key, raw]) => {
    const property = record(raw);
    return Boolean(
      sensitive.test(`${key} ${string(property?.['title']) ?? ''} ${string(property?.['description']) ?? ''}`) ||
      property?.['format'] === 'password',
    );
  });
}

export class OpenCodeSession implements ProviderSession {
  readonly acceptsInputWhileRunning = false;
  private readonly child: ChildProcessWithoutNullStreams;
  private readonly pending = new Map<number, PendingRequest>();
  private readonly approvals = new Map<string, PendingApproval>();
  private readonly inputs = new Map<string, PendingInput>();
  private readonly tools = new Map<string, ActiveTool>();
  private readonly outbox: string[] = [];
  private nextId = 1;
  private sessionId: string | null = null;
  private ready = false;
  private promptActive = false;
  private disposed = false;
  private exited = false;
  private interruptRequested = false;
  private failed: string | null = null;
  private stderrTail = '';
  private assistantText = '';
  private reasoningText = '';
  private assistantItemId: string | null = null;
  private reasoningItemId: string | null = null;
  private killTimer: NodeJS.Timeout | null = null;

  constructor(
    private readonly options: AdapterStartOptions,
    private readonly sink: AdapterSink,
    argsPrefix: readonly string[] = [],
  ) {
    this.child = spawn(options.binary, [...argsPrefix, 'acp'], {
      cwd: options.cwd,
      env: options.env,
      stdio: ['pipe', 'pipe', 'pipe'],
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
        console.error('Focus: dropped an OpenCode ACP frame:', error);
      }
    });
    this.child.on('error', (error) => {
      this.stderrTail = `${this.stderrTail}\n${error.message}`.trim();
      this.onClose(null, null);
    });
    this.child.on('close', (code, signal) => this.onClose(code, signal));
    void this.handshake();
  }

  get alive(): boolean {
    return !this.exited && !this.disposed && this.failed === null;
  }

  send(text: string): void {
    if (!this.ready) {
      if (this.failed) this.reportTurnFailure(this.failed);
      else this.outbox.push(text);
      return;
    }
    this.startPrompt(text);
  }

  respondApproval(requestId: string, decision: FocusApprovalDecision): boolean {
    const pending = this.approvals.get(requestId);
    if (!pending || decision === 'allow-session') return false;
    const optionId = decision === 'allow' ? pending.allowOnce : pending.rejectOnce;
    if (!this.write({
      jsonrpc: '2.0',
      id: pending.rpcId,
      result: { outcome: { outcome: 'selected', optionId } },
    })) return false;
    this.approvals.delete(requestId);
    return true;
  }

  respondUserInput(requestId: string, answers: Record<string, string[]>): boolean {
    const pending = this.inputs.get(requestId);
    if (!pending || Object.keys(answers).length !== pending.questions.size) return false;
    const content: Json = {};
    for (const [key, config] of pending.questions) {
      const values = answers[key];
      if (!Array.isArray(values) || values.length === 0) return false;
      const selected = values.find((value) => !value.startsWith('user_note: '));
      const note = values.find((value) => value.startsWith('user_note: '))?.slice('user_note: '.length);
      if (config.options.size === 0) {
        const answer = values[0]?.replace(/^user_note: /, '');
        if (!answer) return false;
        content[key] = answer;
      } else if (selected && config.options.has(selected)) {
        content[key] = config.options.get(selected);
      } else if (config.custom && selected === 'None of the above') {
        content[`${key}_custom`] = note || 'Other';
      } else if (config.custom && note) {
        content[`${key}_custom`] = note;
      } else {
        return false;
      }
    }
    if (!this.write({ jsonrpc: '2.0', id: pending.rpcId, result: { action: 'accept', content } })) return false;
    this.inputs.delete(requestId);
    return true;
  }

  interrupt(): void {
    if (!this.alive || !this.sessionId || !this.promptActive) return;
    this.interruptRequested = true;
    this.cancelOutstandingInputs();
    void this.request('session/cancel', { sessionId: this.sessionId }).catch(() => undefined);
  }

  dispose(now = false): void {
    if (this.disposed) return;
    this.disposed = true;
    this.cancelOutstandingInputs();
    this.failPending('OpenCode session closed.');
    if (this.exited) return;
    if (now) {
      this.kill('SIGKILL');
      return;
    }
    this.killTimer = setTimeout(() => {
      if (!this.exited) this.kill('SIGKILL');
    }, 5_000);
    this.killTimer.unref();
    try {
      this.child.stdin.end();
    } catch {
      // Already closed.
    }
    setTimeout(() => {
      if (!this.exited) this.kill('SIGTERM');
    }, 1_500).unref();
  }

  private async handshake(): Promise<void> {
    try {
      const initialized = await this.request('initialize', {
        protocolVersion: 1,
        clientInfo: { name: 'Agent Toolkit Desktop', version: '1.49.0' },
        clientCapabilities: {
          elicitation: { form: {} },
          session: { list: true, resume: true },
        },
      });
      if (initialized.error) throw new Error(errorText(initialized.error));
      this.write({ jsonrpc: '2.0', method: 'initialized', params: {} });
      const sessionParams = { cwd: this.options.cwd, mcpServers: [] };
      const resume = this.options.resumeSessionId;
      if (resume && isSafeSessionId(resume)) {
        const loaded = await this.request('session/load', { ...sessionParams, sessionId: resume });
        if (loaded.error) throw new Error(errorText(loaded.error));
        this.sessionId = resume;
      } else {
        const created = await this.request('session/new', sessionParams);
        if (created.error) throw new Error(errorText(created.error));
        this.sessionId = string(record(created.result)?.['sessionId']);
        if (!this.sessionId || !isSafeSessionId(this.sessionId)) throw new Error('OpenCode returned an invalid session ID.');
      }
      this.sink.session(this.sessionId, this.options.model);
      if (this.options.model) {
        if (!isSafeModelId(this.options.model)) throw new Error('That OpenCode model identifier is not valid.');
        const configured = await this.request('session/set_config_option', {
          sessionId: this.sessionId,
          configId: 'model',
          value: this.options.model,
        });
        if (configured.error) throw new Error(errorText(configured.error));
      }
      this.ready = true;
      for (const message of this.outbox.splice(0)) this.startPrompt(message);
    } catch (error) {
      this.failed = error instanceof Error ? error.message : 'OpenCode could not start this session.';
      this.failPending(this.failed);
      while (this.outbox.length > 0) this.failQueuedTurn(this.failed);
      this.kill('SIGTERM');
    }
  }

  private request(method: string, params: Json, timeoutMs = REQUEST_TIMEOUT_MS): Promise<Json> {
    const requestId = this.nextId++;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(requestId);
        reject(new Error(`OpenCode ${method} request timed out.`));
      }, timeoutMs);
      this.pending.set(requestId, {
        timer,
        resolve: (frame) => {
          if (frame['error']) reject(new Error(errorText(frame['error'])));
          else resolve(frame);
        },
      });
      if (!this.write({ jsonrpc: '2.0', id: requestId, method, params })) {
        clearTimeout(timer);
        this.pending.delete(requestId);
        reject(new Error('OpenCode process is not accepting protocol messages.'));
      }
    });
  }

  private startPrompt(text: string): void {
    if (!this.alive || !this.sessionId) {
      this.reportTurnFailure(this.failed ?? 'OpenCode session is unavailable.');
      return;
    }
    if (this.promptActive) {
      this.outbox.push(text);
      return;
    }
    this.promptActive = true;
    this.assistantText = '';
    this.reasoningText = '';
    this.assistantItemId = `opencode_${this.nextId++}`;
    this.reasoningItemId = `opencode_${this.nextId++}`;
    void this.request(
      'session/prompt',
      { sessionId: this.sessionId, prompt: [{ type: 'text', text }] },
      PROMPT_TIMEOUT_MS,
    ).then((frame) => this.finishPrompt(record(frame['result']), null))
      .catch((error: unknown) => this.finishPrompt(null, error instanceof Error ? error.message : 'OpenCode turn failed.'));
  }

  private finishPrompt(result: Json | null, error: string | null): void {
    if (!this.promptActive) return;
    this.promptActive = false;
    if (this.assistantText.trim() && this.assistantItemId)
      this.sink.item({ type: 'assistant', itemId: this.assistantItemId, text: this.assistantText });
    if (this.reasoningText.trim() && this.reasoningItemId)
      this.sink.item({ type: 'reasoning', itemId: this.reasoningItemId, text: this.reasoningText });
    for (const toolId of this.tools.keys()) {
      this.sink.item({ type: 'tool.finished', itemId: toolId, ok: false, output: 'OpenCode stopped before this tool completed.', truncated: false });
      this.tools.delete(toolId);
    }
    const stopReason = string(result?.['stopReason']);
    const interrupted = this.interruptRequested || stopReason === 'cancelled';
    const usage = record(result?.['usage']);
    this.sink.turnFinished({
      outcome: interrupted ? 'interrupted' : error || (stopReason && stopReason !== 'end_turn' && stopReason !== 'refusal') ? 'failed' : 'completed',
      detail: interrupted ? 'Stopped by you.' : error ? errorText({ message: error }) : null,
      durationMs: null,
      usage: usage
        ? {
            inputTokens: number(usage['inputTokens']) ?? 0,
            cachedInputTokens: 0,
            outputTokens: number(usage['outputTokens']) ?? 0,
            costUsd: null,
          }
        : null,
    });
    this.interruptRequested = false;
    this.assistantItemId = null;
    this.reasoningItemId = null;
    const queued = this.outbox.shift();
    if (queued !== undefined) {
      if (this.alive) this.startPrompt(queued);
      else {
        this.reportTurnFailure(this.failed ?? 'OpenCode session is unavailable.');
        while (this.outbox.length > 0) this.failQueuedTurn(this.failed ?? 'OpenCode session is unavailable.');
      }
    }
  }

  private failQueuedTurn(detail: string): void {
    if (!this.outbox.length) return;
    this.outbox.shift();
    this.reportTurnFailure(detail);
  }

  private reportTurnFailure(detail: string): void {
    this.sink.turnFinished({ outcome: 'failed', detail: errorText({ message: detail }), durationMs: null, usage: null });
  }

  private onLine(line: string): void {
    let frame: Json | null;
    try {
      frame = record(JSON.parse(line));
    } catch {
      return;
    }
    if (!frame) return;
    const frameId = id(frame['id']);
    const method = string(frame['method']);
    if (method && frameId !== null) {
      this.onRequest(frameId, method, record(frame['params']) ?? {});
      return;
    }
    if (frameId !== null) {
      const pending = this.pending.get(typeof frameId === 'number' ? frameId : Number.NaN);
      if (pending) {
        this.pending.delete(typeof frameId === 'number' ? frameId : Number.NaN);
        clearTimeout(pending.timer);
        pending.resolve(frame);
      }
      return;
    }
    if (method) this.onNotification(method, record(frame['params']) ?? {});
  }

  private onRequest(rpcId: RpcId, method: string, params: Json): void {
    if (method === 'session/request_permission') {
      this.onPermission(rpcId, params);
      return;
    }
    if (method === 'elicitation/create') {
      this.onElicitation(rpcId, params);
      return;
    }
    this.write({ jsonrpc: '2.0', id: rpcId, error: { code: -32601, message: 'This OpenCode request is not supported by Focus.' } });
  }

  private onPermission(rpcId: RpcId, params: Json): void {
    const toolCall = record(params['toolCall']);
    if (
      (string(params['sessionId']) !== this.sessionId) ||
      record(record(toolCall?.['_meta'])?.['opencode/child-session'])
    ) {
      this.write({ jsonrpc: '2.0', id: rpcId, result: { outcome: { outcome: 'cancelled' } } });
      this.sink.item({ type: 'notice', level: 'warning', text: 'An OpenCode subagent requested a permission Focus could not safely attribute, so it was cancelled.' });
      return;
    }
    const options = Array.isArray(params['options']) ? params['options'].map(record).filter((entry): entry is Json => Boolean(entry)) : [];
    const allow = options.find((option) => option['kind'] === 'allow_once');
    const reject = options.find((option) => option['kind'] === 'reject_once');
    const allowOnce = string(allow?.['optionId']);
    const rejectOnce = string(reject?.['optionId']);
    const toolCallId = string(toolCall?.['toolCallId']);
    if (!toolCall || !allowOnce || !rejectOnce || !toolCallId) {
      this.write({ jsonrpc: '2.0', id: rpcId, result: { outcome: { outcome: 'cancelled' } } });
      this.sink.item({ type: 'notice', level: 'warning', text: 'OpenCode requested an approval Focus could not safely display, so it was cancelled.' });
      return;
    }
    const kind = toolKind(toolCall['kind']);
    const name = string(toolCall['name']) ?? (kind === 'command' ? 'command_execution' : 'opencode_tool');
    const input = toolCall['rawInput'] ?? toolCall['content'] ?? {};
    const described = describeTool(name, input, this.options.cwd);
    const requestId = `opencode-permission-${String(rpcId)}`;
    this.approvals.set(requestId, {
      rpcId,
      allowOnce,
      rejectOnce,
      itemId: toolCallId,
      tool: name,
      input,
    });
    this.sink.approval({
      type: 'approval.requested',
      requestId,
      itemId: toolCallId,
      tool: name,
      kind: described.kind === 'other' ? kind : described.kind,
      title: described.title === name ? string(toolCall['title']) ?? name : described.title,
      input: clipInput(input),
      canAllowForSession: false,
    });
  }

  private onElicitation(rpcId: RpcId, params: Json): void {
    if (string(params['sessionId']) !== this.sessionId) {
      this.write({ jsonrpc: '2.0', id: rpcId, result: { action: 'cancel' } });
      this.sink.item({ type: 'notice', level: 'warning', text: 'An OpenCode subagent asked a question Focus could not safely attribute, so it was cancelled.' });
      return;
    }
    if (requestsSecret(params)) {
      this.write({ jsonrpc: '2.0', id: rpcId, result: { action: 'cancel' } });
      this.sink.item({ type: 'notice', level: 'warning', text: 'OpenCode requested sensitive information through a form, so Focus cancelled the request.' });
      return;
    }
    const parsed = questionsFrom(params);
    const requestId = `opencode-question-${String(rpcId)}`;
    if (!parsed) {
      this.write({ jsonrpc: '2.0', id: rpcId, result: { action: 'cancel' } });
      this.sink.item({ type: 'notice', level: 'warning', text: 'OpenCode asked a question Focus could not safely present, so it was cancelled.' });
      return;
    }
    this.inputs.set(requestId, { rpcId, questions: parsed.keys });
    this.sink.userInput(requestId, parsed.questions);
  }

  private onNotification(method: string, params: Json): void {
    if (method !== 'session/update' || params['sessionId'] !== this.sessionId) return;
    const update = record(params['update']);
    if (!update) return;
    if (!this.promptActive) return;
    const meta = record(update['_meta']);
    if (record(meta?.['opencode/child-session'])) return;
    const kind = string(update['sessionUpdate']);
    if (kind === 'agent_message_chunk' || kind === 'agent_thought_chunk') {
      const content = record(update['content']);
      const delta = string(content?.['text']);
      if (!delta || !this.promptActive) return;
      const reasoning = kind === 'agent_thought_chunk';
      const itemId = reasoning ? this.reasoningItemId : this.assistantItemId;
      if (!itemId) return;
      if (reasoning) this.reasoningText += delta;
      else this.assistantText += delta;
      this.sink.delta(itemId, reasoning ? 'reasoning' : 'assistant', delta);
      return;
    }
    if (kind === 'tool_call') {
      this.startTool(update);
      return;
    }
    if (kind === 'tool_call_update') this.updateTool(update);
  }

  private startTool(update: Json): void {
    const toolId = string(update['toolCallId']);
    if (!toolId || this.tools.has(toolId)) return;
    const kind = toolKind(update['kind']);
    const name = string(update['name']) ?? (kind === 'command' ? 'command_execution' : 'opencode_tool');
    const input = update['rawInput'] ?? {};
    const described = describeTool(name, input, this.options.cwd);
    const title = described.title === name ? string(update['title']) ?? name : described.title;
    const tool: ActiveTool = { name, title, kind: described.kind === 'other' ? kind : described.kind, parentItemId: null };
    this.tools.set(toolId, tool);
    this.sink.item({ type: 'tool.started', itemId: toolId, name, kind: tool.kind, title, input: clipInput(input), parentItemId: null });
  }

  private updateTool(update: Json): void {
    const toolId = string(update['toolCallId']);
    const tool = toolId ? this.tools.get(toolId) : undefined;
    if (!toolId || !tool) return;
    const status = string(update['status']);
    if (status !== 'completed' && status !== 'failed') return;
    const content = update['content'] ?? update['rawOutput'] ?? '';
    const clipped = clipOutput(stringifyToolResult(content));
    this.sink.item({ type: 'tool.finished', itemId: toolId, ok: status === 'completed', ...clipped });
    this.tools.delete(toolId);
  }

  private cancelOutstandingInputs(): void {
    for (const [requestId, pending] of this.approvals) {
      this.write({ jsonrpc: '2.0', id: pending.rpcId, result: { outcome: { outcome: 'cancelled' } } });
      this.approvals.delete(requestId);
      this.sink.approvalCancelled(requestId);
    }
    for (const [requestId, pending] of this.inputs) {
      this.write({ jsonrpc: '2.0', id: pending.rpcId, result: { action: 'cancel' } });
      this.inputs.delete(requestId);
      this.sink.userInputCancelled(requestId, this.interruptRequested ? 'interrupt' : 'shutdown');
    }
  }

  private failPending(message: string): void {
    for (const [requestId, pending] of this.pending) {
      clearTimeout(pending.timer);
      this.pending.delete(requestId);
      pending.resolve({ error: { message } });
    }
    if (this.promptActive) this.finishPrompt(null, message);
  }

  private write(frame: Json): boolean {
    if (this.exited || this.child.stdin.destroyed || this.child.stdin.writableEnded) return false;
    try {
      this.child.stdin.write(`${JSON.stringify(frame)}\n`);
      return true;
    } catch {
      return false;
    }
  }

  private kill(signal: NodeJS.Signals): void {
    try {
      if (this.child.pid !== undefined && process.platform !== 'win32') process.kill(-this.child.pid, signal);
      else this.child.kill(signal);
    } catch {
      // Already gone.
    }
  }

  private onClose(code: number | null, signal: string | null): void {
    if (this.exited) return;
    this.exited = true;
    if (this.killTimer) clearTimeout(this.killTimer);
    this.failPending(this.failed ?? 'OpenCode closed the ACP connection.');
    this.sink.exited({
      code,
      signal,
      stderr: errorText({ message: this.stderrTail.trim() }),
      expected: this.disposed,
      beforeSession: this.sessionId === null,
    });
  }
}

export function openCodePermissionModeSupported(mode: FocusPermissionMode): boolean {
  return mode === 'ask';
}
