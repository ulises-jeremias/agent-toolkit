// @vitest-environment node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { FocusEvent, FocusLiveUpdate, FocusProviderStatus } from '../../src/types/focus';
import { clipOutput, describeTool } from './adapter.js';
import { ClaudeSession, claudeArgs } from './claude.js';
import { focusRoot, isThreadId, newThreadId, ThreadJournal } from './journal.js';
import { probeProviders } from './providers.js';
import { FocusService } from './service.js';

const FAKE = path.join(__dirname, 'testing', 'fake-claude.mjs');

function tempWorkspace(): string {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'atk-focus-'));
}

const READY: FocusProviderStatus = {
  id: 'claude',
  label: 'Claude Code',
  installed: true,
  binary: process.execPath,
  version: '0.0.0',
  auth: 'ready',
  authDetail: 'Signed in',
  signInHint: null,
  models: [],
  capabilities: { sessions: true, approvals: true, interrupt: true, resume: true, modelSwitch: true },
  checkedAt: new Date(0).toISOString(),
};

interface Harness {
  service: FocusService;
  updates: FocusLiveUpdate[];
  workspace: string;
  argvLog: string;
  events: (id: string) => FocusEvent[];
  waitFor: (predicate: () => boolean, label: string) => Promise<void>;
}

const services: FocusService[] = [];

function harness(
  workspace = tempWorkspace(),
  env: NodeJS.ProcessEnv = {},
  provider: FocusProviderStatus = READY,
  timing: { idleMs?: number; interruptGraceMs?: number; journalRoot?: string } = {},
): Harness {
  const updates: FocusLiveUpdate[] = [];
  const argvLog = path.join(workspace, 'argv.log');
  const service = new FocusService({
    getWorkspace: () => workspace,
    emit: (update) => updates.push(update),
    env: () => ({ ...process.env, FAKE_CLAUDE_LOG: argvLog, ...env }),
    probe: async () => [provider],
    ...timing,
    factories: { claude: (options, sink) => new ClaudeSession(options, sink, [FAKE]) },
  });
  services.push(service);
  return {
    service,
    updates,
    workspace,
    argvLog,
    events: (id) => service.readThread(id)?.events ?? [],
    waitFor: async (predicate, label) => {
      const deadline = Date.now() + 10_000;
      while (!predicate()) {
        if (Date.now() > deadline) throw new Error(`timed out waiting for ${label}`);
        await new Promise((resolve) => setTimeout(resolve, 10));
      }
    },
  };
}

function start(h: Harness, overrides: { model?: string | null } = {}): string {
  const created = h.service.createThread({
    cwd: h.workspace,
    projectName: 'demo',
    provider: 'claude',
    model: overrides.model ?? null,
    permissionMode: 'ask',
  });
  if (!created.ok) throw new Error(created.error);
  return created.value.id;
}

const types = (events: FocusEvent[]): string[] => events.map((event) => event.type);
const status = (h: Harness, id: string): string | undefined => h.service.readThread(id)?.thread.status;

afterEach(() => {
  for (const service of services.splice(0)) service.shutdown();
});

