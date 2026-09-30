import { describe, expect, it } from 'vitest';
import { filterCommands, PALETTE_COMMANDS } from './commands';

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

  it('exposes world jumps for memory, projects, terminal, and attention', () => {
    const ids = PALETTE_COMMANDS.map((command) => command.id);
    expect(ids).toEqual(
      expect.arrayContaining(['go:world-memory', 'go:world-projects', 'go:world-terminal', 'go:world-attention']),
    );
    expect(filterCommands(PALETTE_COMMANDS, 'memory archive').map((c) => c.id)).toContain('go:world-memory');
    expect(filterCommands(PALETTE_COMMANDS, 'project houses').map((c) => c.id)).toContain('go:world-projects');
    expect(filterCommands(PALETTE_COMMANDS, 'needs you').map((c) => c.id)).toContain('go:world-attention');
  });
});
