import { describe, expect, it } from 'vitest';
import { projectWorldCommands, resolveProjectWorldJump, resolveWorldJump } from './worldJumps';

describe('resolveWorldJump', () => {
  it('focuses memory, terminal, and attention places on /world', () => {
    expect(resolveWorldJump('world-memory')).toEqual({
      path: '/world',
      extra: { place: 'place:memory' },
      focusEntityId: 'place:memory',
    });
    expect(resolveWorldJump('world-terminal')).toEqual({
      path: '/world',
      extra: { place: 'object:terminal' },
      focusEntityId: 'object:terminal',
    });
    expect(resolveWorldJump('world-attention')).toEqual({
      path: '/world',
      extra: { place: 'object:attention' },
      focusEntityId: 'object:attention',
    });
  });

  it('opens a named project interior without inventing houses', () => {
    expect(resolveProjectWorldJump('hornero')).toEqual({
      path: '/world',
      extra: { project: 'hornero', place: undefined },
      focusEntityId: 'place:project:hornero',
    });
    expect(resolveProjectWorldJump('   ')).toBeNull();
  });

  it('returns null for unknown go targets', () => {
    expect(resolveWorldJump('/office')).toBeNull();
    expect(resolveWorldJump('world-unknown')).toBeNull();
  });
});

describe('projectWorldCommands', () => {
  it('builds Go commands only for real project names, sorted', () => {
    const commands = projectWorldCommands(['zebra', 'alpha']);
    expect(commands.map((c) => c.id)).toEqual(['go:world-project:alpha', 'go:world-project:zebra']);
    expect(commands[0]?.title).toBe('Open project alpha');
    expect(commands[0]?.action).toEqual({ type: 'world-project', projectName: 'alpha' });
  });

  it('skips empty names', () => {
    expect(projectWorldCommands(['', 'ok']).map((c) => c.id)).toEqual(['go:world-project:ok']);
  });
});