describe('thread journal', () => {
  it('validates ids so a thread id can never become a path', () => {
    expect(isThreadId(newThreadId())).toBe(true);
    expect(isThreadId('../../etc')).toBe(false);
    expect(isThreadId('th_UPPER')).toBe(false);
    expect(ThreadJournal.open(tempWorkspace(), '../x')).toBeNull();
  });

  it('skips a torn final line instead of losing the history', () => {
    const h = harness();
    const id = start(h);
    const journal = ThreadJournal.open(h.workspace, id);
    journal?.append(1, { type: 'user', text: 'hello' });
    fs.appendFileSync(path.join(h.workspace, '.agent-toolkit', 'focus', 'threads', id, 'events.jsonl'), '{"seq":2,"ty');
    const reopened = ThreadJournal.open(h.workspace, id);
    expect(reopened?.readEvents()).toHaveLength(1);
    expect(reopened?.append(1, { type: 'user', text: 'again' }).seq).toBe(2);
    // The new event must survive on its own line, not be glued to the torn fragment.
    expect(
      ThreadJournal.open(h.workspace, id)
        ?.readEvents()
        .map((event) => event.seq),
    ).toEqual([1, 2]);
  });

  it('rejects symlinked journal files without modifying external sentinels', () => {
    const h = harness();
    const id = start(h);
    const dir = path.join(h.workspace, '.agent-toolkit', 'focus', 'threads', id);
    const sentinel = path.join(h.workspace, 'sentinel.txt');
    fs.writeFileSync(sentinel, 'do not touch');
    const events = path.join(dir, 'events.jsonl');
    fs.symlinkSync(sentinel, events);
    const journal = ThreadJournal.open(h.workspace, id);
    // Tampering must not be represented as an empty (successfully read) history.
    expect(() => journal?.readEvents()).toThrow(/Symlink/);
    expect(() => journal?.append(1, { type: 'user', text: 'blocked' })).toThrow(/Symlink/);
    expect(fs.readFileSync(sentinel, 'utf8')).toBe('do not touch');
    fs.unlinkSync(events);

    const meta = path.join(dir, 'thread.json');
    fs.unlinkSync(meta);
    fs.symlinkSync(sentinel, meta);
    expect(ThreadJournal.open(h.workspace, id)).toBeNull();
    expect(() => journal?.update({ title: 'blocked' })).toThrow(/Symlink/);
    expect(fs.readFileSync(sentinel, 'utf8')).toBe('do not touch');
  });

  it('moves history into private app storage once and leaves workspace data intact', () => {
    const h = harness();
    const id = start(h);
    const legacy = ThreadJournal.open(h.workspace, id);
    if (!legacy) throw new Error('Expected the newly created legacy thread');
    legacy.append(1, { type: 'user', text: 'preserve this history' });
    const originalEventsInModel = legacy.readEvents();
    const legacyRoot = focusRoot(h.workspace);
    const legacyEvents = path.join(legacyRoot, id, 'events.jsonl');
    const originalEvents = fs.readFileSync(legacyEvents);
    const legacyMeta = path.join(legacyRoot, id, 'thread.json');
    const originalMeta = fs.readFileSync(legacyMeta);
    const appData = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-focus-app-data-'));
    const storageRoot = path.join(appData, 'focus-journals');

    try {
      const migrated = ThreadJournal.list(h.workspace, storageRoot);
      expect(migrated.map((journal) => journal.thread.id)).toEqual([id]);
      expect(migrated[0]?.readEvents()).toEqual(legacy.readEvents());
      expect(fs.readFileSync(legacyEvents)).toEqual(originalEvents);
      expect(fs.readFileSync(path.join(focusRoot(h.workspace, storageRoot), id, 'events.jsonl'))).toEqual(
        originalEvents,
      );
      expect(fs.readFileSync(path.join(focusRoot(h.workspace, storageRoot), id, 'thread.json'))).toEqual(originalMeta);
      expect(fs.existsSync(path.join(path.dirname(focusRoot(h.workspace, storageRoot)), 'migration-v1.json'))).toBe(
        true,
      );
      if (process.platform !== 'win32') {
        expect(fs.statSync(storageRoot).mode & 0o777).toBe(0o700);
        expect(fs.statSync(focusRoot(h.workspace, storageRoot)).mode & 0o777).toBe(0o700);
        expect(fs.statSync(path.join(focusRoot(h.workspace, storageRoot), id)).mode & 0o777).toBe(0o700);
      }

      const sentinel = path.join(appData, 'sentinel.txt');
      fs.writeFileSync(sentinel, 'preserved');
      fs.unlinkSync(legacyEvents);
      fs.symlinkSync(sentinel, legacyEvents);
      expect(ThreadJournal.list(h.workspace, storageRoot)[0]?.readEvents()).toEqual(originalEventsInModel);
      expect(fs.readFileSync(sentinel, 'utf8')).toBe('preserved');
    } finally {
      fs.rmSync(appData, { recursive: true, force: true });
    }
  });

  it('creates and reopens new service threads under the app-owned journal root', () => {
    const workspace = tempWorkspace();
    const appData = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-focus-service-data-'));
    const storageRoot = path.join(appData, 'focus-journals');
    const h = harness(workspace, {}, READY, { journalRoot: storageRoot });

    try {
      const id = start(h);
      expect(path.relative(workspace, focusRoot(workspace, storageRoot))).toMatch(/^\.\./);
      expect(fs.existsSync(path.join(workspace, '.agent-toolkit', 'focus', 'threads', id))).toBe(false);
      expect(h.service.listThreads().map((thread) => thread.id)).toEqual([id]);
      expect(h.service.readThread(id)?.thread.id).toBe(id);
    } finally {
      fs.rmSync(appData, { recursive: true, force: true });
    }
  });

  it('refuses to migrate a symlinked legacy event log and preserves its target', () => {
    const h = harness();
    const id = start(h);
    const legacyRoot = focusRoot(h.workspace);
    const legacyEvents = path.join(legacyRoot, id, 'events.jsonl');
    const external = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-focus-migration-'));
    const sentinel = path.join(external, 'sentinel.txt');
    const storageRoot = path.join(external, 'focus-journals');
    fs.writeFileSync(sentinel, 'do not touch');
    ThreadJournal.open(h.workspace, id)?.append(1, { type: 'user', text: 'legacy event' });
    fs.unlinkSync(legacyEvents);
    fs.symlinkSync(sentinel, legacyEvents);

    try {
      expect(() => ThreadJournal.list(h.workspace, storageRoot)).toThrow(/Symlink/);
      expect(fs.readFileSync(sentinel, 'utf8')).toBe('do not touch');
      expect(fs.existsSync(path.join(path.dirname(focusRoot(h.workspace, storageRoot)), 'migration-v1.json'))).toBe(
        false,
      );
    } finally {
      fs.rmSync(external, { recursive: true, force: true });
    }
  });

  it('fails closed on an oversized legacy journal without reading or marking it migrated', () => {
    const h = harness();
    const id = start(h);
    const legacyEvents = path.join(focusRoot(h.workspace), id, 'events.jsonl');
    const external = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-focus-large-migration-'));
    const storageRoot = path.join(external, 'focus-journals');
    const limit = 64 * 1024 * 1024;
    ThreadJournal.open(h.workspace, id)?.append(1, { type: 'user', text: 'legacy event' });
    fs.truncateSync(legacyEvents, limit + 1);

    try {
      expect(() => ThreadJournal.list(h.workspace, storageRoot)).toThrow(/exceeds the 64 MiB migration limit/);
      expect(fs.statSync(legacyEvents).size).toBe(limit + 1);
      expect(fs.existsSync(path.join(path.dirname(focusRoot(h.workspace, storageRoot)), 'migration-v1.json'))).toBe(
        false,
      );
      expect(fs.existsSync(path.join(focusRoot(h.workspace, storageRoot), id))).toBe(false);
    } finally {
      fs.rmSync(external, { recursive: true, force: true });
    }
  });

  it('rejects a legacy ancestor swapped to a symlink during metadata open', () => {
    const h = harness();
    const id = start(h);
    const legacyRoot = focusRoot(h.workspace);
    const legacyMeta = path.join(legacyRoot, id, 'thread.json');
    const outside = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-focus-race-'));
    const outsideThreads = path.join(outside, 'threads');
    const originalThreads = `${legacyRoot}.original`;
    fs.cpSync(legacyRoot, outsideThreads, { recursive: true });
    const storageRoot = path.join(outside, 'focus-journals');
    const originalOpen = fs.openSync.bind(fs);
    let swapped = false;
    const openSpy = vi.spyOn(fs, 'openSync').mockImplementation((file, flags, mode) => {
      if (!swapped && typeof file === 'string' && path.resolve(file) === legacyMeta) {
        swapped = true;
        fs.renameSync(legacyRoot, originalThreads);
        fs.symlinkSync(outsideThreads, legacyRoot, process.platform === 'win32' ? 'junction' : 'dir');
        try {
          return originalOpen(file, flags, mode);
        } finally {
          fs.unlinkSync(legacyRoot);
          fs.renameSync(originalThreads, legacyRoot);
        }
      }
      return originalOpen(file, flags, mode);
    });

    try {
      expect(() => ThreadJournal.list(h.workspace, storageRoot)).toThrow(/Could not safely migrate Focus thread/);
      expect(swapped).toBe(true);
      expect(fs.existsSync(path.join(path.dirname(focusRoot(h.workspace, storageRoot)), 'migration-v1.json'))).toBe(
        false,
      );
      expect(fs.existsSync(path.join(focusRoot(h.workspace, storageRoot), id))).toBe(false);
    } finally {
      openSpy.mockRestore();
      fs.rmSync(outside, { recursive: true, force: true });
    }
  });

  it('rejects a symlinked private storage root before migrating workspace data', () => {
    const h = harness();
    const appData = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-focus-app-data-'));
    const external = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-focus-storage-target-'));
    const storageRoot = path.join(appData, 'focus-journals');
    const sentinel = path.join(external, 'sentinel.txt');
    fs.writeFileSync(sentinel, 'preserved');
    fs.symlinkSync(external, storageRoot, process.platform === 'win32' ? 'junction' : 'dir');

    try {
      expect(() => ThreadJournal.list(h.workspace, storageRoot)).toThrow(/Unsafe Focus journal storage directory/);
      expect(fs.readFileSync(sentinel, 'utf8')).toBe('preserved');
    } finally {
      fs.rmSync(appData, { recursive: true, force: true });
      fs.rmSync(external, { recursive: true, force: true });
    }
  });

  it('rejects hard-linked event logs before reading or appending', () => {
    const h = harness();
    const id = start(h);
    const journal = ThreadJournal.open(h.workspace, id);
    if (!journal) throw new Error('Expected the newly created thread');
    journal.append(1, { type: 'user', text: 'seed history' });
    const events = path.join(focusRoot(h.workspace), id, 'events.jsonl');
    const sentinel = path.join(h.workspace, 'linked-events.txt');
    fs.renameSync(events, sentinel);
    fs.linkSync(sentinel, events);

    expect(() => journal.readEvents()).toThrow(/Hard-linked/);
    expect(() => journal.append(2, { type: 'assistant', itemId: 'blocked', text: 'blocked' })).toThrow(/Hard-linked/);
    expect(fs.readFileSync(sentinel, 'utf8')).toContain('seed history');

    const metadata = path.join(focusRoot(h.workspace), id, 'thread.json');
    const linkedMetadata = path.join(h.workspace, 'linked-metadata.json');
    fs.renameSync(metadata, linkedMetadata);
    fs.linkSync(linkedMetadata, metadata);
    expect(ThreadJournal.open(h.workspace, id)).toBeNull();
    expect(fs.readFileSync(linkedMetadata, 'utf8')).toContain(id);
  });

  it('rejects symlinked Focus directories and refuses recursive deletion', () => {
    const h = harness();
    const id = start(h);
    const root = path.join(h.workspace, '.agent-toolkit', 'focus', 'threads');
    const dir = path.join(root, id);
    const external = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-focus-external-'));
    const sentinel = path.join(external, 'sentinel.txt');
    fs.writeFileSync(sentinel, 'preserved');
    const originalThread = h.service.readThread(id)?.thread;
    expect(originalThread).toBeDefined();
    if (!originalThread) throw new Error('Expected existing thread before replacing its directory');
    fs.renameSync(dir, path.join(root, 'original'));
    fs.symlinkSync(external, dir, 'dir');
    const journal = new ThreadJournal(h.workspace, { ...originalThread });
    expect(() => journal.remove()).toThrow(/Symlink/);
    expect(() => journal.append(1, { type: 'user', text: 'blocked' })).toThrow(/Symlink/);
    expect(fs.readFileSync(sentinel, 'utf8')).toBe('preserved');
    fs.rmSync(external, { recursive: true, force: true });
  });

  it('rejects a symlinked workspace root rather than trusting its descendants', () => {
    const h = harness();
    const id = start(h);
    const aliasParent = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-focus-alias-'));
    const alias = path.join(aliasParent, 'linked-workspace');
    fs.symlinkSync(h.workspace, alias, 'dir');
    const meta = h.service.readThread(id)?.thread;
    expect(meta).toBeDefined();
    if (!meta) throw new Error('Expected existing thread metadata');
    expect(ThreadJournal.open(alias, id)).toBeNull();
    const journal = new ThreadJournal(alias, { ...meta, workspace: alias });
    expect(() => journal.append(1, { type: 'user', text: 'blocked' })).toThrow(/Symlink/);
    expect(() => journal.remove()).toThrow(/Symlink/);
    expect(ThreadJournal.open(h.workspace, id)).not.toBeNull();
    fs.rmSync(aliasParent, { recursive: true, force: true });
  });

  it('reads thread metadata as untrusted data', () => {
    const h = harness();
    const id = start(h);
    const file = path.join(h.workspace, '.agent-toolkit', 'focus', 'threads', id, 'thread.json');
    const original = JSON.parse(fs.readFileSync(file, 'utf8')) as Record<string, unknown>;
    for (const patch of [
      { permissionMode: 'root' },
      { provider: 'evil' },
      { cwd: 'relative/path' },
      { status: 7 },
      { id: 'th_other00000001' },
    ]) {
      fs.writeFileSync(file, JSON.stringify({ ...original, ...patch }));
      expect(ThreadJournal.open(h.workspace, id)).toBeNull();
    }
    // Missing optional fields are defaulted instead of crashing a listing.
    const sparse = { ...original };
    delete sparse['usage'];
    delete sparse['updatedAt'];
    fs.writeFileSync(file, JSON.stringify(sparse));
    expect(ThreadJournal.open(h.workspace, id)?.thread.usage).toEqual({
      inputTokens: 0,
      cachedInputTokens: 0,
      outputTokens: 0,
      costUsd: null,
    });
    expect(h.service.listThreads()).toHaveLength(1);
  });

  it('does not accept a metadata-only destination as a completed migration', () => {
    const h = harness();
    const id = start(h);
    ThreadJournal.open(h.workspace, id)?.append(1, { type: 'user', text: 'keep the old record' });
    const legacyEvents = path.join(focusRoot(h.workspace), id, 'events.jsonl');
    const originalEvents = fs.readFileSync(legacyEvents);
    const appData = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-focus-partial-migration-'));
    const storageRoot = path.join(appData, 'focus-journals');
    const destination = path.join(focusRoot(h.workspace, storageRoot), id);
    fs.mkdirSync(destination, { recursive: true });
    fs.copyFileSync(path.join(focusRoot(h.workspace), id, 'thread.json'), path.join(destination, 'thread.json'));

    try {
      expect(() => ThreadJournal.list(h.workspace, storageRoot)).toThrow(/resume Focus thread migration/);
      expect(fs.readFileSync(legacyEvents)).toEqual(originalEvents);
      expect(fs.existsSync(path.join(path.dirname(destination), '..', 'migration-v1.json'))).toBe(false);
    } finally {
      fs.rmSync(appData, { recursive: true, force: true });
    }
  });
});

