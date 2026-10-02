import { describe, expect, it } from 'vitest';
import type { ModelInfo, Person, ProviderInfo } from '../../lib/api';
import { personSessionOptions } from './personRunner';

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
    expect(personSessionOptions(person, provider, model, '/work/project', 'project')).toEqual({
      agent: 'Lina',
      personId: 'lina',
      projectId: 'project',
      provider: 'opencode',
      model: 'model-x',
      cmd: '/usr/bin/opencode',
      args: ['--model', 'model-x'],
      cwd: '/work/project',
    });
  });

  it('refuses unavailable, skeleton, or unresolved runners', () => {
    expect(personSessionOptions(person, { ...provider, available: false }, undefined, '/work', 'p')).toBeNull();
    expect(personSessionOptions(person, { ...provider, id: 'skeleton' }, undefined, '/work', 'p')).toBeNull();
    expect(personSessionOptions(person, provider, undefined, '', 'p')).toBeNull();
  });
});
