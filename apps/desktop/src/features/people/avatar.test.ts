import { describe, expect, it } from 'vitest';
import type { Person } from '../../lib/api';
import { personCharacter, personCharacterSprite } from './avatar';

const lina: Person = {
  spec: 'agent-toolkit/person@1',
  id: 'lina',
  name: 'Lina',
  role: 'reviewer',
  goal: 'Review changes',
  archived: false,
};

describe('Person character identity', () => {
  it('uses a configured appearance and keeps the default deterministic', () => {
    expect(personCharacter({ ...lina, avatar: { character: 'keeper' } })).toBe('keeper');
    expect(personCharacter(lina)).toBe(personCharacter(lina));
    expect(personCharacterSprite(lina)).toBe(`char-${personCharacter(lina)}`);
  });
});