describe('focus service with a scripted provider', () => {
  it('streams a turn, asks for approval, applies the decision and journals every step', async () => {
    const h = harness();
    const id = start(h);
    expect((await h.service.send(id, 'please edit math.js')).ok).toBe(true);
    await h.waitFor(() => status(h, id) === 'awaiting-approval', 'approval request');

    const request = h.events(id).find((event) => event.type === 'approval.requested');
    expect(request).toMatchObject({ tool: 'Edit', kind: 'edit', title: 'math.js', canAllowForSession: true });
    // A second message cannot jump the queue past a pending decision.
    expect((await h.service.send(id, 'hurry')).ok).toBe(false);

    const requestId = request?.type === 'approval.requested' ? request.requestId : '';
    expect(h.service.respondApproval(id, requestId, 'allow').ok).toBe(true);
    expect(h.service.respondApproval(id, requestId, 'allow').ok).toBe(false);
    await h.waitFor(() => status(h, id) === 'idle', 'turn end');

    expect(types(h.events(id))).toEqual([
      'user',
      'turn.started',
      'assistant',
      'tool.started',
      'approval.requested',
      'approval.resolved',
      'tool.finished',
      'assistant',
      'turn.finished',
    ]);
    const snapshot = h.service.readThread(id);
    expect(snapshot?.thread).toMatchObject({
      title: 'please edit math.js',
      providerSessionId: 'sess-fake-1',
      resolvedModel: 'fake-model-1',
      turns: 1,
      usage: { inputTokens: 10, cachedInputTokens: 0, outputTokens: 5, costUsd: 0.01 },
    });
    const finished = snapshot?.events.at(-1);
    expect(finished).toMatchObject({ type: 'turn.finished', outcome: 'completed' });
    // Live deltas reuse the id of the item that later commits, and are never journaled.
    const deltas = h.updates.filter((update) => update.kind === 'delta');
    const firstAssistant = snapshot?.events.find((event) => event.type === 'assistant');
    expect(deltas.length).toBeGreaterThan(0);
    expect(deltas[0]?.kind === 'delta' && firstAssistant?.type === 'assistant' && deltas[0].itemId).toBe(
      firstAssistant?.type === 'assistant' ? firstAssistant.itemId : null,
    );
    expect(
      deltas
        .filter((d) => d.kind === 'delta' && d.itemId === deltas[0]?.itemId)
        .map((d) => (d.kind === 'delta' ? d.text : ''))
        .join(''),
    ).toBe('I will fix it.');
    // The provider's model list replaces the static fallback once a session has reported it.
    expect((await h.service.providers())[0]?.models.map((model) => model.id)).toEqual(['default', 'small']);
  });

  it('records a denial and lets the provider continue', async () => {
    const h = harness();
    const id = start(h);
    await h.service.send(id, 'edit it');
    await h.waitFor(() => status(h, id) === 'awaiting-approval', 'approval request');
    const request = h.events(id).find((event) => event.type === 'approval.requested');
    h.service.respondApproval(id, request?.type === 'approval.requested' ? request.requestId : '', 'deny');
    await h.waitFor(() => status(h, id) === 'idle', 'turn end');
    const events = h.events(id);
    expect(events.find((event) => event.type === 'approval.resolved')).toMatchObject({ decision: 'deny', by: 'user' });
    expect(events.find((event) => event.type === 'tool.finished')).toMatchObject({ ok: false });
  });

  it('passes session-scoped permission rules back only for allow-session', async () => {
    const h = harness();
    const id = start(h);
    await h.service.send(id, 'edit it');
    await h.waitFor(() => status(h, id) === 'awaiting-approval', 'approval request');
    const request = h.events(id).find((event) => event.type === 'approval.requested');
    h.service.respondApproval(id, request?.type === 'approval.requested' ? request.requestId : '', 'allow-session');
    await h.waitFor(() => status(h, id) === 'idle', 'turn end');
    expect(h.events(id).find((event) => event.type === 'tool.finished')).toMatchObject({
      ok: true,
      // The provider also offered a rule that would be written to user settings; it is not passed back.
      output: 'updated (rules kept: session)',
    });
  });

  it('interrupts a running turn and says so in the history', async () => {
    const h = harness();
    const id = start(h);
    await h.service.send(id, 'a long answer please');
    await h.waitFor(() => h.updates.some((update) => update.kind === 'delta'), 'first delta');
    expect(h.service.interrupt(id).ok).toBe(true);
    await h.waitFor(() => status(h, id) === 'interrupted', 'interrupted status');
    expect(h.events(id).at(-1)).toMatchObject({
      type: 'turn.finished',
      outcome: 'interrupted',
      detail: 'Stopped by you.',
    });
    expect(h.service.interrupt(id).ok).toBe(false);
    // The same provider session keeps working after an interrupt.
    await h.service.send(id, 'still there?');
    await h.waitFor(() => status(h, id) === 'idle', 'follow-up turn');
    expect(h.events(id).at(-2)).toMatchObject({ type: 'assistant', text: 'echo:still there?' });
  });

  it('reports a provider crash as a failed turn with the provider error', async () => {
    const h = harness();
    const id = start(h);
    await h.service.send(id, 'crash now');
    await h.waitFor(() => status(h, id) === 'error', 'error status');
    expect(h.events(id).at(-1)).toMatchObject({
      type: 'turn.finished',
      outcome: 'failed',
      detail: 'fake provider exploded',
    });
    expect(h.service.readThread(id)?.thread.lastError).toBe('fake provider exploded');
  });

  it('closes live turns on shutdown and resumes the provider session after a restart', async () => {
    const first = harness();
    const id = start(first, { model: 'small' });
    await first.service.send(id, 'hello');
    await first.waitFor(() => status(first, id) === 'idle', 'first turn');
    await first.service.send(id, 'a long answer please');
    await first.waitFor(
      () => first.updates.some((update) => update.kind === 'delta' && update.text.startsWith('chunk')),
      'long turn',
    );
    first.service.shutdown();

    const second = harness(first.workspace);
    const thread = second.service.listThreads().find((entry) => entry.id === id);
    expect(thread).toMatchObject({ status: 'interrupted', turns: 2, providerSessionId: 'sess-fake-1' });
    expect(second.events(id).at(-1)).toMatchObject({
      type: 'turn.finished',
      outcome: 'interrupted',
      detail: 'Agent Toolkit was closed while this turn was running.',
    });

    await second.service.send(id, 'back again');
    await second.waitFor(() => status(second, id) === 'idle', 'resumed turn');
    const launches = fs
      .readFileSync(second.argvLog, 'utf8')
      .trim()
      .split('\n')
      .map((line) => JSON.parse(line) as string[]);
    expect(launches[0]).not.toContain('--resume');
    expect(launches.at(-1)).toEqual(expect.arrayContaining(['--resume', 'sess-fake-1', '--model', 'small']));
    expect(second.service.readThread(id)?.thread.turns).toBe(3);
  });

  it('retries reconciliation after a failed private-journal migration in the same service', () => {
    const h = harness();
    const id = start(h);
    const legacy = ThreadJournal.open(h.workspace, id);
    legacy?.append(1, { type: 'user', text: 'unfinished work' });
    legacy?.update({ status: 'running', turns: 1 });

    const appData = fs.mkdtempSync(path.join(os.tmpdir(), 'atk-focus-reconcile-retry-'));
    const storageRoot = path.join(appData, 'focus-journals');
    const legacyEvents = path.join(focusRoot(h.workspace), id, 'events.jsonl');
    const sentinel = path.join(appData, 'sentinel.txt');
    fs.writeFileSync(sentinel, 'do not touch');
    const original = fs.readFileSync(legacyEvents);
    fs.unlinkSync(legacyEvents);
    fs.symlinkSync(sentinel, legacyEvents);
    try {
      const reopened = harness(h.workspace, {}, READY, { journalRoot: storageRoot });
      expect(() => reopened.service.listThreads()).toThrow(/Symlink/);
      expect(fs.readFileSync(sentinel, 'utf8')).toBe('do not touch');

      fs.unlinkSync(legacyEvents);
      fs.writeFileSync(legacyEvents, original);
      expect(reopened.service.listThreads().find((thread) => thread.id === id)?.status).toBe('interrupted');
      expect(reopened.events(id).at(-1)).toMatchObject({
        type: 'turn.finished',
        outcome: 'interrupted',
      });
      expect(reopened.service.listThreads().find((thread) => thread.id === id)?.status).toBe('interrupted');
      expect(reopened.events(id).filter((event) => event.type === 'turn.finished')).toHaveLength(1);
    } finally {
      fs.rmSync(appData, { recursive: true, force: true });
    }
  });

  it('marks a turn interrupted when the app died without a clean shutdown', () => {
    const h = harness();
    const id = start(h);
    const journal = ThreadJournal.open(h.workspace, id);
    journal?.append(1, { type: 'user', text: 'work' });
    journal?.append(1, { type: 'turn.started', model: null });
    journal?.append(1, {
      type: 'approval.requested',
      requestId: 'r1',
      itemId: null,
      tool: 'Bash',
      kind: 'command',
      title: 'rm -rf build',
      input: {},
      canAllowForSession: false,
    });
    journal?.update({ status: 'awaiting-approval', turns: 1 });

    const reopened = harness(h.workspace);
    expect(reopened.service.listThreads()[0]?.status).toBe('interrupted');
    expect(types(reopened.events(id)).slice(-2)).toEqual(['approval.resolved', 'turn.finished']);
    expect(reopened.events(id).at(-2)).toMatchObject({ decision: 'deny', by: 'shutdown' });
  });

  it('starts one provider process when two messages are sent at once', async () => {
    const h = harness();
    const id = start(h);
    const [first, second] = await Promise.all([h.service.send(id, 'one'), h.service.send(id, 'two')]);
    expect([first.ok, second.ok]).toEqual([true, true]);
    await h.waitFor(() => types(h.events(id)).filter((type) => type === 'assistant').length === 2, 'both answers');
    await h.waitFor(() => status(h, id) === 'idle', 'idle');
    expect(fs.readFileSync(h.argvLog, 'utf8').trim().split('\n')).toHaveLength(1);
    const sent = h.events(id).flatMap((event) => (event.type === 'user' ? [event.text] : []));
    expect(sent).toEqual(['one', 'two']);
  });

  it('keeps the process while a turn the provider opened by itself is still running', async () => {
    // The idle timer armed after turn 1 would otherwise fire in the middle of turn 2.
    const h = harness(tempWorkspace(), { FAKE_CLAUDE_SECOND_TURN_MS: '200' }, READY, { idleMs: 60 });
    const id = start(h);
    await h.service.send(id, 'answer twice');
    await h.waitFor(
      () => h.service.readThread(id)?.thread.turns === 2 && status(h, id) === 'idle',
      'second turn closed',
    );
    expect(types(h.events(id))).toEqual([
      'user',
      'turn.started',
      'assistant',
      'turn.finished',
      'turn.started',
      'assistant',
      'turn.finished',
    ]);
    expect(h.events(id).at(-1)).toMatchObject({ outcome: 'completed' });
  });

  it('stops a provider that ignores the interrupt and still closes the turn', async () => {
    const h = harness(tempWorkspace(), { FAKE_CLAUDE_IGNORE_INTERRUPT: '1' }, READY, { interruptGraceMs: 80 });
    const id = start(h);
    await h.service.send(id, 'a long answer please');
    await h.waitFor(() => h.updates.some((update) => update.kind === 'delta'), 'first delta');
    h.service.interrupt(id);
    await h.waitFor(() => status(h, id) === 'interrupted', 'interrupted by watchdog');
    expect(h.events(id).at(-1)).toMatchObject({ type: 'turn.finished', outcome: 'interrupted' });
  });

  it('withdraws an approval the provider cancelled', async () => {
    const h = harness();
    const id = start(h);
    await h.service.send(id, 'please withdraw');
    await h.waitFor(() => status(h, id) === 'idle' && h.events(id).length > 4, 'turn end');
    expect(h.events(id).find((event) => event.type === 'approval.resolved')).toMatchObject({
      decision: 'deny',
      by: 'interrupt',
    });
    expect(h.events(id).at(-1)).toMatchObject({ type: 'turn.finished', outcome: 'completed' });
  });

  it('forgets a provider conversation that can no longer be resumed', async () => {
    const h = harness();
    const id = start(h);
    ThreadJournal.open(h.workspace, id)?.update({ providerSessionId: 'gone' });
    await h.service.send(id, 'hello again');
    await h.waitFor(() => status(h, id) === 'error', 'failed resume');
    const failed = h.events(id).at(-1);
    const detail = failed?.type === 'turn.finished' ? (failed.detail ?? '') : '';
    expect(failed).toMatchObject({ type: 'turn.finished', outcome: 'failed' });
    expect(detail).toContain('No conversation found with session ID: gone');
    expect(detail).toContain('Your next message starts a fresh one');
    expect(h.service.readThread(id)?.thread.providerSessionId).toBeNull();
    await h.service.send(id, 'fresh start');
    await h.waitFor(() => status(h, id) === 'idle', 'fresh session');
    expect(h.service.readThread(id)?.thread.providerSessionId).toBe('sess-fake-1');
  });

  it('rejects values that could be read as command-line flags', () => {
    const h = harness();
    const base = { cwd: h.workspace, projectName: null, provider: 'claude' as const, permissionMode: 'ask' as const };
    expect(h.service.createThread({ ...base, model: '--dangerously-skip-permissions' }).ok).toBe(false);
    expect(h.service.createThread({ ...base, model: 'opus[1m]' }).ok).toBe(true);
    const id = start(h);
    expect(h.service.updateThread(id, { model: '-x' }).ok).toBe(false);
    const args = claudeArgs({ model: '--flag', permissionMode: 'ask', resumeSessionId: '--resume-all' });
    expect(args).not.toContain('--flag');
    expect(args).not.toContain('--resume');
  });

  it('refuses to start when the provider is signed out or the folder is gone', async () => {
    const signedOut = harness(tempWorkspace(), {}, { ...READY, auth: 'signed-out', signInHint: 'claude auth login' });
    const id = start(signedOut);
    const result = await signedOut.service.send(id, 'hi');
    expect(result).toEqual({
      ok: false,
      error: 'Claude Code is not signed in. Run `claude auth login` in a terminal.',
    });
    expect(signedOut.events(id)).toEqual([]);

    const h = harness();
    expect(
      h.service.createThread({
        cwd: path.join(h.workspace, 'missing'),
        projectName: null,
        provider: 'claude',
        model: null,
        permissionMode: 'ask',
      }).ok,
    ).toBe(false);
    expect(
      h.service.createThread({
        cwd: h.workspace,
        projectName: null,
        provider: 'codex',
        model: null,
        permissionMode: 'ask',
      }).ok,
    ).toBe(false);
  });

  it('relaunches with new settings on the next message and blocks changes mid-turn', async () => {
    const h = harness();
    const id = start(h);
    await h.service.send(id, 'a long answer please');
    await h.waitFor(() => h.updates.some((update) => update.kind === 'delta'), 'first delta');
    expect(h.service.updateThread(id, { permissionMode: 'accept-edits' }).ok).toBe(false);
    expect(h.service.deleteThread(id).ok).toBe(false);
    h.service.interrupt(id);
    await h.waitFor(() => status(h, id) === 'interrupted', 'interrupted');
    expect(h.service.updateThread(id, { permissionMode: 'accept-edits', title: 'Renamed' }).ok).toBe(true);
    await h.service.send(id, 'continue');
    await h.waitFor(() => status(h, id) === 'idle', 'second turn');
    const last = fs.readFileSync(h.argvLog, 'utf8').trim().split('\n').at(-1) ?? '';
    expect(JSON.parse(last)).toEqual(
      expect.arrayContaining(['--permission-mode', 'acceptEdits', '--resume', 'sess-fake-1']),
    );
    expect(h.service.deleteThread(id).ok).toBe(true);
    expect(h.service.readThread(id)).toBeNull();
  });
});

