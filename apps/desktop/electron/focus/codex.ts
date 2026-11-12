import { spawn, type ChildProcessWithoutNullStreams } from 'node:child_process';
import readline from 'node:readline';
import type { FocusApprovalDecision, FocusModelOption, FocusPermissionMode, FocusUsage } from '../../src/types/focus';
import {
  clipInput,
  clipOutput,
  isSafeModelId,
  needsShell,
  type AdapterSink,
  type AdapterStartOptions,
  type ProviderSession,
} from './adapter';

/**
 * Codex adapter (ADR-044). Drives the user's installed `codex app-server`
 * over its JSON-RPC protocol on stdio: one long-lived process per Focus
 * thread, one Codex thread inside it, turns started with `turn/start`.
 * Approvals arrive as server-initiated requests and are answered by id.
 *
 * Shapes follow the bindings `codex app-server generate-ts` emits for
 * codex-cli 0.167.2. Frames this adapter does not know are ignored; server
 * requests it cannot serve are refused so Codex never waits on us.
 */

interface Policy {
  approvalPolicy: 'untrusted' | 'on-request' | 'never';
  sandbox: 'read-only' | 'workspace-write' | 'danger-full-access';
}

/** Permission modes mapped onto Codex's two dials: when to ask, and what the sandbox allows. */
export const CODEX_POLICY: Record<FocusPermissionMode, Policy> = {
  // Measured with codex-cli 0.167.2: a read-only sandbox lets reads run freely and makes Codex ask,
  // with its reason, before anything that writes. `untrusted` asked before every `cat`.
  ask: { approvalPolicy: 'on-request', sandbox: 'read-only' },
  'accept-edits': { approvalPolicy: 'on-request', sandbox: 'workspace-write' },
  plan: { approvalPolicy: 'never', sandbox: 'read-only' },
  bypass: { approvalPolicy: 'never', sandbox: 'danger-full-access' },
};

type Json = Record<string, unknown>;

function asRecord(value: unknown): Json | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? (value as Json) : null;
}

function asString(value: unknown): string | null {
  return typeof value === 'string' ? value : null;
}

