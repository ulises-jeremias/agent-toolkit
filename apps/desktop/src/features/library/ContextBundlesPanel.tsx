import { Link } from 'react-router';
import { useWorkspacePacks } from '../../data/workspacePacks';
import { useSessionContext } from '../../shell/useSessionContext';
import { EmptyState, Mono, Panel, QueryView, StatusBadge } from '../../ui';
import { filterContextBundles } from './contextBundles';
import styles from './library.module.css';

/**
 * Read-only discovery of workspace context bundles beside the installable
 * catalog. Bundles are managed in Workspace; this panel never installs,
 * activates, or edits them, and says so in place.
 */
export function ContextBundlesPanel({ workspace, needle }: { workspace: string; needle: string }) {
  const packs = useWorkspacePacks(workspace);
  const { href } = useSessionContext();
  const shown = packs.data ? filterContextBundles(packs.data.packs, needle) : [];
  return (
    <Panel
      title="Workspace context bundles"
      meta={packs.data ? `${packs.data.packs.length} in this workspace` : undefined}
      actions={<Link to={href('/workspace')}>Manage in Workspace</Link>}
    >
      <p className={styles.definitionsNote}>
        Context bundles add shared workspace context to future sessions. They are not installable Library capabilities:
        finding one here installs nothing and changes no running session. Create, edit, or select bundles in Workspace.
      </p>
      {!workspace ? (
        <p role="status">Choose a workspace in Settings before browsing its context bundles.</p>
      ) : (
        <QueryView
          query={packs}
          loading="Reading workspace context bundles"
          errorTitle="Could not read context bundles"
        >
          {(response) =>
            response.packs.length === 0 ? (
              <EmptyState title="No context bundles are defined in this workspace yet.">
                Create one in Workspace when a group of projects needs shared context.
              </EmptyState>
            ) : shown.length === 0 ? (
              <EmptyState title="No context bundles match this search.">
                Try another name, description, or project, or clear the search field.
              </EmptyState>
            ) : (
              <>
                {response.marker_issue ? <p role="alert">{response.marker_issue}</p> : null}
                <ul className={styles.bundleList} aria-label="Workspace context bundles">
                  {shown.map((pack) => (
                    <li key={pack.path} className={styles.bundleCard}>
                      <div className={styles.bundleHeading}>
                        <strong>{pack.name}</strong>
                        {pack.active ? <StatusBadge tone="ok" label="Used for future sessions" /> : null}
                      </div>
                      <p>{pack.description || 'No description provided.'}</p>
                      {pack.projects.length ? (
                        <p>
                          Related projects: <span>{pack.projects.join(', ')}</span>
                        </p>
                      ) : null}
                      {pack.validation_errors.map((error) => (
                        <p key={error} role="alert">
                          {error}
                        </p>
                      ))}
                      <details className={styles.resourceDetails}>
                        <summary>Bundle file</summary>
                        <Mono>{pack.path}</Mono>
                      </details>
                    </li>
                  ))}
                </ul>
              </>
            )
          }
        </QueryView>
      )}
    </Panel>
  );
}
