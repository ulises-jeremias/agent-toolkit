import fs from 'node:fs';
import type {
  FocusApprovalDecision,
  FocusCreateThreadInput,
  FocusEvent,
  FocusEventBody,
  FocusLiveUpdate,
  FocusModelOption,
  FocusPermissionMode,
  FocusProviderId,
  FocusProviderStatus,
  FocusResult,
  FocusThread,
  FocusThreadPatch,
  FocusThreadSnapshot,
} from '../../src/types/focus';
import type { AdapterSink, ProviderSession, ProviderSessionFactory } from './adapter';
import { ClaudeSession } from './claude';
import { isThreadId, newThreadId, ThreadJournal } from './journal';
import { probeProviders, type ProbeOptions } from './providers';

/**
 * Focus session service (ADR-044). Owns provider processes, the per-thread
 * journal and the status machine. The renderer is a projection: it receives
 * journaled events plus live-only text deltas and never decides what
 * happened.
 */

const PROVIDERS: readonly FocusProviderId[] = ['claude', 'codex', 'opencode'];
const MODES: readonly FocusPermissionMode[] = ['ask', 'accept-edits', 'plan', 'bypass'];
const PROBE_TTL_MS = 60_000;
const INTERRUPT_GRACE_MS = 8_000;

export interface FocusServiceOptions {
  getWorkspace: () => string | null;
  emit: (update: FocusLiveUpdate) => void;
  env?: () => NodeJS.ProcessEnv;
  factories?: Partial<Record<FocusProviderId, ProviderSessionFactory>>;
  probe?: (options: ProbeOptions) => Promise<FocusProviderStatus[]>;
  /** Keep an idle provider process this long for fast follow-ups, then release it. */
  idleMs?: number;
}

interface Runtime {
  journal: ThreadJournal;
  session: ProviderSession | null;
  turn: number;
  turnOpen: boolean;
  pendingApprovals: Set<string>;
  idleTimer: NodeJS.Timeout | null;
  interruptTimer: NodeJS.Timeout | null;
  interrupting: boolean;
}

const DEFAULT_FACTORIES: Partial<Record<FocusProviderId, ProviderSessionFactory>> = {
  claude: (options, sink) => new ClaudeSession(options, sink),
};

function ok<T>(value: T): FocusResult<T> {
  return { ok: true, value };
}

function fail<T>(error: string): FocusResult<T> {
  return { ok: false, error };
}

function titleFrom(text: string): string {
  const line =
    text
      .split('\n')
      .find((part) => part.trim())
      ?.trim() ?? 'New session';
  return line.length > 64 ? `${line.slice(0, 63)}…` : line;
}

export class FocusService {
  private readonly runtimes = new Map<string, Runtime>();
  private readonly reconciled = new Set<string>();
  private readonly factories: Partial<Record<FocusProviderId, ProviderSessionFactory>>;
  private readonly modelCache = new Map<FocusProviderId, FocusModelOption[]>();
  private probeCache: { at: number; value: Promise<FocusProviderStatus[]> } | null = null;
  private closed = false;

  constructor(private readonly options: FocusServiceOptions) {
    this.factories = options.factories ?? DEFAULT_FACTORIES;
  }

  providers(refresh = false): Promise<FocusProviderStatus[]> {
    const now = Date.now();
    if (refresh || !this.probeCache || now - this.probeCache.at > PROBE_TTL_MS) {
      const probe = this.options.probe ?? probeProviders;
      const supported = new Set(PROVIDERS.filter((id) => this.factories[id]));
      this.probeCache = { at: now, value: probe({ env: this.env(), supported }) };
    }
    return this.probeCache.value.then((list) =>
      list.map((status) => {
        const models = this.modelCache.get(status.id);
        return models ? { ...status, models } : status;
      }),
    );
  }

  listThreads(): FocusThread[] {
    const workspace = this.options.getWorkspace();
    if (!workspace) return [];
    this.reconcile(workspace);
    return ThreadJournal.list(workspace)
      .map((journal) => this.runtimes.get(journal.thread.id)?.journal.thread ?? journal.thread)
      .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
  }

