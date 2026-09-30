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
    title: 'Go to shared knowledge (Library)',
    hint: 'Inspector the world opens · catalog knowledge, not memory',
    keywords: ['world', 'knowledge', 'library', 'archive'],
  },
  {
    id: 'go:world-memory',
    group: 'Go',
    title: 'Open memory archive',
    hint: 'Semantic place · card index on the world grounds',
    keywords: ['world', 'memory', 'archive', 'records'],
  },
  {
    id: 'go:world-projects',
    group: 'Go',
    title: 'Open project houses',
    hint: 'Semantic district · real project cottages on /world',
    keywords: ['world', 'project', 'house', 'grounds'],
  },
  {
    id: 'go:world-terminal',
    group: 'Go',
    title: 'Open terminal workstation',
    hint: 'Semantic object · focus Terminal on the world',
    keywords: ['world', 'terminal', 'pty'],
  },
  {
    id: 'go:world-attention',
    group: 'Go',
    title: 'Open attention (Needs you)',
    hint: 'Semantic stamp · focus Needs you, then Office',
    keywords: ['world', 'office', 'attention', 'needs'],
  },
  {
    id: 'session:new-terminal',
    group: 'Session',
    title: 'New terminal session',
    hint: 'Open a PTY at this workstation',
    keywords: ['pty', 'shell', 'dock', 'workstation'],
  },
  {
    id: 'session:start-job',
    group: 'Session',
    title: 'Start a job',
    hint: 'Operations · inspect the job that serve returns',
    keywords: ['job', 'operations', 'workshop'],
  },
  {
    id: 'session:run-loop',
    group: 'Session',
    title: 'Run a loop as a job',
    hint: 'Operations · POST /loops/{name}/run',
    keywords: ['loop', 'operations', 'workshop'],
  },
  {
    id: 'session:next-needs-me',
    group: 'Session',
    title: 'Next that needs me',
    hint: 'Cycle crash, failed jobs, then running work',
    keywords: ['attention', 'failed', 'crash', 'next', 'needs'],
  },
  {
    id: 'session:restart-backend',
    group: 'Session',
    title: 'Restart backend',
    hint: 'Relaunch the supervised serve process',
    keywords: ['serve', 'crash'],
  },
  {
    id: 'session:replay-onboarding',
    group: 'Session',
    title: 'Run first-run setup again',
    hint: 'Replay harness confirm, then enter the world',
    keywords: ['onboarding', 'setup', 'welcome'],
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
