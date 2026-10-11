import { errorMessage, recoveryHint } from '../../lib/api';
import { useActivateWorkspacePack, useWorkspacePacks } from '../../data/workspacePacks';
import { Button, Panel, StatusBadge } from '../../ui';
import styles from './workspace.module.css';

export function WorkspacePacksPanel({ workspace }: { workspace: string }) {
  const packs = useWorkspacePacks(workspace);
  const activate = useActivateWorkspacePack(workspace);

  return (
    <Panel
      title="Workspace context packs"
      meta="Optional context for future sessions"
      actions={packs.data?.active_pack ? <StatusBadge tone="ok" label="Context selected" /> : null}
    >
      <p className={styles.packIntro}>
        These workspace bundles add shared project context when a new session starts. They are separate from reusable
        Library capabilities; choosing one does not install or run anything.
      </p>
      {packs.isPending ? <p role="status">Reading workspace context packs…</p> : null}
      {packs.isError ? (
        <p role="alert">
          Could not read workspace context packs: {errorMessage(packs.error)} {recoveryHint(packs.error)}
        </p>
      ) : null}
      {packs.data?.marker_issue ? (
        <p className={styles.packError} role="alert">
          {packs.data.marker_issue}
        </p>
      ) : null}
      {packs.isSuccess && packs.data.packs.length === 0 ? (
        <p className={styles.packEmpty}>
          No context packs are defined in this workspace. The rest of the workspace works normally.
        </p>
      ) : null}
      {packs.data?.packs.length ? (
        <ul className={styles.packList} aria-label="Workspace context packs">
          {packs.data.packs.map((pack) => (
            <li
              key={pack.path}
              className={pack.active ? `${styles.packCard} ${styles.packCardActive}` : styles.packCard}
            >
              <div className={styles.packHeading}>
                <div>
                  <strong>{pack.name}</strong>
                  <code>{pack.path}</code>
                </div>
                {pack.active ? <StatusBadge tone="ok" label="Used for future sessions" /> : null}
              </div>
              <p>{pack.description || 'No description provided.'}</p>
              {pack.projects.length ? (
                <p className={styles.packProjects}>
                  Projects: <span>{pack.projects.join(', ')}</span>
                </p>
              ) : null}
              {pack.validation_errors.map((error) => (
                <p className={styles.packError} key={error} role="alert">
                  {error}
                </p>
              ))}
              <div className={styles.packActions}>
                <Button
                  disabled={Boolean(pack.validation_errors.length) || pack.active || activate.isPending}
                  onClick={() => activate.mutate(pack.path)}
                >
                  Use for future sessions
                </Button>
              </div>
            </li>
          ))}
        </ul>
      ) : null}
      {packs.data?.active_pack && !packs.data.packs.some((pack) => pack.path === packs.data?.active_pack) ? (
        <p className={styles.packError} role="status">
          The selected pack is no longer available. Clear it so new sessions do not inherit a missing context file.
        </p>
      ) : null}
      {packs.data?.active_pack || packs.data?.marker_issue ? (
        <div className={styles.packActions}>
          <Button disabled={activate.isPending} onClick={() => activate.mutate('')}>
            Clear selected context
          </Button>
        </div>
      ) : null}
      {activate.isError ? (
        <p role="alert">
          Could not update the selected context: {errorMessage(activate.error)} {recoveryHint(activate.error)}
        </p>
      ) : null}
      {activate.data?.message ? <p role="status">{activate.data.message}</p> : null}
    </Panel>
  );
}
