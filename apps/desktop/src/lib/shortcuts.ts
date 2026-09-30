/**
 * Global keyboard shortcuts. One table feeds the global handler, the command
 * palette hints, the shortcut map and the terminal's reserved-chord filter,
 * so a chord can never mean two things.
 *
 * "Mod" is Ctrl, or Cmd on macOS; either modifier is accepted everywhere.
 */

export const GOTO_INDEXES = [1, 2, 3, 4, 5, 6, 7] as const;
export type GotoIndex = (typeof GOTO_INDEXES)[number];

export type ShortcutId = 'palette' | 'paletteAlt' | 'shortcuts' | 'toggleDock' | `goto${GotoIndex}`;

export interface KeyLike {
  key: string;
  code: string;
  ctrlKey: boolean;
  metaKey: boolean;
  shiftKey: boolean;
  altKey: boolean;
}

export interface Shortcut {
  id: ShortcutId;
  /** Display tokens, e.g. ['Mod', 'K']. */
  keys: readonly string[];
  description: string;
  matches: (event: KeyLike) => boolean;
}

function mod(event: KeyLike): boolean {
  return (event.ctrlKey || event.metaKey) && !event.altKey;
}

function gotoShortcut(index: GotoIndex): Shortcut {
  const digit = String(index);
  return {
    id: `goto${index}` as const,
    keys: ['Mod', digit],
    description: `Go to destination ${index}`,
    matches: (event) => mod(event) && !event.shiftKey && (event.code === `Digit${digit}` || event.key === digit),
  };
}

export const SHORTCUTS: readonly Shortcut[] = [
  {
    id: 'palette',
    keys: ['Mod', 'K'],
    description: 'Open the command palette',
    matches: (event) => mod(event) && !event.shiftKey && event.key.toLowerCase() === 'k',
  },
  {
    id: 'paletteAlt',
    keys: ['Mod', 'Shift', 'P'],
    description: 'Open the command palette',
    matches: (event) => mod(event) && event.shiftKey && event.key.toLowerCase() === 'p',
  },
  {
    id: 'shortcuts',
    keys: ['Mod', '/'],
    description: 'Show keyboard shortcuts',
    matches: (event) => mod(event) && (event.code === 'Slash' || event.key === '/'),
  },
  {
    id: 'toggleDock',
    keys: ['Mod', '`'],
    description: 'Show or hide the terminal dock',
    matches: (event) => mod(event) && !event.shiftKey && (event.code === 'Backquote' || event.key === '`'),
  },
  ...GOTO_INDEXES.map(gotoShortcut),
];

export function matchShortcut(event: KeyLike): ShortcutId | null {
  return SHORTCUTS.find((shortcut) => shortcut.matches(event))?.id ?? null;
}

/**
 * Chords the app keeps for itself even while a terminal has focus. Everything
 * else, including Ctrl+C, Ctrl+D and Ctrl+L, reaches the PTY unchanged.
 */
export function isReservedChord(event: KeyLike): boolean {
  return matchShortcut(event) !== null;
}

export function shortcutKeys(id: ShortcutId): readonly string[] {
  return SHORTCUTS.find((shortcut) => shortcut.id === id)?.keys ?? [];
}

/** Resolve display tokens for the current platform ("Mod" becomes Ctrl or ⌘). */
export function displayKeys(keys: readonly string[], isMac: boolean): string[] {
  return keys.map((key) => (key === 'Mod' ? (isMac ? '⌘' : 'Ctrl') : key));
}

/** Value for the `aria-keyshortcuts` attribute, e.g. "Control+Shift+P". */
export function ariaKeyShortcuts(keys: readonly string[], isMac: boolean): string {
  return keys.map((key) => (key === 'Mod' ? (isMac ? 'Meta' : 'Control') : key)).join('+');
}

export function isMacPlatform(userAgent: string): boolean {
  return /Mac|iPhone|iPad/.test(userAgent);
}

export const IS_MAC = typeof navigator !== 'undefined' && isMacPlatform(navigator.userAgent);
