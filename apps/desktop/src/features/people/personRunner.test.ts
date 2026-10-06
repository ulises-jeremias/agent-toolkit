import { describe, expect, it } from 'vitest';
import type { ModelInfo, Person, ProviderInfo } from '../../lib/api';
import { initialPromptMode, personInitialPrompt, personSessionOptions } from './personRunner';

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
    const model: ModelInfo = { profile: 'balanced', runner: 'opencode', model: 'model-x' };
    expect(
      personSessionOptions({ ...person, budget: { max_seconds: 90 } }, provider, model, '/work/project', 'project'),
    ).toEqual({
      agent: 'Lina',
      personId: 'lina',
      projectId: 'project',
      provider: 'opencode',
      model: 'model-x',
      cmd: '/usr/bin/opencode',
      args: ['--model', 'model-x'],
      cwd: '/work/project',
      maxSeconds: 90,
    });
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
        'model-x',
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
  ])('sends a reviewed initial task to %s using its interactive CLI contract', (providerId, args) => {
    expect(
      personSessionOptions(
        person,
        { ...provider, id: providerId },
        { profile: 'balanced', runner: providerId, model: 'model-x' },
        '/work/project',
        'project',
        '  Review this PR  ',
      )?.args,
    ).toEqual(args);
  });

  it('keeps unsupported runners interactive and never guesses prompt flags', () => {
    expect(initialPromptMode('cursor')).toBe('unsupported');
    expect(
      personSessionOptions(person, { ...provider, id: 'cursor' }, undefined, '/work/project', 'project', 'task')?.args,
    ).toEqual([]);
  });

  it('does not send a prompt when the user clears the one-time task', () => {
    expect(personInitialPrompt(person, '  ')).toBeNull();
    expect(personSessionOptions(person, provider, undefined, '/work/project', 'project', '')?.args).toEqual([]);
  });
});
