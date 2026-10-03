/**
 * Command-palette jumps that focus a semantic world place.
 * Pure helpers — CommandPalette and tests share the same map.
 */

export interface WorldJump {
  /** Destination path (without session query). */
  path: string;
  /** Extra query — place focuses a grounds entity; project opens an interior. */
  extra?: Record<string, string | undefined>;
  /** Stable entity id selected on /world when path is the world. */
  focusEntityId?: string;
}

const WORLD_JUMPS: Readonly<Record<string, WorldJump>> = {
  'world-memory': {
    path: '/world',
    extra: { place: 'place:memory' },
    focusEntityId: 'place:memory',
  },
  'world-terminal': {
    path: '/world',
    extra: { place: 'object:terminal' },
    focusEntityId: 'object:terminal',
  },
  'world-attention': {
    path: '/world',
    extra: { place: 'object:attention' },
    focusEntityId: 'object:attention',
  },
  'world-projects': {
    path: '/world',
    extra: { place: 'projects', project: undefined },
    focusEntityId: undefined,
  },
};

/** Resolve a `go:` target (slice after `go:`) into a world/inspector jump. */
export function resolveWorldJump(goTarget: string): WorldJump | null {
  if (goTarget.startsWith('world-project:')) {
    const name = goTarget.slice('world-project:'.length).trim();
    if (!name) return null;
    return {
      path: '/world',
      extra: { project: name, place: undefined },
      focusEntityId: `place:project:${name}`,
    };
  }
  return WORLD_JUMPS[goTarget] ?? null;
}

export function resolveProjectWorldJump(projectName: string): WorldJump | null {
  const name = projectName.trim();
  if (!name) return null;
  return {
    path: '/world',
    extra: { project: name, place: undefined },
    focusEntityId: `place:project:${name}`,
  };
}

/** Dynamic palette rows for real project houses (never invent names). */
export function projectWorldCommands(projectNames: readonly string[]): ReadonlyArray<{
  id: string;
  group: 'Go';
  title: string;
  hint: string;
  keywords: readonly string[];
  action: { type: 'world-project'; projectName: string };
}> {
  return [...projectNames]
    .filter(Boolean)
    .sort((a, b) => a.localeCompare(b))
    .map((name) => ({
      id: `go:world-project:${name}`,
      group: 'Go' as const,
      title: `Open project ${name}`,
      hint: 'Enter the project house on the world',
      keywords: ['project', 'house', 'world', name],
      action: { type: 'world-project' as const, projectName: name },
    }));
}