describe('claude adapter argv', () => {
  it('maps permission modes and only adds model/resume when set', () => {
    expect(claudeArgs({ model: null, permissionMode: 'ask', resumeSessionId: null })).toEqual([
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
      'default',
    ]);
    expect(claudeArgs({ model: 'opus', permissionMode: 'bypass', resumeSessionId: 's1' }).slice(-6)).toEqual(
      ['--permission-mode', 'bypassPermissions', '--model', 'opus', '--resume', 's1'].slice(-6),
    );
  });
});

describe('tool descriptions', () => {
  it('keeps aliased workspace paths relative when the provider reports the real path', () => {
    const workspace = tempWorkspace();
    const alias = `${workspace}.alias`;
    const physicalWorkspace = fs.realpathSync(workspace);
    const physicalFile = path.join(physicalWorkspace, 'nested', 'file.ts');
    fs.mkdirSync(path.dirname(physicalFile));
    fs.writeFileSync(physicalFile, 'export {};');
    fs.symlinkSync(workspace, alias, process.platform === 'win32' ? 'junction' : 'dir');

    try {
      expect(describeTool('Edit', { file_path: physicalFile }, alias)).toEqual({
        kind: 'edit',
        title: path.join('nested', 'file.ts'),
      });
    } finally {
      fs.rmSync(alias, { recursive: true, force: true });
      fs.rmSync(workspace, { recursive: true, force: true });
    }
  });

  it('classifies provider tools into neutral kinds with a readable title', () => {
    expect(describeTool('Bash', { command: 'npm test\nnpm run lint' }, '/repo')).toEqual({
      kind: 'command',
      title: 'npm test',
    });
    expect(describeTool('Edit', { file_path: '/repo/src/a.ts' }, '/repo')).toEqual({
      kind: 'edit',
      title: path.join('src', 'a.ts'),
    });
    expect(describeTool('Read', { file_path: '/elsewhere/b.ts' }, '/repo')).toEqual({
      kind: 'read',
      title: '/elsewhere/b.ts',
    });
    expect(describeTool('mcp__github__create_issue', {}, '/repo')).toEqual({
      kind: 'other',
      title: 'mcp__github__create_issue',
    });
  });

  it('keeps the head and tail of very long output', () => {
    const clipped = clipOutput(`START${'x'.repeat(40_000)}END`);
    expect(clipped.truncated).toBe(true);
    expect(clipped.output.startsWith('START')).toBe(true);
    expect(clipped.output.endsWith('END')).toBe(true);
  });
});

