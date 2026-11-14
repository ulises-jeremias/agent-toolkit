import { useSyncExternalStore } from 'react';
import { currentDesktopPreferences, updateDesktopPreferences } from '../shell/desktopPreferences';

/**
 * Appearance preferences (renderer-local UI state).
 *
 * Theme and motion are durable per-user preferences; `serve` exposes no
 * userData preferences are owned by Electron; this module is the live renderer cache.
 */

export type ThemePreference = 'system' | 'meadow' | 'dusk';
export type ResolvedTheme = 'meadow' | 'dusk';
export type MotionPreference = 'system' | 'reduced';

export interface Appearance {
  theme: ThemePreference;
  resolvedTheme: ResolvedTheme;
  motion: MotionPreference;
}

export function parseThemePreference(raw: string | null): ThemePreference {
  return raw === 'meadow' || raw === 'dusk' || raw === 'system' ? raw : 'system';
}

export function parseMotionPreference(raw: string | null): MotionPreference {
  return raw === 'reduced' ? 'reduced' : 'system';
}

export function resolveTheme(preference: ThemePreference, prefersDark: boolean): ResolvedTheme {
  if (preference === 'system') return prefersDark ? 'dusk' : 'meadow';
  return preference;
}

function prefersDarkQuery(): MediaQueryList | null {
  return typeof window.matchMedia === 'function' ? window.matchMedia('(prefers-color-scheme: dark)') : null;
}

const listeners = new Set<() => void>();
let snapshot: Appearance = computeAppearance();

function computeAppearance(): Appearance {
  const stored = currentDesktopPreferences();
  const theme = parseThemePreference(stored.theme);
  const motion = parseMotionPreference(stored.motion);
  return { theme, motion, resolvedTheme: resolveTheme(theme, prefersDarkQuery()?.matches ?? false) };
}

function applyToDocument(appearance: Appearance): void {
  const root = document.documentElement;
  root.dataset.theme = appearance.resolvedTheme;
  root.dataset.themePreference = appearance.theme;
  if (appearance.motion === 'reduced') root.dataset.motion = 'reduced';
  else delete root.dataset.motion;
}

function refresh(): void {
  snapshot = computeAppearance();
  applyToDocument(snapshot);
  for (const listener of listeners) listener();
}

/** Apply the stored appearance before first paint and follow OS changes. */
export function initAppearance(): void {
  // This module is evaluated before the async Electron preferences read in
  // main.tsx completes. Recompute now so a durable theme restored on startup
  // is not overwritten by the module's initial system-theme snapshot.
  refresh();
  prefersDarkQuery()?.addEventListener('change', refresh);
}

export function setThemePreference(theme: ThemePreference): void {
  updateDesktopPreferences({ theme });
  refresh();
}

export function setMotionPreference(motion: MotionPreference): void {
  updateDesktopPreferences({ motion });
  refresh();
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function useAppearance(): Appearance {
  return useSyncExternalStore(subscribe, () => snapshot);
}
