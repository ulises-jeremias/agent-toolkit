import { describe, expect, it } from 'vitest';
import { filterCommands, PALETTE_COMMANDS } from './commands';

describe('filterCommands', () => {
  it('returns every command when the query is empty', () => {
    expect(filterCommands(PALETTE_COMMANDS, '')).toHaveLength(PALETTE_COMMANDS.length);
  });

  it('matches destination names and questions', () => {
    const hits = filterCommands(PALETTE_COMMANDS, 'world');
    expect(hits.map((command) => command.id)).toContain('go:/world');
  });

  it('matches keywords for the terminal dock', () => {
    const hits = filterCommands(PALETTE_COMMANDS, 'pty');
    expect(hits.map((command) => command.id)).toEqual(['go:world-terminal', 'session:new-terminal']);
  });
});
