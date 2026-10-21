import { useEffect, useState, type FormEvent } from 'react';
import { useProjects } from '../../data/projects';
import { useActivateWorkspacePack, useSaveWorkspacePack, useWorkspacePacks } from '../../data/workspacePacks';
import { errorMessage, recoveryHint, type WorkspacePackSummary } from '../../lib/api';
import { Button, ButtonRow, Dialog, Field, Panel, StatusBadge, TextArea, TextInput } from '../../ui';
import styles from './workspace.module.css';

export function WorkspacePacksPanel({ workspace }: { workspace: string }) {
  const packs = useWorkspacePacks(workspace);
  const projects = useProjects(workspace);
  const activate = useActivateWorkspacePack(workspace);
  const save = useSaveWorkspacePack(workspace);
  const [editing, setEditing] = useState<WorkspacePackSummary | null | undefined>(undefined);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [selectedProjects, setSelectedProjects] = useState<string[]>([]);
  const [notes, setNotes] = useState('');
  const isOpen = editing !== undefined;
  const resetSave = save.reset;

  useEffect(() => {
    if (editing === undefined) return;
    setName(editing?.name ?? '');
    setDescription(editing?.description ?? '');
    setSelectedProjects(editing?.projects ?? []);
    setNotes(editing?.notes ?? '');
    resetSave();
  }, [editing, resetSave]);

  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (editing === undefined || save.isPending) return;
    try {
      await save.mutateAsync({
        pack_path: editing?.path ?? '',
        revision: editing?.revision ?? '',
        name,
        description,
        projects: selectedProjects,
        notes,
      });
      setEditing(undefined);
    } catch {
      // Keep the review form open so the user can correct or reload it.
    }
  };

  const toggleProject = (project: string) => {
    setSelectedProjects((selected) =>
      selected.includes(project) ? selected.filter((name) => name !== project) : [...selected, project],
    );
  };

  const reloadLatest = async () => {
    const refreshed = await packs.refetch();
    const latest = refreshed.data?.packs.find((pack) => pack.path === editing?.path);
    if (latest) setEditing(latest);
    else setEditing(undefined);
  };

  return (
    <>
      <Panel
        title="Workspace context packs"
        meta="Optional context for future sessions"
        actions={
          <ButtonRow>
            {packs.data?.active_pack ? <StatusBadge tone="ok" label="Context selected" /> : null}
            <Button
              onClick={() => setEditing(null)}
              disabled={!packs.isSuccess}
              aria-label="Create workspace context pack"
            >
              Create pack
            </Button>
          </ButtonRow>
        }
      >
        <p className={styles.packIntro}>
          These workspace bundles add shared notes when a new session starts. They are separate from reusable Library
          capabilities; saving or selecting one does not install or run anything.
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
            No context packs are defined yet. Create one here when you need shared context.
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
                    <code title={pack.path}>{pack.path}</code>
                  </div>
                  {pack.active ? <StatusBadge tone="ok" label="Used for future sessions" /> : null}
                </div>
                <p>{pack.description || 'No description provided.'}</p>
                {pack.projects.length ? (
                  <p className={styles.packProjects}>
                    Related projects: <span>{pack.projects.join(', ')}</span>
                  </p>
                ) : null}
                {pack.extra_fields.length ? (
                  <p className={styles.packProjects}>
                    Also in this file (kept as-is, not edited here): <span>{pack.extra_fields.join(', ')}</span>
                  </p>
                ) : null}
                {pack.validation_errors.map((error) => (
                  <p className={styles.packError} key={error} role="alert">
                    {error}
                  </p>
                ))}
                <div className={styles.packActions}>
                  <Button variant="ghost" onClick={() => setEditing(pack)} disabled={!pack.revision}>
                    Edit
                  </Button>
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

      <Dialog
        open={isOpen}
        onClose={() => setEditing(undefined)}
        title={editing ? `Edit ${editing.name}` : 'Create a context pack'}
        description="Keep this focused on shared context people need before a session. It will not install capabilities or start agents."
        closeDisabled={save.isPending}
        footer={
          <ButtonRow>
            <Button variant="ghost" onClick={() => setEditing(undefined)} disabled={save.isPending}>
              Cancel
            </Button>
            <Button type="submit" form="workspace-pack-form" busy={save.isPending} busyLabel="Saving…">
              Save pack
            </Button>
          </ButtonRow>
        }
      >
        <form id="workspace-pack-form" onSubmit={(event) => void submit(event)} className={styles.packForm}>
          <Field label="Name" hint="Shown in the workspace roster. Up to 80 characters.">
            {(control) => (
              <TextInput
                {...control}
                value={name}
                onChange={(event) => setName(event.target.value)}
                maxLength={80}
                required
                autoComplete="off"
              />
            )}
          </Field>
          <Field label="Description" hint="A short explanation of when this context is useful.">
            {(control) => (
              <TextInput
                {...control}
                value={description}
                onChange={(event) => setDescription(event.target.value)}
                maxLength={240}
                required
              />
            )}
          </Field>
          <fieldset className={styles.packProjectChoices}>
            <legend>Related projects (reference only)</legend>
            {projects.isPending ? <p role="status">Loading workspace projects…</p> : null}
            {projects.isError ? (
              <p role="alert">Projects could not be loaded. You can still save without selecting any.</p>
            ) : null}
            {projects.data?.projects.length ? (
              projects.data.projects.map((project) => (
                <label key={project.name}>
                  <input
                    type="checkbox"
                    checked={selectedProjects.includes(project.name)}
                    onChange={() => toggleProject(project.name)}
                    disabled={project.status !== 'ok'}
                  />
                  <span>{project.name}</span>
                  {project.status !== 'ok' ? <small>Unavailable</small> : null}
                </label>
              ))
            ) : (
              <p className={styles.packEmpty}>No linked projects yet. You can add project context later.</p>
            )}
          </fieldset>
          <Field label="Shared notes" hint="Plain context for future sessions. Do not add secrets.">
            {(control) => (
              <TextArea
                {...control}
                value={notes}
                onChange={(event) => setNotes(event.target.value)}
                maxLength={8192}
                placeholder="Goals, conventions, useful links, or working agreements…"
              />
            )}
          </Field>
          {save.isError ? (
            <p className={styles.packError} role="alert">
              Could not save the context pack: {errorMessage(save.error)} {recoveryHint(save.error)}
            </p>
          ) : null}
          {save.isError && errorMessage(save.error).includes('changed since it was opened') ? (
            <Button variant="ghost" onClick={() => void reloadLatest()} disabled={packs.isFetching}>
              Discard changes and reload latest
            </Button>
          ) : null}
          {editing?.extra_fields.length ? (
            <p>
              This pack file also defines <strong>{editing.extra_fields.join(', ')}</strong>. Those fields are not
              edited in this form; saving keeps them exactly as they are in the file.
            </p>
          ) : null}
          {editing && !editing.revision ? (
            <p className={styles.packError} role="alert">
              This file cannot be edited because its revision could not be safely verified.
            </p>
          ) : null}
        </form>
      </Dialog>
    </>
  );
}
