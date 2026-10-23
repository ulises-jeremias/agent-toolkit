import { describe, expect, it } from 'vitest';
import type { ModelInfo, Person, ProviderInfo } from '../../lib/api';
import { initialPromptMode, modelIdUsableForRunner, personInitialPrompt, personSessionOptions } from './personRunner';

const person: Person = {
  spec: 'agent-toolkit/person@1',
  id: 'lina',
  name: 'Lina',
  role: 'reviewer',
  goal: 'Review changes',
  archived: false,
};

const provider: ProviderInfo = {
  id: 'opencode',
  bin: '/usr/bin/opencode',
  available: true,
  capability: 'interactive',
  version: '1.0',
};

describe('personSessionOptions', () => {
  it('builds a real runner PTY with argv and project identity metadata', () => {
    const model: ModelInfo = { profile: 'balanced', runner: 'opencode', model: 'opencode/model-x' };
    const options = personSessionOptions(
      { ...person, budget: { max_seconds: 90 } },
      provider,
      model,
      '/work/project',
      'project',
    );
    // opencode is assign-strategy: a ses_-prefixed id is chosen at launch.
    expect(options?.providerSessionId).toMatch(/^ses_[0-9a-f]{24}$/);
    expect(options).toMatchObject({
      agent: 'Lina',
      personId: 'lina',
      projectId: 'project',
      provider: 'opencode',
      model: 'opencode/model-x',
      cmd: '/usr/bin/opencode',
      args: ['--model', 'opencode/model-x', '--session', options?.providerSessionId],
      cwd: '/work/project',
      maxSeconds: 90,
    });
  });

  it('drops bare profile aliases for opencode instead of killing the session at launch', () => {
    const alias: ModelInfo = { profile: 'economy', runner: 'opencode', model: 'haiku' };
    const options = personSessionOptions(person, provider, alias, '/work/project', 'project');
    expect(options?.model).toBeUndefined();
    expect(options?.args).not.toContain('--model');
    // The same shorthand stays usable for runners that accept aliases.
    expect(modelIdUsableForRunner('claude', 'haiku')).toBe(true);
    expect(modelIdUsableForRunner('opencode', 'opencode/flint-40b-free')).toBe(true);
    expect(modelIdUsableForRunner('opencode', 'github-copilot/claude-sonnet-5#high')).toBe(true);
    expect(modelIdUsableForRunner('opencode', 'haiku')).toBe(false);
    expect(modelIdUsableForRunner('opencode', 'Flint 40B Free')).toBe(false);
    expect(modelIdUsableForRunner('opencode', '/model-x')).toBe(false);
    expect(modelIdUsableForRunner('opencode', 'provider/')).toBe(false);
  });

  it('refuses unavailable, skeleton, or unresolved runners', () => {
    expect(personSessionOptions(person, { ...provider, available: false }, undefined, '/work', 'p')).toBeNull();
    expect(personSessionOptions(person, { ...provider, id: 'skeleton' }, undefined, '/work', 'p')).toBeNull();
    expect(personSessionOptions(person, provider, undefined, '', 'p')).toBeNull();
  });

  it.each([
    [
      'claude',
      [
        '--model',
        'model-x',
        'Role: reviewer\nConfigured goal: Review changes\n\nTask for this session:\nReview this PR',
      ],
    ],
    [
      'codex',
      [
        '--model',
        'model-x',
        'Role: reviewer\nConfigured goal: Review changes\n\nTask for this session:\nReview this PR',
      ],
    ],
    [
      'opencode',
      [
        'mini',
        '--model',
        'opencode/model-x',
        '--prompt',
        'Role: reviewer\nConfigured goal: Review changes\n\nTask for this session:\nReview this PR',
      ],
    ],
    [
      'copilot',
      [
        '--model',
        'model-x',
        '--interactive',
        'Role: reviewer\nConfigured goal: Review changes\n\nTask for this session:\nReview this PR',
      ],
    ],
    [
      'cursor',
      [
        '--model',
        'model-x',
        'Role: reviewer\nConfigured goal: Review changes\n\nTask for this session:\nReview this PR',
      ],
    ],
    [
      'muse',
      [
        '--model',
        'model-x',
        'Role: reviewer\nConfigured goal: Review changes\n\nTask for this session:\nReview this PR',
      ],
    ],
  ])('sends a reviewed initial task to %s using its interactive CLI contract', (providerId, args) => {
    const options = personSessionOptions(
      person,
      { ...provider, id: providerId },
      {
        profile: 'balanced',
        runner: providerId,
        model: providerId === 'opencode' ? 'opencode/model-x' : 'model-x',
      },
      '/work/project',
      'project',
      '  Review this PR  ',
    );
    if (providerId === 'claude' || providerId === 'copilot' || providerId === 'opencode') {
      // Assign-strategy runners receive a session id we choose (resume support).
      const flag = providerId === 'opencode' ? '--session' : '--session-id';
      const sessionIdIndex = options?.args?.indexOf(flag) ?? -1;
      expect(sessionIdIndex).toBeGreaterThanOrEqual(0);
      expect(options?.providerSessionId).toBe(options?.args?.[sessionIdIndex + 1]);
      if (providerId === 'opencode') expect(options?.providerSessionId).toMatch(/^ses_/);
      expect(options?.args?.filter((arg) => arg !== flag && arg !== options?.providerSessionId)).toEqual(args);
    } else {
      expect(options?.providerSessionId).toBeUndefined();
      expect(options?.args).toEqual(args);
    }
  });

  it('keeps unsupported runners interactive and never guesses prompt flags', () => {
    expect(initialPromptMode('windsurf')).toBe('unsupported');
    expect(
      personSessionOptions(person, { ...provider, id: 'windsurf' }, undefined, '/work/project', 'project', 'task')
        ?.args,
    ).toEqual([]);
  });

  it('carries durable notes into the reviewed initial prompt', () => {
    expect(personInitialPrompt({ ...person, notes: 'Prefers small PRs.' }, 'Review this PR')).toBe(
      'Role: reviewer\nConfigured goal: Review changes\nDurable notes: Prefers small PRs.\n\nTask for this session:\nReview this PR',
    );
    expect(personInitialPrompt({ ...person, notes: '   ' }, 'Review this PR')).toBe(
      'Role: reviewer\nConfigured goal: Review changes\n\nTask for this session:\nReview this PR',
    );
  });

  it('does not send a prompt when the user clears the one-time task', () => {
    expect(personInitialPrompt(person, '  ')).toBeNull();
    const options = personSessionOptions(person, provider, undefined, '/work/project', 'project', '');
    // No prompt is sent, but the assign-strategy session id still is.
    expect(options?.args).toEqual(['--session', options?.providerSessionId]);
  });
});
