import { describe, expect, it } from 'vitest';
import type { BackendState, HarnessResolution } from '../../types/electron';
import { backendIsReady, harnessIsChosen, harnessNeedsCreate } from './steps';

const harness = (source: HarnessResolution['source']): HarnessResolution => ({
  path: '/ws',
  source,
  defaultPath: '/home/u/.ai-workspace',
  overrideVar: source === 'override' ? 'AGENT_TOOLKIT_WORKSPACE' : null,
  notice: source === 'fallback' ? 'missing' : null,
});

describe('onboarding step gates', () => {
  it('treats default, override, and user-chosen harnesses as chosen', () => {
    expect(harnessIsChosen(harness('default'))).toBe(true);
    expect(harnessIsChosen(harness('override'))).toBe(true);
    expect(harnessIsChosen(harness('user'))).toBe(true);
    expect(harnessIsChosen(harness('fallback'))).toBe(false);
    expect(harnessNeedsCreate(harness('fallback'))).toBe(true);
    expect(harnessNeedsCreate(harness('default'))).toBe(false);
  });

  it('waits for a ready backend', () => {
    expect(backendIsReady({ status: 'ready' } as BackendState)).toBe(true);
    expect(backendIsReady({ status: 'starting' } as BackendState)).toBe(false);
    expect(backendIsReady(null)).toBe(false);
  });
});
