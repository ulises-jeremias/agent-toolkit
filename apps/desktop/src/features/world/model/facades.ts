/**
 * Visual façade ids for the cozy theme pack. Façades are theme-layer only —
 * they never invent domain state. Project houses pick a stable variant from
 * the project name so the district is scannable without fake metadata.
 */

export const PROJECT_FACADES = [
  'house-cottage',
  'house-studio',
  'house-workshop',
  'house-tower',
  'house-cabin',
  'house-brick',
] as const;

export type ProjectFacade = (typeof PROJECT_FACADES)[number];

export type LandmarkFacade =
  | 'landmark-workspace'
  | 'landmark-archive'
  | 'landmark-library'
  | 'landmark-files'
  | 'landmark-operations'
  | 'landmark-settings'
  | 'landmark-terminal'
  | 'landmark-attention';

export type BuildingFacade = ProjectFacade | LandmarkFacade;

function facadeIndex(name: string): number {
  let hash = 2166136261;
  for (let i = 0; i < name.length; i += 1) {
    hash ^= name.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0) % PROJECT_FACADES.length;
}

/** Deterministic, stable across sessions — same name → same house silhouette. */
export function projectFacade(name: string): ProjectFacade {
  return PROJECT_FACADES[facadeIndex(name)]!;
}

/** Assign unique nearby silhouettes before repeating one in a project valley. */
export function projectFacades(names: readonly string[]): ReadonlyMap<string, ProjectFacade> {
  const assigned = new Map<string, ProjectFacade>();
  const used = new Set<ProjectFacade>();
  for (const name of [...new Set(names)].sort((left, right) => (left < right ? -1 : left > right ? 1 : 0))) {
    const first = facadeIndex(name);
    let selected: ProjectFacade | undefined;
    for (let offset = 0; offset < PROJECT_FACADES.length; offset += 1) {
      const candidate = PROJECT_FACADES[(first + offset) % PROJECT_FACADES.length]!;
      if (!used.has(candidate)) {
        selected = candidate;
        break;
      }
    }
    const facade = selected ?? projectFacade(name);
    assigned.set(name, facade);
    used.add(facade);
  }
  return assigned;
}
