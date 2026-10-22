import type { WorkspacePackSummary } from '../../lib/api';

/**
 * Library discovery filter for workspace context bundles. Bundles are
 * workspace context, not installable capabilities; this only decides which
 * of them the Library search shows beside Skills and Agent Definitions.
 */
export function filterContextBundles(packs: readonly WorkspacePackSummary[], needle: string): WorkspacePackSummary[] {
  const normalized = needle.trim().toLocaleLowerCase();
  if (!normalized) return [...packs];
  return packs.filter((pack) =>
    [pack.name, pack.description, pack.path, ...pack.projects].join(' ').toLocaleLowerCase().includes(normalized),
  );
}
