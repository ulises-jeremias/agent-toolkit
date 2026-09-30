import { useSyncExternalStore } from 'react';

/**
 * Appearance preferences (renderer-local UI state).
 *
 * Theme and motion are durable per-user preferences; `serve` exposes no
 * preference endpoint yet, so they persist in localStorage. When the backend
 * owns UI preferences this module becomes a thin cache over that endpoint.
 */

export type ThemePreference = 'system' | 'paper' | 'ink';
export type ResolvedTheme = 'paper' | 'ink';
export type MotionPreference = 'system' | 'reduced';

export interface Appearance {
  theme: ThemePreference;
  resolvedTheme: ResolvedTheme;
  motion: MotionPreference;
}

const THEME_KEY = 'atk.appearance.theme';
const MOTION_KEY = 'atk.appearance.motion';

function readStorage(key: string): string | null {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeStorage(key: string, value: string): void {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // Storage unavailable (private mode, quota): the preference stays session-only.
  }
}

export function parseThemePreference(raw: string | null): ThemePreference {
  return raw === 'paper' || raw === 'ink' || raw === 'system' ? raw : 'system';
}

export function parseMotionPreference(raw: string | null): MotionPreference {
  return raw === 'reduced' ? 'reduced' : 'system';
}

export function resolveTheme(preference: ThemePreference, prefersDark: boolean): ResolvedTheme {
  if (preference === 'system') return prefersDark ? 'ink' : 'paper';
  return preference;
}

function prefersDarkQuery(): MediaQueryList | null {
  return typeof window.matchMedia === 'function' ? window.matchMedia('(prefers-color-scheme: dark)') : null;
}

const listeners = new Set<() => void>();
let snapshot: Appearance = computeAppearance();

function computeAppearance(): Appearance {
  const theme = parseThemePreference(readStorage(THEME_KEY));
  const motion = parseMotionPreference(readStorage(MOTION_KEY));
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
  applyToDocument(snapshot);
  prefersDarkQuery()?.addEventListener('change', refresh);
}

export function setThemePreference(theme: ThemePreference): void {
  writeStorage(THEME_KEY, theme);
  refresh();
}

export function setMotionPreference(motion: MotionPreference): void {
  writeStorage(MOTION_KEY, motion);
  refresh();
}

function subscribe(listener: () => void): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

export function useAppearance(): Appearance {
  return useSyncExternalStore(subscribe, () => snapshot);
}
