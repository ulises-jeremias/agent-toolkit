import type { ITerminalOptions } from '@xterm/xterm';

/**
 * xterm takes literal colours, not CSS variables. These mirror the terminal
 * primitives in tokens.css (Cozy World night, gold, sage, rust, teal); the
 * terminal keeps one dark palette in both Meadow and Dusk.
 */
export const TERMINAL_OPTIONS: ITerminalOptions = {
  theme: {
    background: '#161510',
    foreground: '#e9e1cf',
    cursor: '#39ff9b',
    cursorAccent: '#161510',
    selectionBackground: 'rgba(212, 169, 75, 0.35)',
    black: '#161510',
    red: '#e07a62',
    green: '#39ff9b',
    yellow: '#d4a94b',
    blue: '#7fa8c4',
    magenta: '#b894b8',
    cyan: '#7fb8ad',
    white: '#e9e1cf',
    brightBlack: '#6a6252',
    brightRed: '#ec9a84',
    brightGreen: '#39ff9b',
    brightYellow: '#e6c070',
    brightBlue: '#9cc0d8',
    brightMagenta: '#d0add0',
    brightCyan: '#9cd0c6',
    brightWhite: '#fcf7ec',
  },
  fontFamily: "'IBM Plex Mono', ui-monospace, Menlo, monospace",
  fontSize: 13,
  lineHeight: 1.2,
  cursorBlink: false,
  allowProposedApi: true,
  scrollback: 5000,
};
