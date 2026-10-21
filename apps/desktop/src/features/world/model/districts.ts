import type { ContextPackRef, WorldDistrict } from './types';

/**
 * District planning — a pure projection of workspace context packs onto the
 * semantic world. Districts group project houses into named neighbourhoods
 * without duplicating project state: every project keeps exactly one lot,
 * in the district of the first pack (input order) that references it, while
 * every referencing pack stays visible in the project's detail. Projects no
 * pack references live in the unfiled district; shared civic places live in
 * the commons. Switching the active pack never moves houses — it only marks
 * which district is active, so running sessions are never disturbed.
 */

export const COMMONS_DISTRICT_ID = 'district:commons';
export const UNFILED_DISTRICT_ID = 'district:unfiled';

export function districtIdForPack(packPath: string): string {
  return `district:pack:${packPath}`;
}

export interface DistrictPlan {
  /** Districts in display order: commons, pack districts, unfiled. */
  districts: WorldDistrict[];
  /** Project name → its single layout district id. */
  byProject: Map<string, string>;
  /** Project name → every pack name referencing it (input order). */
  packNamesByProject: Map<string, string[]>;
}

export function planDistricts(projectNames: readonly string[], packs: readonly ContextPackRef[]): DistrictPlan {
  const known = new Set(projectNames);
  const byProject = new Map<string, string>();
  const packNamesByProject = new Map<string, string[]>();

  for (const pack of packs) {
    for (const project of pack.projects) {
      if (!known.has(project)) continue;
      const names = packNamesByProject.get(project) ?? [];
      names.push(pack.name);
      packNamesByProject.set(project, names);
      if (!byProject.has(project)) {
        byProject.set(project, districtIdForPack(pack.path));
      }
    }
  }

  const districts: WorldDistrict[] = [{ id: COMMONS_DISTRICT_ID, name: 'Civic Commons' }];
  for (const pack of packs) {
    const id = districtIdForPack(pack.path);
    if ([...byProject.values()].includes(id)) {
      districts.push({ id, name: pack.name, packPath: pack.path, active: pack.active === true });
    }
  }
  const unfiled = projectNames.filter((name) => !byProject.has(name));
  for (const name of unfiled) {
    byProject.set(name, UNFILED_DISTRICT_ID);
  }
  if (unfiled.length > 0) {
    districts.push({ id: UNFILED_DISTRICT_ID, name: 'No context pack' });
  }

  return { districts, byProject, packNamesByProject };
}