describe('provider probe', () => {
  it('claims ready only from the CLI account status and never leaks account identifiers', async () => {
    const statuses = await probeProviders({
      find: (name) => (name === 'opencode' ? null : `/bin/${name}`),
      run: async (binary, args) => {
        if (args[0] === '--version')
          return {
            code: 0,
            stdout: binary.endsWith('claude') ? '2.1.322 (Claude Code)' : 'codex-cli 0.167.2',
            stderr: '',
          };
        if (binary.endsWith('claude')) {
          return {
            code: 0,
            stdout: JSON.stringify({
              loggedIn: true,
              authMethod: 'claude.ai',
              subscriptionType: 'pro',
              email: 'someone@example.com',
              orgName: 'Secret Org',
            }),
            stderr: '',
          };
        }
        return { code: 1, stdout: '', stderr: 'Not logged in' };
      },
    });
    expect(statuses.map((status) => [status.id, status.installed, status.auth])).toEqual([
      ['claude', true, 'ready'],
      ['codex', true, 'signed-out'],
      ['opencode', false, 'unknown'],
    ]);
    expect(statuses[0]).toMatchObject({
      version: '2.1.322',
      authDetail: 'Signed in with Claude subscription (pro)',
      signInHint: null,
    });
    expect(statuses[1]?.signInHint).toBe('codex login');
    expect(JSON.stringify(statuses)).not.toMatch(/example\.com|Secret Org/);
  });

  it('keeps the other providers when one probe throws, and reads "not logged in" before "logged in"', async () => {
    const statuses = await probeProviders({
      find: (name) => `/bin/${name}`,
      run: async (binary, args) => {
        if (binary.endsWith('claude')) throw new Error('spawn EINVAL');
        if (args[0] === '--version') return { code: 0, stdout: '1.2.3', stderr: '' };
        if (binary.endsWith('codex')) return { code: 0, stdout: 'Not logged in', stderr: '' };
        return { code: 0, stdout: '10 credentials', stderr: '' };
      },
    });
    expect(statuses.map((status) => [status.id, status.installed, status.auth])).toEqual([
      ['claude', false, 'unknown'],
      ['codex', true, 'signed-out'],
      ['opencode', true, 'ready'],
    ]);
    expect(statuses[0]?.authDetail).toBe('Could not be checked');
  });
});
