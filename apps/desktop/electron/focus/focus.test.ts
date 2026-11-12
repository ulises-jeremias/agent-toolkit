// @vitest-environment node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, describe, expect, it } from 'vitest';
import type { FocusEvent, FocusLiveUpdate, FocusProviderStatus } from '../../src/types/focus';
import { clipOutput, describeTool } from './adapter.js';
import { ClaudeSession, claudeArgs } from './claude.js';
import { isThreadId, newThreadId, ThreadJournal } from './journal.js';
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
): Harness {
  const updates: FocusLiveUpdate[] = [];
  const argvLog = path.join(workspace, 'argv.log');
  const service = new FocusService({
    getWorkspace: () => workspace,
    emit: (update) => updates.push(update),
    env: () => ({ ...process.env, FAKE_CLAUDE_LOG: argvLog, ...env }),
    probe: async () => [provider],
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
      output: 'updated (session rule saved)',
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
  it('classifies provider tools into neutral kinds with a readable title', () => {
    expect(describeTool('Bash', { command: 'npm test\nnpm run lint' }, '/repo')).toEqual({
      kind: 'command',
      title: 'npm test',
    });
    expect(describeTool('Edit', { file_path: '/repo/src/a.ts' }, '/repo')).toEqual({ kind: 'edit', title: 'src/a.ts' });
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
});
