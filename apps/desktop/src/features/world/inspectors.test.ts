import { describe, expect, it } from 'vitest';
import { entityActivateVerb } from './inspectors';

describe('world interaction labels', () => {
  it('names the interior door action by its actual destination', () => {
    expect(
      entityActivateVerb({
        id: 'object:exit-grounds',
        hrefPath: '/world',
        name: 'Exit',
        concept: 'Return to workspace grounds',
        themeKey: 'workspace.grounds',
        kind: 'object',
      }),
    ).toBe('Return to workspace grounds');
  });
});
