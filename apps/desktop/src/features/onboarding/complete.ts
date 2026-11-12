/** First-run completion lives in this window's profile, not in the workspace. */

import { currentDesktopPreferences, updateDesktopPreferences } from '../../shell/desktopPreferences';

export const REPLAY_ONBOARDING_EVENT = 'atk:replay-onboarding';

export function readOnboardingComplete(): boolean {
  return currentDesktopPreferences().onboardingComplete;
}

export function writeOnboardingComplete(): void {
  updateDesktopPreferences({ onboardingComplete: true });
}

export function clearOnboardingComplete(): void {
  updateDesktopPreferences({ onboardingComplete: false });
}

/** Electron first-run only. Browser-dev has no harness supervisor. */
export function shouldRunOnboarding(): boolean {
  return typeof window !== 'undefined' && Boolean(window.atk) && !readOnboardingComplete();
}

export function requestOnboardingReplay(): void {
  clearOnboardingComplete();
  window.dispatchEvent(new Event(REPLAY_ONBOARDING_EVENT));
}
