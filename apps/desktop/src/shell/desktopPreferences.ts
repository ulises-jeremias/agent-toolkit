import type { DesktopPreferences, DesktopRouteMemory } from '../types/electron';

const DEFAULTS: DesktopPreferences = {
  version: 1,
  onboardingComplete: false,
  theme: 'system',
  motion: 'system',
  routes: {},
};
let preferences = DEFAULTS;

export function currentDesktopPreferences(): DesktopPreferences {
  return preferences;
}

export async function initializeDesktopPreferences(): Promise<void> {
  if (!window.atk) return;
  try {
    preferences = await window.atk.preferences.read();
  } catch {
    // A preference read failure must never prevent the application from opening.
    preferences = DEFAULTS;
  }
}

export function updateDesktopPreferences(patch: Partial<Omit<DesktopPreferences, 'version'>>): void {
  preferences = { ...preferences, ...patch };
  if (window.atk?.preferences) void window.atk.preferences.update(patch).catch(() => undefined);
}

export function rememberRoute(workspace: string, route: DesktopRouteMemory): void {
  updateDesktopPreferences({ routes: { ...preferences.routes, [workspace]: route } });
}