  createThread(input: FocusCreateThreadInput): FocusResult<FocusThread> {
    const workspace = this.options.getWorkspace();
    if (!workspace) return fail('No workspace is open.');
    if (!PROVIDERS.includes(input.provider)) return fail('Unknown provider.');
    if (!MODES.includes(input.permissionMode)) return fail('Unknown permission mode.');
    if (!this.factories[input.provider]) return fail('Focus sessions are not available for this provider yet.');
    if (typeof input.cwd !== 'string' || !isDirectory(input.cwd)) return fail('The project folder does not exist.');
    const now = new Date().toISOString();
    const thread: FocusThread = {
      id: newThreadId(),
      title: (input.title ?? '').trim().slice(0, 120),
      workspace,
      projectName: input.projectName ? input.projectName.slice(0, 120) : null,
      cwd: input.cwd,
      provider: input.provider,
      model: input.model ? input.model.slice(0, 120) : null,
      resolvedModel: null,
      permissionMode: input.permissionMode,
      providerSessionId: null,
      status: 'idle',
      createdAt: now,
      updatedAt: now,
      turns: 0,
      lastError: null,
      usage: { inputTokens: 0, cachedInputTokens: 0, outputTokens: 0, costUsd: null },
    };
    const journal = ThreadJournal.create(workspace, thread);
    this.options.emit({ kind: 'thread', thread: journal.thread });
    return ok(journal.thread);
  }

  readThread(id: string): FocusThreadSnapshot | null {
    const journal = this.journalFor(id);
    return journal ? { thread: journal.thread, events: journal.readEvents() } : null;
  }

  updateThread(id: string, patch: FocusThreadPatch): FocusResult<FocusThread> {
    const journal = this.journalFor(id);
    if (!journal) return fail('Session not found.');
    const runtime = this.runtimes.get(id);
    const next: Partial<FocusThread> = {};
    if (typeof patch.title === 'string') next.title = patch.title.trim().slice(0, 120);
    const relaunch =
      (patch.model !== undefined && patch.model !== journal.thread.model) ||
      (patch.permissionMode !== undefined && patch.permissionMode !== journal.thread.permissionMode);
    if (relaunch) {
      if (runtime?.turnOpen) return fail('Stop the running turn before changing the model or permissions.');
      if (patch.permissionMode !== undefined) {
        if (!MODES.includes(patch.permissionMode)) return fail('Unknown permission mode.');
        next.permissionMode = patch.permissionMode;
      }
      if (patch.model !== undefined) next.model = patch.model ? patch.model.slice(0, 120) : null;
      // The next message relaunches the provider with the new settings and resumes the same conversation.
      this.releaseSession(runtime);
    }
    return ok(this.setThread(journal, next));
  }

  deleteThread(id: string): FocusResult<true> {
    const journal = this.journalFor(id);
    if (!journal) return fail('Session not found.');
    const runtime = this.runtimes.get(id);
    if (runtime?.turnOpen) return fail('Stop the running turn before deleting this session.');
    this.releaseSession(runtime);
    this.runtimes.delete(id);
    journal.remove();
    this.options.emit({ kind: 'removed', threadId: id });
    return ok(true);
  }

  async send(id: string, text: string): Promise<FocusResult<true>> {
    if (this.closed) return fail('Agent Toolkit is shutting down.');
    const message = typeof text === 'string' ? text.trim() : '';
    if (!message) return fail('Write a message first.');
    const journal = this.journalFor(id);
    if (!journal) return fail('Session not found.');
    const runtime = this.runtimeFor(journal);
    if (runtime.pendingApprovals.size > 0) return fail('Answer the pending approval first.');
    if (!runtime.session?.alive) {
      const started = await this.startSession(runtime);
      if (!started.ok) return started;
    }
    this.clearIdle(runtime);
    this.record(runtime, { type: 'user', text: message }, { openTurn: 'user' });
    if (!journal.thread.title) this.setThread(journal, { title: titleFrom(message) });
    runtime.session?.send(message);
    return ok(true);
  }

  respondApproval(id: string, requestId: string, decision: FocusApprovalDecision): FocusResult<true> {
    const runtime = this.runtimes.get(id);
    if (!runtime?.session || !runtime.pendingApprovals.has(requestId))
      return fail('This approval is no longer pending.');
    if (!runtime.session.respondApproval(requestId, decision)) return fail('This approval is no longer pending.');
    this.resolveApproval(runtime, requestId, decision, 'user');
    return ok(true);
  }

  interrupt(id: string): FocusResult<true> {
    const runtime = this.runtimes.get(id);
    if (!runtime?.turnOpen || !runtime.session) return fail('Nothing is running in this session.');
    if (runtime.interrupting) return ok(true);
    runtime.interrupting = true;
    for (const requestId of [...runtime.pendingApprovals])
      this.resolveApproval(runtime, requestId, 'deny', 'interrupt');
    runtime.session.interrupt();
    // A provider that ignores the interrupt is stopped; the turn is then closed as interrupted on exit.
    runtime.interruptTimer = setTimeout(() => runtime.session?.dispose(), INTERRUPT_GRACE_MS);
    runtime.interruptTimer.unref();
    return ok(true);
  }

  /** Close every live turn honestly and stop provider processes. Synchronous journal writes. */
  shutdown(): void {
    this.closed = true;
    for (const runtime of this.runtimes.values()) {
      this.clearIdle(runtime);
      if (runtime.turnOpen)
        this.closeTurn(runtime, 'interrupted', 'Agent Toolkit was closed while this turn was running.', 'shutdown');
      runtime.session?.dispose();
      runtime.session = null;
    }
    this.runtimes.clear();
  }

