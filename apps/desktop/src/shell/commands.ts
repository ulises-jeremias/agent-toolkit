import { DESTINATIONS, type DestinationPath } from './destinations';
import type { LoopInfo, Person, SwarmRunInfo } from '../lib/api';
import type { PtySessionInfo } from '../types/electron';

export type CommandGroup = 'Go' | 'People' | 'Loops' | 'Swarms' | 'Session' | 'Appearance' | 'Help';

export type PaletteAction =
  | { type: 'navigate'; path: DestinationPath }
  | { type: 'workspace-switch' }
  | {
      type: 'world-jump';
      target: 'world-knowledge' | 'world-memory' | 'world-projects' | 'world-terminal' | 'world-attention';
    }
  | { type: 'world-project'; projectName: string }
  | { type: 'person'; intent: 'inspect' | 'start' | 'session'; personId: string }
  | { type: 'people-workflow'; intent: 'create' | 'import' }
  | { type: 'loop-schedule'; name: string }
  | { type: 'swarm-run'; runId: string }
  | {
      type: 'session';
      intent:
        | 'new-terminal'
        | 'start-job'
        | 'run-loop'
        | 'start-swarm'
        | 'next-needs-me'
        | 'restart-backend'
        | 'replay-onboarding';
    }
  | { type: 'theme'; theme: 'meadow' | 'dusk' | 'system' }
  | { type: 'help'; intent: 'shortcuts' };

export interface PaletteCommand {
  id: string;
  group: CommandGroup;
  title: string;
  hint?: string;
  keys?: readonly string[];
  keywords?: readonly string[];
  action: PaletteAction;
}

export const PALETTE_COMMANDS: readonly PaletteCommand[] = [
  ...DESTINATIONS.map<PaletteCommand>((destination) => ({
    id: `go:${destination.path}`,
    group: 'Go' as const,
    title: `Go to ${destination.label}`,
    hint: destination.question,
    keywords: [destination.label, destination.path.slice(1)],
    action: { type: 'navigate', path: destination.path },
  })),
  {
    id: 'go:world-knowledge',
    group: 'Go',
    title: 'Go to shared knowledge (Library)',
    hint: 'Inspector the world opens · catalog knowledge, not memory',
    keywords: ['world', 'knowledge', 'library', 'archive'],
    action: { type: 'world-jump', target: 'world-knowledge' },
  },
  {
    id: 'go:world-memory',
    group: 'Go',
    title: 'Open memory archive',
    hint: 'Semantic place · card index on the world grounds',
    keywords: ['world', 'memory', 'archive', 'records'],
    action: { type: 'world-jump', target: 'world-memory' },
  },
  {
    id: 'go:world-projects',
    group: 'Go',
    title: 'Open project houses',
    hint: 'Semantic district · real project cottages on /world',
    keywords: ['world', 'project', 'house', 'grounds'],
    action: { type: 'world-jump', target: 'world-projects' },
  },
  {
    id: 'go:world-terminal',
    group: 'Go',
    title: 'Open terminal workstation',
    hint: 'Semantic object · focus Terminal on the world',
    keywords: ['world', 'terminal', 'pty'],
    action: { type: 'world-jump', target: 'world-terminal' },
  },
  {
    id: 'go:world-attention',
    group: 'Go',
    title: 'Open attention (Needs you)',
    hint: 'Semantic stamp · focus Needs you, then Office',
    keywords: ['world', 'office', 'attention', 'needs'],
    action: { type: 'world-jump', target: 'world-attention' },
  },
  {
    id: 'session:new-terminal',
    group: 'Session',
    title: 'New terminal session',
    hint: 'Open a PTY at this workstation',
    keywords: ['pty', 'shell', 'dock', 'workstation'],
    action: { type: 'session', intent: 'new-terminal' },
  },
  {
    id: 'people:create',
    group: 'People',
    title: 'Create Person',
    hint: 'Open the roster form for a reusable collaborator',
    keywords: ['new', 'collaborator', 'hire', 'profile'],
    action: { type: 'people-workflow', intent: 'create' },
  },
  {
    id: 'people:import-munder',
    group: 'People',
    title: 'Import Person from Munder Difflin',
    hint: 'Review a hire file before saving; import never starts a session',
    keywords: ['hire', 'json', 'review', 'munder', 'import'],
    action: { type: 'people-workflow', intent: 'import' },
  },
  {
    id: 'go:switch-workspace',
    group: 'Go',
    title: 'Switch workspace…',
    hint: 'Settings · choose another local workspace or return to the default',
    keywords: ['workspace', 'harness', 'switch', 'context', 'folder'],
    action: { type: 'workspace-switch' },
  },
  {
    id: 'session:start-job',
    group: 'Session',
    title: 'Start a job',
    hint: 'Operations · inspect the job that serve returns',
    keywords: ['job', 'operations', 'workshop'],
    action: { type: 'session', intent: 'start-job' },
  },
  {
    id: 'session:run-loop',
    group: 'Session',
    title: 'Run a loop as a job',
    hint: 'Operations · POST /loops/{name}/run',
    keywords: ['loop', 'operations', 'workshop'],
    action: { type: 'session', intent: 'run-loop' },
  },
  {
    id: 'session:start-swarm',
    group: 'Session',
    title: 'Start a swarm',
    hint: 'Choose a recipe and task in Operations',
    keywords: ['team', 'agents', 'operations', 'recipe'],
    action: { type: 'session', intent: 'start-swarm' },
  },
  {
    id: 'session:next-needs-me',
    group: 'Session',
    title: 'Next that needs me',
    hint: 'Cycle crash, failed jobs, then running work',
    keywords: ['attention', 'failed', 'crash', 'next', 'needs'],
    action: { type: 'session', intent: 'next-needs-me' },
  },
  {
    id: 'session:restart-backend',
    group: 'Session',
    title: 'Restart backend',
    hint: 'Relaunch the supervised serve process',
    keywords: ['serve', 'crash'],
    action: { type: 'session', intent: 'restart-backend' },
  },
  {
    id: 'session:replay-onboarding',
    group: 'Session',
    title: 'Run first-run setup again',
    hint: 'Replay harness confirm, then enter the world',
    keywords: ['onboarding', 'setup', 'welcome'],
    action: { type: 'session', intent: 'replay-onboarding' },
  },
  {
    id: 'appearance:meadow',
    group: 'Appearance',
    title: 'Use Meadow theme',
    keywords: ['light', 'theme'],
    action: { type: 'theme', theme: 'meadow' },
  },
  {
    id: 'appearance:dusk',
    group: 'Appearance',
    title: 'Use Dusk theme',
    keywords: ['dark', 'theme'],
    action: { type: 'theme', theme: 'dusk' },
  },
  {
    id: 'appearance:system',
    group: 'Appearance',
    title: 'Use System theme',
    keywords: ['auto', 'theme'],
    action: { type: 'theme', theme: 'system' },
  },
  {
    id: 'help:shortcuts',
    group: 'Help',
    title: 'Keyboard shortcuts',
    keys: ['?'],
    keywords: ['bindings', 'hotkeys'],
    action: { type: 'help', intent: 'shortcuts' },
  },
];

