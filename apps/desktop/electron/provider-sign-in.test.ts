import { describe, expect, it } from 'vitest';
import { resolveProviderSignIn } from './provider-sign-in.js';

describe('provider sign-in command allowlist', () => {
  it('maps the Claude provider id to the fixed Claude login command', () => {
    expect(resolveProviderSignIn('claude', () => '/opt/bin/claude')).toMatchObject({
      binary: '/opt/bin/claude',
      args: ['auth', 'login'],
      terminal: { cmd: '/opt/bin/claude', args: ['auth', 'login'], ephemeral: true },
    });
  });

  it('maps the Codex provider id to the fixed Codex login command', () => {
    expect(resolveProviderSignIn('codex', () => '/opt/bin/codex')).toMatchObject({
      binary: '/opt/bin/codex',
      args: ['login'],
      terminal: { cmd: '/opt/bin/codex', args: ['login'], ephemeral: true },
    });
  });

  it('rejects unknown ids and providers without an installed binary', () => {
    expect(resolveProviderSignIn('opencode', () => '/bin/opencode')).toBeNull();
    expect(resolveProviderSignIn('claude', () => null)).toBeNull();
  });
});