  private env(): NodeJS.ProcessEnv {
    return this.options.env?.() ?? process.env;
  }

  private journalFor(id: unknown): ThreadJournal | null {
    if (!isThreadId(id)) return null;
    const live = this.runtimes.get(id);
    if (live) return live.journal;
    const workspace = this.options.getWorkspace();
    if (!workspace) return null;
    this.reconcile(workspace);
    return ThreadJournal.open(workspace, id);
  }

  private runtimeFor(journal: ThreadJournal): Runtime {
    const existing = this.runtimes.get(journal.thread.id);
    if (existing) return existing;
    const runtime: Runtime = {
      journal,
      session: null,
      turn: journal.thread.turns,
      turnOpen: false,
      pendingApprovals: new Set(),
      idleTimer: null,
      interruptTimer: null,
      interrupting: false,
    };
    this.runtimes.set(journal.thread.id, runtime);
    return runtime;
  }

  /**
   * A thread journaled as running with no live process was cut off by an app
   * exit or crash. Say so in the history instead of showing a spinner forever.
   */
  private reconcile(workspace: string): void {
    if (this.reconciled.has(workspace)) return;
    this.reconciled.add(workspace);
    for (const journal of ThreadJournal.list(workspace)) {
      const { status, id, turns } = journal.thread;
      if ((status !== 'running' && status !== 'awaiting-approval') || this.runtimes.has(id)) continue;
      const events = journal.readEvents();
      const open = new Set<string>();
      for (const event of events) {
        if (event.type === 'approval.requested') open.add(event.requestId);
        if (event.type === 'approval.resolved') open.delete(event.requestId);
      }
      for (const requestId of open) {
        journal.append(turns, { type: 'approval.resolved', requestId, decision: 'deny', by: 'shutdown' });
      }
      journal.append(turns, {
        type: 'turn.finished',
        outcome: 'interrupted',
        detail: 'Agent Toolkit closed while this turn was running.',
        durationMs: null,
        usage: null,
      });
      journal.update({ status: 'interrupted' });
    }
  }

  private async startSession(runtime: Runtime): Promise<FocusResult<true>> {
    const thread = runtime.journal.thread;
    const factory = this.factories[thread.provider];
    if (!factory) return fail('Focus sessions are not available for this provider yet.');
    if (!isDirectory(thread.cwd)) return fail(`The project folder no longer exists: ${thread.cwd}`);
    const status = (await this.providers()).find((provider) => provider.id === thread.provider);
    if (!status?.installed || !status.binary) return fail(`${status?.label ?? thread.provider} is not installed.`);
    if (status.auth === 'signed-out') {
      return fail(
        `${status.label} is not signed in. Run \`${status.signInHint ?? 'the provider login'}\` in a terminal.`,
      );
    }
    let session: ProviderSession | null = null;
    session = factory(
      {
        binary: status.binary,
        cwd: thread.cwd,
        model: thread.model,
        permissionMode: thread.permissionMode,
        resumeSessionId: thread.providerSessionId,
        env: this.env(),
      },
      // Frames from a released process must never touch the session that replaced it.
      this.sinkFor(runtime, () => session !== null && runtime.session === session),
    );
    runtime.session = session;
    return ok(true);
  }

  private sinkFor(runtime: Runtime, isCurrent: () => boolean): AdapterSink {
    const threadId = runtime.journal.thread.id;
    return {
      session: (providerSessionId, model) => {
        if (!isCurrent()) return;
        this.setThread(runtime.journal, { providerSessionId, resolvedModel: model });
      },
      models: (models) => {
        this.modelCache.set(runtime.journal.thread.provider, models);
      },
      delta: (itemId, channel, text) => {
        if (!isCurrent()) return;
        this.ensureTurn(runtime);
        this.options.emit({ kind: 'delta', threadId, itemId, channel, text });
      },
      item: (body) => {
        if (!isCurrent()) return;
        this.record(runtime, body, { openTurn: 'provider' });
      },
      approval: (request) => {
        if (!isCurrent()) return;
        this.record(runtime, request, { openTurn: 'provider' });
        runtime.pendingApprovals.add(request.requestId);
        this.setThread(runtime.journal, { status: 'awaiting-approval' });
      },
      turnFinished: (result) => {
        if (!isCurrent() || !runtime.turnOpen) return;
        const previous = runtime.journal.thread.usage;
        const usage = result.usage
          ? {
              inputTokens: previous.inputTokens + result.usage.inputTokens,
              cachedInputTokens: previous.cachedInputTokens + result.usage.cachedInputTokens,
              outputTokens: previous.outputTokens + result.usage.outputTokens,
              // Providers report a running session total, not a per-turn price.
              costUsd: result.usage.costUsd ?? previous.costUsd,
            }
          : previous;
        this.closeTurn(runtime, result.outcome, result.detail, 'interrupt', result.durationMs, result.usage, usage);
        this.scheduleIdle(runtime);
      },
      exited: (info) => {
        if (!isCurrent()) return;
        runtime.session = null;
        if (!runtime.turnOpen) return;
        if (runtime.interrupting || info.expected) {
          this.closeTurn(runtime, 'interrupted', 'Stopped by you.', 'interrupt');
          return;
        }
        const reason =
          info.stderr || `The provider process exited unexpectedly (${info.signal ?? `code ${String(info.code)}`}).`;
        this.closeTurn(runtime, 'failed', reason, 'interrupt');
      },
    };
  }

