import { describe, expect, it } from 'vitest';
import type { FocusProviderStatus } from '../../types/focus';
import { permissionModeBlocker, providerSupportsPermissionMode } from './labels';

const provider: FocusProviderStatus = {
  id: 'claude',
  label: 'Claude Code',
  installed: true,
  binary: '/usr/bin/claude',
  version: '1.2.3',
  auth: 'ready',
  authDetail: 'Signed in',
  signInHint: null,
  permissionModes: ['accept-edits', 'plan'],
  models: [],
  capabilities: { sessions: true, approvals: true, interrupt: true, resume: true, modelSwitch: true },
  checkedAt: new Date(0).toISOString(),
};

describe('provider permission modes', () => {
  it('uses the probed CLI choices and explains when Ask cannot be enforced', () => {
    expect(providerSupportsPermissionMode(provider, 'plan')).toBe(true);
    expect(providerSupportsPermissionMode(provider, 'ask')).toBe(false);
    expect(permissionModeBlocker(provider, 'ask')).toBe(
      'Claude Code 1.2.3 does not support Ask before changes in Focus. Update the CLI, then check again.',
    );
    expect(permissionModeBlocker(provider, 'plan')).toBeNull();
  });

  it('keeps legacy provider fixtures compatible when no mode probe is supplied', () => {
    const legacy = { ...provider, permissionModes: undefined };
    expect(providerSupportsPermissionMode(legacy, 'ask')).toBe(true);
  });
});