export function commandsForWorkspace(hasWorkspace: boolean): readonly PaletteCommand[] {
  return hasWorkspace
    ? PALETTE_COMMANDS
    : PALETTE_COMMANDS.filter((command) => command.action.type !== 'people-workflow');
}

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
          action: { type: 'person', intent: 'inspect', personId: person.id },
        },
      ];
      if (liveSession) {
        commands.push({
          id: `people:session:${person.id}`,
          group: 'People',
          title: `Open ${person.name}'s terminal`,
          hint: `${person.role} · live PTY${liveSession.projectId ? ` · ${liveSession.projectId}` : ''}`,
          keywords: [...commonKeywords, 'terminal', 'session', 'running', liveSession.projectId ?? ''],
          action: { type: 'person', intent: 'session', personId: person.id },
        });
      } else if (!person.archived) {
        commands.push({
          id: `people:start:${person.id}`,
          group: 'People',
          title: `Start ${person.name}`,
          hint: `${person.role} · review project and runner`,
          keywords: [...commonKeywords, 'start', 'run', 'collaborator'],
          action: { type: 'person', intent: 'start', personId: person.id },
        });
      }
      return commands;
    });
}

export function loopScheduleCommands(loops: readonly Pick<LoopInfo, 'name' | 'cadence'>[]): PaletteCommand[] {
  return [...loops]
    .sort((a, b) => a.name.localeCompare(b.name))
    .map((loop) => ({
      id: `loop:schedule:${loop.name}`,
      group: 'Loops',
      title: `Manage ${loop.name} schedule`,
      hint: `${loop.cadence} · review install or disable`,
      keywords: ['schedule', 'timer', 'launchd', 'systemd', 'loop', loop.name],
      action: { type: 'loop-schedule', name: loop.name },
    }));
}

const ACTIONABLE_SWARM_STATES = new Set([
  'paused',
  'budget_exhausted',
  'failed',
  'awaiting_human',
  'awaiting_plan_approval',
]);

export function recoverableSwarmCommands(
  runs: readonly Pick<SwarmRunInfo, 'run_id' | 'task' | 'run_state' | 'recipe'>[],
) {
  return runs
    .filter((run) => ACTIONABLE_SWARM_STATES.has(run.run_state))
    .map((run) => ({
      id: `swarm:inspect:${run.run_id}`,
      group: 'Swarms' as const,
      title: `Review ${run.run_state} swarm`,
      hint: `${run.task || run.recipe || 'Swarm run'} · ${run.run_id}`,
      keywords: [
        'recover',
        'resume',
        'failed',
        'paused',
        'budget',
        ...(run.run_state === 'awaiting_human' || run.run_state === 'awaiting_plan_approval'
          ? ['approve', 'approval', 'human', 'plan', 'gate']
          : []),
        run.task,
        run.recipe,
        run.run_id,
      ],
      action: { type: 'swarm-run' as const, runId: run.run_id },
    }));
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