  private ensureTurn(runtime: Runtime): void {
    if (runtime.turnOpen) return;
    runtime.turn += 1;
    runtime.turnOpen = true;
    runtime.interrupting = false;
    this.setThread(runtime.journal, { turns: runtime.turn, status: 'running', lastError: null });
  }

  /** Journal one event and push it live. Opens a turn first when none is open. */
  private record(runtime: Runtime, body: FocusEventBody, options: { openTurn: 'user' | 'provider' }): FocusEvent {
    const opening = !runtime.turnOpen;
    this.ensureTurn(runtime);
    const emit = (eventBody: FocusEventBody): FocusEvent => {
      const event = runtime.journal.append(runtime.turn, eventBody);
      this.options.emit({ kind: 'event', threadId: runtime.journal.thread.id, event });
      return event;
    };
    const started: FocusEventBody = { type: 'turn.started', model: runtime.journal.thread.model };
    // A user-opened turn reads "message, then work"; provider-opened turns (queued input) start with the marker.
    if (opening && options.openTurn === 'provider') emit(started);
    const event = emit(body);
    if (opening && options.openTurn === 'user') emit(started);
    return event;
  }

  private resolveApproval(
    runtime: Runtime,
    requestId: string,
    decision: FocusApprovalDecision,
    by: 'user' | 'interrupt' | 'shutdown',
  ): void {
    if (!runtime.pendingApprovals.delete(requestId)) return;
    const event = runtime.journal.append(runtime.turn, { type: 'approval.resolved', requestId, decision, by });
    this.options.emit({ kind: 'event', threadId: runtime.journal.thread.id, event });
    if (runtime.turnOpen && runtime.pendingApprovals.size === 0) this.setThread(runtime.journal, { status: 'running' });
  }

  private closeTurn(
    runtime: Runtime,
    outcome: 'completed' | 'interrupted' | 'failed',
    detail: string | null,
    approvalsBy: 'interrupt' | 'shutdown',
    durationMs: number | null = null,
    turnUsage: FocusThread['usage'] | null = null,
    threadUsage: FocusThread['usage'] = runtime.journal.thread.usage,
  ): void {
    if (runtime.interruptTimer) clearTimeout(runtime.interruptTimer);
    runtime.interruptTimer = null;
    for (const requestId of [...runtime.pendingApprovals])
      this.resolveApproval(runtime, requestId, 'deny', approvalsBy);
    const event = runtime.journal.append(runtime.turn, {
      type: 'turn.finished',
      outcome,
      detail,
      durationMs,
      usage: turnUsage,
    });
    runtime.turnOpen = false;
    runtime.interrupting = false;
    this.options.emit({ kind: 'event', threadId: runtime.journal.thread.id, event });
    this.setThread(runtime.journal, {
      status: outcome === 'completed' ? 'idle' : outcome === 'interrupted' ? 'interrupted' : 'error',
      lastError: outcome === 'failed' ? detail : null,
      usage: threadUsage,
    });
  }

  private setThread(journal: ThreadJournal, patch: Partial<FocusThread>): FocusThread {
    const thread = journal.update(patch);
    this.options.emit({ kind: 'thread', thread });
    return thread;
  }

  private scheduleIdle(runtime: Runtime): void {
    this.clearIdle(runtime);
    runtime.idleTimer = setTimeout(() => this.releaseSession(runtime), this.options.idleMs ?? 5 * 60_000);
    runtime.idleTimer.unref();
  }

  private clearIdle(runtime: Runtime): void {
    if (runtime.idleTimer) clearTimeout(runtime.idleTimer);
    runtime.idleTimer = null;
  }

  private releaseSession(runtime: Runtime | undefined): void {
    if (!runtime) return;
    this.clearIdle(runtime);
    runtime.session?.dispose();
    runtime.session = null;
  }
}

function isDirectory(dir: string): boolean {
  try {
    return fs.statSync(dir).isDirectory();
  } catch {
    return false;
  }
}
