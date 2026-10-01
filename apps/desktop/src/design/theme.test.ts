import { describe, expect, it } from 'vitest';
import { parseMotionPreference, parseThemePreference, resolveTheme } from './theme';

describe('appearance preferences', () => {
  it('falls back to system for unknown stored values', () => {
    expect(parseThemePreference(null)).toBe('system');
    expect(parseThemePreference('neon')).toBe('system');
    expect(parseThemePreference('dusk')).toBe('dusk');
    expect(parseMotionPreference('reduced')).toBe('reduced');
    expect(parseMotionPreference('fast')).toBe('system');
  });

  it('resolves system from the OS scheme and honours explicit choices', () => {
    expect(resolveTheme('system', true)).toBe('dusk');
    expect(resolveTheme('system', false)).toBe('meadow');
    expect(resolveTheme('meadow', true)).toBe('meadow');
  });
});
