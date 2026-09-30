import { afterEach, describe, expect, it } from 'vitest';
import {
  clearOnboardingComplete,
  ONBOARDING_STORAGE_KEY,
  readOnboardingComplete,
  shouldRunOnboarding,
  writeOnboardingComplete,
} from './complete';

describe('onboarding completion', () => {
  afterEach(() => {
    window.localStorage.clear();
    delete window.atk;
  });

  it('is incomplete until written', () => {
    expect(readOnboardingComplete()).toBe(false);
    writeOnboardingComplete();
    expect(readOnboardingComplete()).toBe(true);
    expect(window.localStorage.getItem(ONBOARDING_STORAGE_KEY)).toBe('1');
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
