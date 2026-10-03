import { describe, expect, it } from 'vitest';
import {
  filterCommands,
  commandsForWorkspace,
  loopScheduleCommands,
  mcpProviderCommands,
  PALETTE_COMMANDS,
  personCommands,
  recoverableSwarmCommands,
} from './commands';

describe('filterCommands', () => {
  it('returns every command when the query is empty', () => {
    expect(filterCommands(PALETTE_COMMANDS, '')).toHaveLength(PALETTE_COMMANDS.length);
  });

  it('matches destination names and questions', () => {
    const world = filterCommands(PALETTE_COMMANDS, 'world');
    expect(world.map((command) => command.id)).toContain('go:/world');
    const officeHits = filterCommands(PALETTE_COMMANDS, 'office');
    expect(officeHits.map((command) => command.id)).toContain('go:/office');
    const office = PALETTE_COMMANDS.find((command) => command.id === 'go:/office');
    expect(office?.hint).toBe('What needs attention now?');
  });

  it('matches keywords for the terminal dock and world terminal place', () => {
    const hits = filterCommands(PALETTE_COMMANDS, 'pty');
    expect(hits.map((command) => command.id)).toEqual(
      expect.arrayContaining(['go:world-terminal', 'session:new-terminal']),
    );
  });

  it('finds the terminal as a workstation place', () => {
    const hits = filterCommands(PALETTE_COMMANDS, 'workstation');
    expect(hits.map((command) => command.id)).toEqual(expect.arrayContaining(['go:/terminal', 'session:new-terminal']));
  });

  it('lists Next that needs me as a session command', () => {
    expect(PALETTE_COMMANDS.map((command) => command.id)).toContain('session:next-needs-me');
    const hits = filterCommands(PALETTE_COMMANDS, 'needs me');
    expect(hits.map((command) => command.id)).toContain('session:next-needs-me');
  });

  it('reaches the swarm start flow and uses the current world theme names', () => {
    expect(filterCommands(PALETTE_COMMANDS, 'start a swarm').map((command) => command.id)).toContain(
      'session:start-swarm',
    );
    expect(PALETTE_COMMANDS.find((command) => command.id === 'appearance:meadow')?.title).toBe('Use Meadow theme');
    expect(PALETTE_COMMANDS.find((command) => command.id === 'appearance:dusk')?.title).toBe('Use Dusk theme');
    expect(PALETTE_COMMANDS.some((command) => /Paper|\bInk\b/.test(command.title))).toBe(false);
  });

  it('binds universal commands to typed canonical actions rather than parsing command ids', () => {
    expect(PALETTE_COMMANDS.find((command) => command.id === 'go:/operations')?.action).toEqual({
      type: 'navigate',
      path: '/operations',
    });
    expect(PALETTE_COMMANDS.find((command) => command.id === 'session:start-swarm')?.action).toEqual({
      type: 'session',
      intent: 'start-swarm',
    });
    expect(PALETTE_COMMANDS.find((command) => command.id === 'session:restart-backend')?.action).toEqual({
      type: 'session',
      intent: 'restart-backend',
    });
    expect(PALETTE_COMMANDS.find((command) => command.id === 'go:switch-workspace')?.action).toEqual({
      type: 'workspace-switch',
    });
  });

  it('exposes world jumps for memory, projects, terminal, and attention', () => {
    const ids = PALETTE_COMMANDS.map((command) => command.id);
    expect(ids).toEqual(
      expect.arrayContaining(['go:world-memory', 'go:world-projects', 'go:world-terminal', 'go:world-attention']),
    );
    expect(filterCommands(PALETTE_COMMANDS, 'memory archive').map((c) => c.id)).toContain('go:world-memory');
    expect(filterCommands(PALETTE_COMMANDS, 'project houses').map((c) => c.id)).toContain('go:world-projects');
    expect(filterCommands(PALETTE_COMMANDS, 'needs you').map((c) => c.id)).toContain('go:world-attention');
  });

  it('offers truthful People actions and hides Start for archived or live collaborators', () => {
    const commands = personCommands(
      [
        { id: 'lina', name: 'Lina', role: 'reviewer', archived: false },
        { id: 'maya', name: 'Maya', role: 'architect', archived: true },
        { id: 'alex', name: 'Alex', role: 'implementer', archived: false },
      ],
      [{ personId: 'alex', projectId: 'agent-toolkit', exitCode: null }],
    );
    expect(commands.map((command) => command.title)).toEqual([
      'Inspect Alex',
      "Open Alex's terminal",
      'Inspect Lina',
      'Start Lina',
      'Inspect Maya',
    ]);
    expect(filterCommands(commands, 'Start Lina').map((command) => command.id)).toEqual(['people:start:lina']);
    expect(filterCommands(commands, 'terminal agent-toolkit').map((command) => command.id)).toEqual([
      'people:session:alex',
    ]);
    expect(commands.find((command) => command.id === 'people:start:lina')?.action).toEqual({
      type: 'person',
      intent: 'start',
      personId: 'lina',
    });
  });

  it('offers direct People workflows and only real loop schedules and recoverable swarm runs', () => {
    const staticIds = PALETTE_COMMANDS.map((command) => command.id);
    expect(staticIds).toEqual(expect.arrayContaining(['people:create', 'people:import-munder']));
    expect(PALETTE_COMMANDS.find((command) => command.id === 'people:import-munder')?.action).toEqual({
      type: 'people-workflow',
      intent: 'import',
    });

    const loops = loopScheduleCommands([{ name: 'daily-triage', cadence: 'daily' }]);
    expect(filterCommands(loops, 'schedule daily triage').map((command) => command.id)).toEqual([
      'loop:schedule:daily-triage',
    ]);
    expect(loops[0]?.action).toEqual({ type: 'loop-schedule', name: 'daily-triage' });

    const swarms = recoverableSwarmCommands([
      { run_id: 'paused-run', task: 'Review change', recipe: 'pair', run_state: 'paused' },
      { run_id: 'budget-run', task: 'Check budget', recipe: 'pair', run_state: 'budget_exhausted' },
      { run_id: 'failed-run', task: 'Retry failure', recipe: 'pair', run_state: 'failed' },
      { run_id: 'approval-run', task: 'Approve plan', recipe: 'pair', run_state: 'awaiting_plan_approval' },
      { run_id: 'human-run', task: 'Review handoff', recipe: 'pair', run_state: 'awaiting_human' },
      { run_id: 'done-run', task: 'Finished task', recipe: 'pair', run_state: 'completed' },
    ]);
    expect(swarms.map((command) => command.id)).toEqual([
      'swarm:inspect:paused-run',
      'swarm:inspect:budget-run',
      'swarm:inspect:failed-run',
      'swarm:inspect:approval-run',
      'swarm:inspect:human-run',
    ]);
    expect(swarms[0]?.action).toEqual({ type: 'swarm-run', runId: 'paused-run' });
    expect(filterCommands(swarms, 'approve plan').map((command) => command.id)).toEqual([
      'swarm:inspect:approval-run',
      'swarm:inspect:human-run',
    ]);
  });

  it('creates direct MCP provider actions from the live catalog and routes them to review', () => {
    const providers = mcpProviderCommands([
      {
        id: 'github',
        display_name: 'GitHub',
        package: 'ghcr.io/github/github-mcp-server',
        required_env: ['GITHUB_PERSONAL_ACCESS_TOKEN'],
      },
    ]);
    expect(filterCommands(providers, 'configure github mcp').map((command) => command.id)).toEqual([
      'library:mcp:github',
    ]);
    expect(filterCommands(providers, 'GITHUB_PERSONAL_ACCESS_TOKEN').map((command) => command.id)).toEqual([
      'library:mcp:github',
    ]);
    expect(providers[0]?.action).toEqual({ type: 'mcp-provider', providerId: 'github' });
    expect(PALETTE_COMMANDS.find((command) => command.id === 'library:review-installation')?.action).toEqual({
      type: 'library-workflow',
      intent: 'review-installation',
    });
  });

  it('hides People create and import commands until a workspace exists', () => {
    expect(commandsForWorkspace(false).map((command) => command.id)).not.toEqual(
      expect.arrayContaining(['people:create', 'people:import-munder']),
    );
    expect(commandsForWorkspace(true).map((command) => command.id)).toEqual(
      expect.arrayContaining(['people:create', 'people:import-munder']),
    );
  });
});
