import { afterEach, describe, expect, it } from 'vitest';
import {
  clearOnboardingComplete,
  readOnboardingComplete,
  shouldRunOnboarding,
  writeOnboardingComplete,
} from './complete';

describe('onboarding completion', () => {
  afterEach(() => {
    clearOnboardingComplete();
    delete window.atk;
  });

  it('is incomplete until written', () => {
    expect(readOnboardingComplete()).toBe(false);
    writeOnboardingComplete();
    expect(readOnboardingComplete()).toBe(true);
    clearOnboardingComplete();
    expect(readOnboardingComplete()).toBe(false);
  });

  it('runs only in Electron before completion', () => {
    expect(shouldRunOnboarding()).toBe(false);
    window.atk = {} as Window['atk'];
    expect(shouldRunOnboarding()).toBe(true);
    writeOnboardingComplete();
    expect(shouldRunOnboarding()).toBe(false);
  });
});
