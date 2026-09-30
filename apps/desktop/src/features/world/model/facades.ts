/**
 * Visual façade ids for the cozy theme pack. Façades are theme-layer only —
 * they never invent domain state. Project houses pick a stable variant from
 * the project name so the district is scannable without fake metadata.
 */

export const PROJECT_FACADES = ['house-cottage', 'house-studio', 'house-workshop', 'house-lab'] as const;

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

/** Deterministic, stable across sessions — same name → same house silhouette. */
export function projectFacade(name: string): ProjectFacade {
  let hash = 2166136261;
  for (let i = 0; i < name.length; i += 1) {
    hash ^= name.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  return PROJECT_FACADES[(hash >>> 0) % PROJECT_FACADES.length]!;
}
