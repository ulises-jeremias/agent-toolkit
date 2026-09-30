/** First-run completion lives in this window's profile, not in the workspace. */

export const ONBOARDING_STORAGE_KEY = 'atk.desktop.onboarding.complete';

export const REPLAY_ONBOARDING_EVENT = 'atk:replay-onboarding';

export function readOnboardingComplete(): boolean {
  try {
    return window.localStorage.getItem(ONBOARDING_STORAGE_KEY) === '1';
  } catch {
    return false;
  }
}

export function writeOnboardingComplete(): void {
  window.localStorage.setItem(ONBOARDING_STORAGE_KEY, '1');
}

export function clearOnboardingComplete(): void {
  window.localStorage.removeItem(ONBOARDING_STORAGE_KEY);
}

/** Electron first-run only. Browser-dev has no harness supervisor. */
export function shouldRunOnboarding(): boolean {
  return typeof window !== 'undefined' && Boolean(window.atk) && !readOnboardingComplete();
}

export function requestOnboardingReplay(): void {
  clearOnboardingComplete();
  window.dispatchEvent(new Event(REPLAY_ONBOARDING_EVENT));
}
