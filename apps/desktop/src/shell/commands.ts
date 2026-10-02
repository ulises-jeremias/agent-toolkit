import { DESTINATIONS } from './destinations';
import type { Person } from '../lib/api';
import type { PtySessionInfo } from '../types/electron';

export type CommandGroup = 'Go' | 'People' | 'Session' | 'Appearance' | 'Help';

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
    id: 'session:start-swarm',
    group: 'Session',
    title: 'Start a swarm',
    hint: 'Choose a recipe and task in Operations',
    keywords: ['team', 'agents', 'operations', 'recipe'],
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
    id: 'appearance:meadow',
    group: 'Appearance',
    title: 'Use Meadow theme',
    keywords: ['light', 'theme'],
  },
  {
    id: 'appearance:dusk',
    group: 'Appearance',
    title: 'Use Dusk theme',
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

/** Dynamic direct actions for saved People; session actions require a live PTY. */
export function personCommands(
  people: readonly Pick<Person, 'id' | 'name' | 'role' | 'archived'>[],
  sessions: readonly Pick<PtySessionInfo, 'personId' | 'projectId' | 'exitCode'>[],
): PaletteCommand[] {
  return [...people]
    .sort((a, b) => a.name.localeCompare(b.name))
    .flatMap((person) => {
      const liveSession = sessions.find((session) => session.personId === person.id && session.exitCode === null);
      const commonKeywords = ['people', 'person', person.id, person.name, person.role];
      const commands: PaletteCommand[] = [
        {
          id: `people:inspect:${person.id}`,
          group: 'People',
          title: `Inspect ${person.name}`,
          hint: `${person.role}${person.archived ? ' · archived' : ''}`,
          keywords: [...commonKeywords, 'profile', 'details', 'open'],
        },
      ];
      if (liveSession) {
        commands.push({
          id: `people:session:${person.id}`,
          group: 'People',
          title: `Open ${person.name}'s terminal`,
          hint: `${person.role} · live PTY${liveSession.projectId ? ` · ${liveSession.projectId}` : ''}`,
          keywords: [...commonKeywords, 'terminal', 'session', 'running', liveSession.projectId ?? ''],
        });
      } else if (!person.archived) {
        commands.push({
          id: `people:start:${person.id}`,
          group: 'People',
          title: `Start ${person.name}`,
          hint: `${person.role} · review project and runner`,
          keywords: [...commonKeywords, 'start', 'run', 'collaborator'],
        });
      }
      return commands;
    });
}

export const SHORTCUTS: ReadonlyArray<{ keys: readonly string[]; action: string }> = [
  { keys: ['Ctrl', 'K'], action: 'Open the command palette' },
  { keys: ['Esc'], action: 'Close the innermost dialog' },
  { keys: ['?'], action: 'Show this shortcut map' },
];

export function filterCommands(commands: readonly PaletteCommand[], query: string): PaletteCommand[] {
  const terms = query.trim().toLowerCase().split(/\s+/).filter(Boolean);
  if (terms.length === 0) return [...commands];
  return commands.filter((command) => {
    const haystack = [command.title, command.hint ?? '', command.group, ...(command.keywords ?? [])]
      .join(' ')
      .toLowerCase();
    return terms.every((term) => haystack.includes(term));
  });
}
