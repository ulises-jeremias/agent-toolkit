import { describe, expect, it } from 'vitest';
import type { ModelInfo, Person, ProviderInfo } from '../../lib/api';
import {
  canResumeConversation,
  newProviderSessionId,
  personResumeOptions,
  providerResumeSupport,
} from './providerResume';

const person: Person = {
  spec: 'agent-toolkit/person@1',
  id: 'lina',
  name: 'Lina',
  role: 'reviewer',
  goal: 'Review changes',
  archived: false,
};

function provider(id: string): ProviderInfo {
  return { id, bin: `/usr/bin/${id}`, available: true, capability: 'interactive', version: '1.0' };
}

const model: ModelInfo = { profile: 'balanced', runner: 'claude', model: 'model-x' };
const ID = '0199da6e-0000-7000-8000-000000000001';

describe('providerResumeSupport', () => {
  it('classifies verified dialects and refuses to guess the rest', () => {
    expect(providerResumeSupport('claude')).toEqual({ kind: 'assign' });
    expect(providerResumeSupport('copilot')).toEqual({ kind: 'assign' });
    expect(providerResumeSupport('codex')).toEqual({ kind: 'capture' });
    // opencode ids are timestamp-encoded and cannot be assigned safely;
    // gemini was not verified against an installed CLI.
    expect(providerResumeSupport('opencode')).toBeNull();
    expect(providerResumeSupport('gemini')).toBeNull();
    expect(providerResumeSupport('cursor')).toBeNull();
  });

  it('requires both a supported runner and a recorded conversation id', () => {
    expect(canResumeConversation('claude', ID)).toBe(true);
    expect(canResumeConversation('claude', '')).toBe(false);
    expect(canResumeConversation('claude', undefined)).toBe(false);
    expect(canResumeConversation('opencode', 'ses_abc')).toBe(false);
  });

  it('generates UUID-shaped assignable ids', () => {
    expect(newProviderSessionId()).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  });
});

describe('personResumeOptions', () => {
  it('resumes claude with --resume before the optional prompt', () => {
    const options = personResumeOptions(person, provider('claude'), model, '/work/project', 'project', ID, 'Continue');
    expect(options?.args).toEqual([
      '--model',
      'model-x',
      '--resume',
      ID,
      'Role: reviewer\nConfigured goal: Review changes\n\nTask for this session:\nContinue',
    ]);
    expect(options?.providerSessionId).toBe(ID);
  });

  it('resumes codex via the resume subcommand without inventing a model flag', () => {
    const options = personResumeOptions(person, provider('codex'), model, '/work/project', 'project', ID);
    expect(options?.args).toEqual(['resume', ID]);
    expect(options?.cmd).toBe('/usr/bin/codex');
  });

  it('resumes copilot with --session-id and the interactive prompt', () => {
    const options = personResumeOptions(person, provider('copilot'), undefined, '/work/project', 'project', ID, 'Go');
    expect(options?.args).toEqual([
      '--session-id',
      ID,
      '--interactive',
      'Role: reviewer\nConfigured goal: Review changes\n\nTask for this session:\nGo',
    ]);
  });

  it('returns null for unsupported runners, missing ids and unavailable providers', () => {
    expect(
      personResumeOptions(person, provider('opencode'), undefined, '/work/project', 'project', 'ses_abc'),
    ).toBeNull();
    expect(personResumeOptions(person, provider('claude'), undefined, '/work/project', 'project', '')).toBeNull();
    expect(
      personResumeOptions(
        person,
        { ...provider('claude'), available: false },
        undefined,
        '/work/project',
        'project',
        ID,
      ),
    ).toBeNull();
  });
});
