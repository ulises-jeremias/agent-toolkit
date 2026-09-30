import { describe, expect, it } from 'vitest';
import { TERMINAL_OPTIONS } from './terminalTheme';

describe('TERMINAL_OPTIONS', () => {
  it('keeps the Paper Co. dock: ink ground, neon prompt, brass selection', () => {
    const theme = TERMINAL_OPTIONS.theme;
    expect(theme?.background).toBe('#161510');
    expect(theme?.cursor).toBe('#39ff9b');
    expect(theme?.green).toBe('#39ff9b');
    expect(theme?.selectionBackground).toBe('rgba(212, 169, 75, 0.35)');
  });
});
