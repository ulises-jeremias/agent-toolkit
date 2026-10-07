import type { InstallReceiptSummary } from '../../lib/api';

export type LibraryResourceKind = 'skill' | 'agent';
export type LibraryReceiptState = 'none' | 'verified' | 'partial' | 'needs-attention';

export interface LibraryResourceEvidence {
  state: LibraryReceiptState;
  targets: string[];
}

function resourceFromPath(
  path: string | undefined,
): { kind: LibraryResourceKind; name: string; primary: boolean } | null {
  if (typeof path !== 'string') return null;
  const segments = path.replaceAll('\\', '/').split('/').filter(Boolean);
  const filename = segments.at(-1);
  const skillsIndex = segments.lastIndexOf('skills');
  const skillEntry = skillsIndex >= 0 ? segments[skillsIndex + 1] : undefined;
  if (skillEntry && !(skillEntry.endsWith('.md') && segments[skillsIndex - 1] === 'agent')) {
    return {
      kind: 'skill',
      name: skillEntry,
      primary: filename === 'SKILL.md' && segments.length === skillsIndex + 3,
    };
  }

  if (!filename?.endsWith('.md')) return null;
  const parent = segments.at(-2);
  const isAgentDefinition = parent === 'agents' || (parent === 'skills' && segments.at(-3) === 'agent');
  return isAgentDefinition ? { kind: 'agent', name: filename.slice(0, -3), primary: true } : null;
}

/**
 * Match receipt-owned files to a Library catalog resource. Absence means only
 * that Toolkit has no receipt for this resource; it does not claim that the
 * user has not installed or copied it independently.
 */
export function libraryResourceEvidence(
  kind: LibraryResourceKind,
  name: string,
  receipts: readonly InstallReceiptSummary[],
): LibraryResourceEvidence {
  const matched = receipts.flatMap((receipt) => {
    const artifacts = receipt.artifacts.flatMap((artifact) => {
      const resource = resourceFromPath(artifact.path);
      return resource?.kind === kind && resource.name === name ? [{ artifact, primary: resource.primary }] : [];
    });
    return artifacts.length > 0 ? [{ target: receipt.target, artifacts }] : [];
  });

  if (matched.length === 0) return { state: 'none', targets: [] };

  return {
    state: matched.some(({ artifacts }) => artifacts.some(({ artifact }) => artifact.status !== 'unchanged'))
      ? 'needs-attention'
      : kind === 'skill' && matched.some(({ artifacts }) => !artifacts.some(({ primary }) => primary))
        ? 'partial'
        : 'verified',
    targets: [...new Set(matched.map(({ target }) => target))].sort(),
  };
}