function num(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function firstLine(value: string, max = 160): string {
  const line = value.split('\n').find((part) => part.trim()) ?? '';
  return line.length > max ? `${line.slice(0, max - 1)}…` : line;
}

/**
 * Codex runs commands through the user's shell (`/usr/bin/zsh -lc "…"`). People read the command,
 * not the wrapper: prefer Codex's own parsed actions, then unwrap, then fall back to the raw string.
 */
export function displayCommand(command: unknown, actions: unknown): string {
  if (Array.isArray(actions) && actions.length > 0) {
    const parts = actions.map((action) => asString(asRecord(action)?.['command']));
    if (parts.every((part): part is string => Boolean(part))) return parts.join(' && ');
  }
  const raw = Array.isArray(command) ? command.join(' ') : (asString(command) ?? '');
  const wrapped = /^\S*(?:zsh|bash|sh)\s+-l?c\s+(['"])([\s\S]*)\1$/.exec(raw);
  if (!wrapped) return raw;
  const inner = wrapped[2] ?? raw;
  return wrapped[1] === '"' ? inner.replace(/\\(["\\$`])/g, '$1') : inner;
}

interface PendingApproval {
  rpcId: number | string;
  /** v2 requests answer `accept`/`decline`; the legacy pair answers `approved`/`denied`. */
  dialect: 'v2' | 'legacy';
}

interface FileChange {
  path: string;
  kind: string;
  diff: string;
}

function fileChanges(item: Json): FileChange[] {
  const changes = Array.isArray(item['changes']) ? item['changes'] : [];
  return changes.flatMap((entry) => {
    const change = asRecord(entry);
    const path = asString(change?.['path']);
    if (!change || !path) return [];
    const kind = asRecord(change['kind']);
    return [{ path, kind: asString(change['kind']) ?? asString(kind?.['type']) ?? 'update', diff: asString(change['diff']) ?? '' }];
  });
}

export class CodexSession implements ProviderSession {
  private readonly child: ChildProcessWithoutNullStreams;
  private readonly waiting = new Map<number, (result: Json | null, error: Json | null) => void>();
  private readonly approvals = new Map<string, PendingApproval>();
  private readonly changesByItem = new Map<string, FileChange[]>();
  private readonly outbox: string[] = [];
  private nextId = 1;
  private threadId: string | null = null;
  private turnId: string | null = null;
  private lastUsage: FocusUsage | null = null;
  private stderrTail = '';
  private disposed = false;
  private exited = false;
  private failed: string | null = null;

  constructor(
    private readonly options: AdapterStartOptions,
    private readonly sink: AdapterSink,
    /** Tests run a scripted stand-in through `node`; production passes nothing. */
    argsPrefix: readonly string[] = [],
  ) {
    this.child = spawn(options.binary, [...argsPrefix, 'app-server'], {
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
        console.error('Focus: dropped a Codex frame:', error);
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
    return !this.exited && !this.disposed;
  }

  send(text: string): void {
    // Messages sent before the thread exists wait for it; nothing is dropped.
    if (!this.threadId) {
      if (this.failed) this.reportStartFailure();
      else this.outbox.push(text);
      return;
    }
    this.startTurn(text);
  }

  respondApproval(requestId: string, decision: FocusApprovalDecision): boolean {
    const pending = this.approvals.get(requestId);
    if (!pending) return false;
    this.approvals.delete(requestId);
    const answer =
      pending.dialect === 'v2'
        ? { allow: 'accept', 'allow-session': 'acceptForSession', deny: 'decline' }[decision]
        : { allow: 'approved', 'allow-session': 'approved_for_session', deny: 'denied' }[decision];
    this.write({ id: pending.rpcId, result: { decision: answer } });
    return true;
  }

  interrupt(): void {
    if (!this.alive || !this.threadId || !this.turnId) return;
    for (const requestId of [...this.approvals.keys()]) this.respondApproval(requestId, 'deny');
    void this.request('turn/interrupt', { threadId: this.threadId, turnId: this.turnId });
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

  private request(method: string, params: Json): Promise<Json> {
    const id = this.nextId;
    this.nextId += 1;
    return new Promise((resolve, reject) => {
      this.waiting.set(id, (result, error) => {
        if (error) reject(new Error(asString(error['message']) ?? `${method} failed`));
        else resolve(result ?? {});
      });
      this.write({ id, method, params });
    });
  }

  private async handshake(): Promise<void> {
    try {
      await this.request('initialize', {
        clientInfo: { name: 'agent-toolkit-desktop', title: 'Agent Toolkit Desktop', version: '1' },
        capabilities: null,
      });
      this.write({ method: 'initialized' });
      const policy = CODEX_POLICY[this.options.permissionMode];
      const model = this.options.model && isSafeModelId(this.options.model) ? this.options.model : null;
      const common = { cwd: this.options.cwd, approvalPolicy: policy.approvalPolicy, sandbox: policy.sandbox, model };
      const started = this.options.resumeSessionId
        ? await this.request('thread/resume', { threadId: this.options.resumeSessionId, excludeTurns: true, ...common })
        : await this.request('thread/start', common);
      const threadId = asString(asRecord(started['thread'])?.['id']);
      if (!threadId) throw new Error('Codex did not return a thread.');
      this.threadId = threadId;
      this.sink.session(threadId, asString(started['model']));
      void this.loadModels();
      for (const text of this.outbox.splice(0)) this.startTurn(text);
    } catch (error) {
      this.failed = error instanceof Error ? error.message : String(error);
      if (this.outbox.length > 0) this.reportStartFailure();
    }
  }

  /** The thread could not be opened: fail the waiting turn and let the service see the exit. */
  private reportStartFailure(): void {
    this.outbox.length = 0;
    this.stderrTail = `${this.failed ?? 'Codex could not start a thread.'}\n${this.stderrTail}`.trim();
    this.kill('SIGTERM');
  }

  private async loadModels(): Promise<void> {
    try {
      const response = await this.request('model/list', {});
      const data = Array.isArray(response['data']) ? response['data'] : [];
      const models: FocusModelOption[] = [];
      for (const entry of data) {
        const model = asRecord(entry);
        const id = asString(model?.['model']) ?? asString(model?.['id']);
        if (!model || !id || model['hidden'] === true || !isSafeModelId(id)) continue;
        const option: FocusModelOption = { id, label: asString(model['displayName']) ?? id };
        const description = asString(model['description']);
        if (description) option.description = description;
        models.push(option);
      }
      if (models.length > 0) this.sink.models(models);
    } catch {
      // The model list is a convenience; the session works without it.
    }
  }

  private startTurn(text: string): void {
    if (!this.threadId) return;
    this.request('turn/start', {
      threadId: this.threadId,
      input: [{ type: 'text', text, text_elements: [] }],
    }).then(
      (result) => {
        this.turnId = asString(asRecord(result['turn'])?.['id']) ?? this.turnId;
      },
      (error: unknown) => {
        this.sink.turnFinished({
          outcome: 'failed',
          detail: error instanceof Error ? error.message : String(error),
          durationMs: null,
          usage: null,
        });
      },
    );
  }

  private onClose(code: number | null, signal: string | null): void {
    if (this.exited) return;
    this.exited = true;
    for (const settle of this.waiting.values()) settle(null, { message: 'Codex exited.' });
    this.waiting.clear();
    this.sink.exited({
      code,
      signal,
      stderr: this.stderrTail.trim(),
      expected: this.disposed,
      beforeSession: this.threadId === null,
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
    const method = asString(frame['method']);
    const id = frame['id'];
    if (!method) {
      if (typeof id === 'number') {
        const settle = this.waiting.get(id);
        this.waiting.delete(id);
        settle?.(asRecord(frame['result']), asRecord(frame['error']));
      }
      return;
    }
    const params = asRecord(frame['params']) ?? {};
    if (typeof id === 'number' || typeof id === 'string') this.onServerRequest(id, method, params);
    else this.onNotification(method, params);
  }

  private onServerRequest(rpcId: number | string, method: string, params: Json): void {
    const requestId = `codex-${String(rpcId)}`;
    const itemId = asString(params['itemId']) ?? asString(params['callId']);
    if (method === 'item/commandExecution/requestApproval' || method === 'execCommandApproval') {
      const command = displayCommand(params['command'], params['commandActions']) || 'command';
      this.approvals.set(requestId, { rpcId, dialect: method.startsWith('item/') ? 'v2' : 'legacy' });
      this.sink.approval({
        type: 'approval.requested',
        requestId,
        itemId,
        tool: 'Shell',
        kind: 'command',
        title: firstLine(command),
        input: clipInput({ command, cwd: params['cwd'], reason: params['reason'] }),
        canAllowForSession: true,
      });
      return;
    }
    if (method === 'item/fileChange/requestApproval' || method === 'applyPatchApproval') {
      const changes = (itemId ? this.changesByItem.get(itemId) : undefined) ?? [];
      this.approvals.set(requestId, { rpcId, dialect: method.startsWith('item/') ? 'v2' : 'legacy' });
      this.sink.approval({
        type: 'approval.requested',
        requestId,
        itemId,
        tool: 'Edit',
        kind: 'edit',
        title: changes.map((change) => change.path).join(', ') || 'file changes',
        input: clipInput({ changes, reason: params['reason'] }),
        canAllowForSession: true,
      });
      return;
    }
    // Anything else would need UI this app does not have yet. Refuse it so the turn can continue or fail visibly.
    this.write({ id: rpcId, error: { code: -32601, message: `${method} is not supported by this client` } });
  }

  private onNotification(method: string, params: Json): void {
    switch (method) {
      case 'item/agentMessage/delta': {
        const itemId = asString(params['itemId']);
        const delta = asString(params['delta']);
        if (itemId && delta) this.sink.delta(itemId, 'assistant', delta);
        return;
      }
      case 'item/reasoning/summaryTextDelta':
      case 'item/reasoning/textDelta': {
        const itemId = asString(params['itemId']);
        const delta = asString(params['delta']);
        if (itemId && delta) this.sink.delta(itemId, 'reasoning', delta);
        return;
      }
      case 'turn/started':
        this.turnId = asString(asRecord(params['turn'])?.['id']) ?? this.turnId;
        return;
      case 'item/started':
        this.onItemStarted(asRecord(params['item']));
        return;
      case 'item/completed':
        this.onItemCompleted(asRecord(params['item']));
        return;
      case 'thread/tokenUsage/updated': {
        const last = asRecord(asRecord(params['tokenUsage'])?.['last']);
        if (!last) return;
        const cached = num(last['cachedInputTokens']);
        this.lastUsage = {
          inputTokens: Math.max(0, num(last['inputTokens']) - cached),
          cachedInputTokens: cached,
          outputTokens: num(last['outputTokens']),
          costUsd: null,
        };
        return;
      }
      case 'serverRequest/resolved': {
        // Codex settled a request itself (for example the turn was interrupted).
        const requestId = `codex-${String(params['requestId'])}`;
        if (this.approvals.delete(requestId)) this.sink.approvalCancelled(requestId);
        return;
      }
      case 'error': {
        if (params['willRetry'] === true) return;
        const message = asString(asRecord(params['error'])?.['message']);
        if (message) this.sink.item({ type: 'notice', level: 'error', text: message });
        return;
      }
      case 'turn/completed':
        this.onTurnCompleted(asRecord(params['turn']));
        return;
      default:
        return;
    }
  }

  private onItemStarted(item: Json | null): void {
    const id = asString(item?.['id']);
    if (!item || !id) return;
    switch (item['type']) {
      case 'commandExecution': {
        const command = displayCommand(item['command'], item['commandActions']);
        this.sink.item({
          type: 'tool.started',
          itemId: id,
          name: 'Shell',
          kind: 'command',
          title: firstLine(command) || 'command',
          input: clipInput({ command, cwd: item['cwd'] }),
          parentItemId: null,
        });
        return;
      }
      case 'fileChange': {
        const changes = fileChanges(item);
        this.changesByItem.set(id, changes);
        this.sink.item({
          type: 'tool.started',
          itemId: id,
          name: 'Edit',
          kind: 'edit',
          title: changes.map((change) => change.path).join(', ') || 'file changes',
          input: clipInput({ changes }),
          parentItemId: null,
        });
        return;
      }
      case 'mcpToolCall':
        this.sink.item({
          type: 'tool.started',
          itemId: id,
          name: `${asString(item['server']) ?? 'mcp'}:${asString(item['tool']) ?? 'tool'}`,
          kind: 'other',
          title: asString(item['tool']) ?? 'tool',
          input: clipInput(item['arguments']),
          parentItemId: null,
        });
        return;
      case 'webSearch':
        this.sink.item({
          type: 'tool.started',
          itemId: id,
          name: 'WebSearch',
          kind: 'web',
          title: asString(item['query']) ?? 'web search',
          input: clipInput({ query: item['query'] }),
          parentItemId: null,
        });
        return;
      default:
        return;
    }
  }

  private onItemCompleted(item: Json | null): void {
    const id = asString(item?.['id']);
    if (!item || !id) return;
    switch (item['type']) {
      case 'agentMessage': {
        const text = asString(item['text']) ?? '';
        if (text.trim()) this.sink.item({ type: 'assistant', itemId: id, text });
        return;
      }
      case 'reasoning': {
        const parts = [item['summary'], item['content']].flatMap((value) =>
          Array.isArray(value) ? value.filter((part): part is string => typeof part === 'string') : [],
        );
        const text = parts.join('\n\n');
        if (text.trim()) this.sink.item({ type: 'reasoning', itemId: id, text });
        return;
      }
      case 'commandExecution': {
        const ok = item['status'] === 'completed' && (item['exitCode'] === 0 || item['exitCode'] === null);
        const output = asString(item['aggregatedOutput']) ?? '';
        const suffix = typeof item['exitCode'] === 'number' && item['exitCode'] !== 0 ? `\n(exit ${item['exitCode']})` : '';
        this.sink.item({ type: 'tool.finished', itemId: id, ok, ...clipOutput(`${output}${suffix}`) });
        return;
      }
      case 'fileChange': {
        const status = asString(item['status']) ?? 'completed';
        this.changesByItem.delete(id);
        this.sink.item({
          type: 'tool.finished',
          itemId: id,
          ok: status === 'completed',
          output: status === 'completed' ? 'Applied.' : `Not applied (${status}).`,
          truncated: false,
        });
        return;
      }
      case 'mcpToolCall':
      case 'webSearch': {
        const failed = item['status'] === 'failed' || Boolean(item['error']);
        const body = item['result'] ?? item['error'] ?? '';
        const text = typeof body === 'string' ? body : JSON.stringify(body, null, 2);
        this.sink.item({ type: 'tool.finished', itemId: id, ok: !failed, ...clipOutput(text ?? '') });
        return;
      }
      default:
        return;
    }
  }

  private onTurnCompleted(turn: Json | null): void {
    const status = asString(turn?.['status']);
    this.turnId = null;
    const usage = this.lastUsage;
    this.lastUsage = null;
    const error = asRecord(turn?.['error']);
    const details = [asString(error?.['message']), asString(error?.['additionalDetails'])].filter(Boolean).join('\n');
    this.sink.turnFinished({
      outcome: status === 'completed' ? 'completed' : status === 'interrupted' ? 'interrupted' : 'failed',
      detail: status === 'completed' ? null : status === 'interrupted' ? 'Stopped by you.' : details || 'Codex reported an error.',
      durationMs: typeof turn?.['durationMs'] === 'number' ? turn['durationMs'] : null,
      usage,
    });
  }
}
