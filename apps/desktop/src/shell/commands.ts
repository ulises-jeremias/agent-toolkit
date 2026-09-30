import { DESTINATIONS } from './destinations';

export type CommandGroup = 'Go' | 'Session' | 'Appearance' | 'Help';

export interface PaletteCommand {
  id: string;
  group: CommandGroup;
  title: string;
  hint?: string;
  keys?: readonly string[];
  keywords?: readonly string[];
}

export const PALETTE_COMMANDS: readonly PaletteCommand[] = [
  ...DESTINATIONS.map((destination) => ({
    id: `go:${destination.path}`,
    group: 'Go' as const,
    title: `Go to ${destination.label}`,
    hint: destination.question,
    keywords: [destination.label, destination.path.slice(1)],
  })),
  {
    id: 'go:world-knowledge',
    group: 'Go',
    title: 'Go to shared knowledge (World)',
    hint: 'Semantic place · workspace knowledge / memory',
    keywords: ['world', 'knowledge', 'memory', 'archive'],
  },
  {
    id: 'go:world-terminal',
    group: 'Go',
    title: 'Go to terminal workstation',
    hint: 'Semantic object · open Terminal',
    keywords: ['world', 'terminal', 'pty'],
  },
  {
    id: 'session:new-terminal',
    group: 'Session',
    title: 'New terminal session',
    hint: 'Open a PTY in the dock',
    keywords: ['pty', 'shell', 'dock'],
  },
  {
    id: 'session:start-job',
    group: 'Session',
    title: 'Start a job',
    hint: 'Operations · run an agent-toolkit command',
    keywords: ['job', 'operations'],
  },
  {
    id: 'session:restart-backend',
    group: 'Session',
    title: 'Restart backend',
    hint: 'Relaunch the supervised serve process',
    keywords: ['serve', 'crash'],
  },
  {
    id: 'appearance:paper',
    group: 'Appearance',
    title: 'Use Paper theme',
    keywords: ['light', 'theme'],
  },
  {
    id: 'appearance:ink',
    group: 'Appearance',
    title: 'Use Ink theme',
    keywords: ['dark', 'theme'],
  },
  {
    id: 'appearance:system',
    group: 'Appearance',
    title: 'Use System theme',
    keywords: ['auto', 'theme'],
  },
  {
    id: 'help:shortcuts',
    group: 'Help',
    title: 'Keyboard shortcuts',
    keys: ['?'],
    keywords: ['bindings', 'hotkeys'],
  },
];

export const SHORTCUTS: ReadonlyArray<{ keys: readonly string[]; action: string }> = [
  { keys: ['Ctrl', 'K'], action: 'Open the command palette' },
  { keys: ['Esc'], action: 'Close the innermost dialog' },
  { keys: ['?'], action: 'Show this shortcut map' },
];

export function filterCommands(commands: readonly PaletteCommand[], query: string): PaletteCommand[] {
  const needle = query.trim().toLowerCase();
  if (!needle) return [...commands];
  return commands.filter((command) => {
    const haystack = [command.title, command.hint ?? '', command.group, ...(command.keywords ?? [])]
      .join(' ')
      .toLowerCase();
    return haystack.includes(needle);
  });
}
