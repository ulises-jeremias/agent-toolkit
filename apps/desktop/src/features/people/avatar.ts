import type { Person } from '../../lib/api';

export const PERSON_CHARACTERS = ['scout', 'maker', 'scholar', 'keeper'] as const;
export type PersonCharacter = (typeof PERSON_CHARACTERS)[number];
export type PersonCharacterSprite = `char-${PersonCharacter}`;

/** The same durable choice is used in the roster portrait and the live world character. */
export function personCharacter(person: Person): PersonCharacter {
  const configured = person.avatar?.character;
  if (PERSON_CHARACTERS.some((choice) => choice === configured)) return configured as PersonCharacter;
  let hash = 2166136261;
  for (const letter of person.id) hash = Math.imul(hash ^ letter.charCodeAt(0), 16777619);
  return PERSON_CHARACTERS[(hash >>> 0) % PERSON_CHARACTERS.length]!;
}

export function personCharacterSprite(person: Person): PersonCharacterSprite {
  return `char-${personCharacter(person)}`;
}
