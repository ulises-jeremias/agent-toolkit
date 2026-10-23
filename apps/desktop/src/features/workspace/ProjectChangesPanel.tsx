import { useEffect, useState } from 'react';
import {
  useProjectGitCommit,
  useProjectGitDiff,
  useProjectGitStage,
  useProjectGitStageHunk,
  useProjectGitStatus,
  useProjectGitUnstage,
} from '../../data/projects';
import { errorMessage } from '../../lib/api';
import type { GitFileChange } from '../../lib/api';
import { Button, ButtonRow, EmptyState, ErrorState, Field, LoadingState, Panel, StatusBadge, TextArea } from '../../ui';
import { diffLineTone, isClean, splitDiffHunks } from './projectGit';
import styles from './changes.module.css';

type Selection = { path: string; staged: boolean } | null;

/**
 * Project Changes — real git working-tree review for one registered
 * project: staged / changed / untracked groups, per-file diff, stage,
 * unstage, and commit. All operations go through the typed backend git
 * routes; nothing here shells out or invents state.
 */
export function ProjectChangesPanel({
  workspace,
  projects,
}: {
  workspace: string;
  projects: { name: string; status: string }[];
}) {
  const linked = projects.filter((project) => project.status === 'ok');
  const [project, setProject] = useState('');
  const active = linked.some((entry) => entry.name === project) ? project : (linked[0]?.name ?? '');
  const [selection, setSelection] = useState<Selection>(null);
  const [message, setMessage] = useState('');
  const [receipt, setReceipt] = useState('');
  const [actionError, setActionError] = useState('');

  const status = useProjectGitStatus(workspace, active);
  const diff = useProjectGitDiff(workspace, active, selection?.path ?? '', selection?.staged ?? false);
  const stage = useProjectGitStage(workspace, active);
  const unstage = useProjectGitUnstage(workspace, active);
  const commit = useProjectGitCommit(workspace, active);
  const stageHunk = useProjectGitStageHunk(workspace, active);
  const busy = stage.isPending || unstage.isPending || commit.isPending || stageHunk.isPending;

  useEffect(() => {
    setSelection(null);
    setReceipt('');
    setActionError('');
  }, [active]);

  if (linked.length === 0) return null;

  const data = status.data;
  const runAction = (fn: () => Promise<{ ok: boolean; detail: string }>, done?: string) => {
    setActionError('');
    fn()
      .then((res) => {
        if (!res.ok) {
          setActionError(res.detail || 'The git operation failed.');
          return;
        }
        if (done) {
          setReceipt(done);
          setMessage('');
        }
      })
      .catch((err: unknown) => setActionError(errorMessage(err)));
  };

  const renderGroup = (
    title: string,
    files: GitFileChange[],
    stagedGroup: boolean,
    actionLabel: string,
    onAction: (path: string) => void,
  ) => (
    <div>
      <h3 className={styles.groupTitle}>
        {title} ({files.length})
      </h3>
      {files.length === 0 ? (
        <p className={styles.groupEmpty}>None.</p>
      ) : (
        <ul className={styles.fileList} aria-label={`${title} files`}>
          {files.map((file) => {
            const selected = selection?.path === file.path && selection?.staged === stagedGroup;
            return (
              <li key={`${stagedGroup ? 's' : 'u'}:${file.path}`} className={styles.fileRow}>
                <button
                  type="button"
                  className={selected ? `${styles.fileButton} ${styles.selected}` : styles.fileButton}
                  aria-current={selected ? 'true' : undefined}
                  onClick={() => setSelection({ path: file.path, staged: stagedGroup })}
                >
                  <StatusBadge tone={stagedGroup ? 'ok' : 'warn'} label={file.code} />
                  <span>{file.path}</span>
                </button>
                <Button variant="ghost" disabled={busy} onClick={() => onAction(file.path)}>
                  {actionLabel}
                </Button>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );

  return (
    <Panel title="Changes" meta={data?.branch ? `branch ${data.branch}` : 'Review and commit real repository changes'}>
      <div className={styles.toolbar}>
        <Field label="Project">
          {(control) => (
            <select
              {...control}
              value={active}
              onChange={(event) => setProject(event.target.value)}
              aria-label="Changes project"
            >
              {linked.map((entry) => (
                <option key={entry.name} value={entry.name}>
                  {entry.name}
                </option>
              ))}
            </select>
          )}
        </Field>
      </div>

      {status.isPending ? <LoadingState label="Reading working tree" /> : null}
      {status.isError ? (
        <ErrorState title="Could not read changes" error={status.error} onRetry={() => void status.refetch()} />
      ) : null}
      {data && !data.ok ? (
        <p role="alert">Could not read changes: {data.detail || 'the project is not a git repository.'}</p>
      ) : null}
      {actionError ? <p role="alert">{actionError}</p> : null}
      {receipt ? <p role="status">{receipt}</p> : null}

      {data?.ok ? (
        <>
          {isClean(data) ? (
            <EmptyState title="Working tree clean.">Nothing staged, changed, or untracked in {active}.</EmptyState>
          ) : (
            <div className={styles.split}>
              <div className={styles.groups}>
                {renderGroup('Staged', data.staged, true, 'Unstage', (path) =>
                  runAction(() => unstage.mutateAsync([path])),
                )}
                {renderGroup('Changed', data.unstaged, false, 'Stage', (path) =>
                  runAction(() => stage.mutateAsync([path])),
                )}
                {renderGroup('Untracked', data.untracked, false, 'Stage', (path) =>
                  runAction(() => stage.mutateAsync([path])),
                )}
              </div>
              <div className={styles.diffPane} aria-live="polite">
                {!selection ? (
                  <EmptyState title="Select a file.">Choose a changed file to inspect its diff.</EmptyState>
                ) : diff.isPending ? (
                  <LoadingState label={`Reading diff for ${selection.path}`} />
                ) : diff.isError ? (
                  <ErrorState title="Could not read diff" error={diff.error} onRetry={() => void diff.refetch()} />
                ) : diff.data && !diff.data.ok ? (
                  <p role="alert">{diff.data.detail || 'Could not read this diff.'}</p>
                ) : diff.data ? (
                  <>
                    <p className={styles.diffMeta}>
                      <strong>{selection.path}</strong>
                      <StatusBadge
                        tone={selection.staged ? 'ok' : 'warn'}
                        label={selection.staged ? 'staged' : 'changed'}
                      />
                      {diff.data.truncated ? <StatusBadge tone="warn" label="truncated" /> : null}
                    </p>
                    {diff.data.diff ? (
                      <div aria-label={`Diff for ${selection.path}`}>
                        {splitDiffHunks(diff.data.diff).map((hunk, hunkIndex) => (
                          <div key={hunkIndex} className={styles.hunk}>
                            <p className={styles.hunkBar}>
                              <span className={styles[diffLineTone(hunk.header)]}>{hunk.header}</span>
                              <Button
                                variant="ghost"
                                disabled={busy}
                                onClick={() =>
                                  runAction(() =>
                                    stageHunk.mutateAsync({
                                      path: selection.path,
                                      staged: selection.staged,
                                      hunk: hunkIndex,
                                    }),
                                  )
                                }
                              >
                                {selection.staged ? `Unstage hunk ${hunkIndex + 1}` : `Stage hunk ${hunkIndex + 1}`}
                              </Button>
                            </p>
                            <pre className={styles.diff}>
                              {hunk.lines.map((line, index) => (
                                <span key={index} className={styles[diffLineTone(line)]}>
                                  {line}
                                  {'\n'}
                                </span>
                              ))}
                            </pre>
                          </div>
                        ))}
                      </div>
                    ) : (
                      <EmptyState title="No textual diff.">
                        This file may be new, binary, or unchanged in the selected view.
                      </EmptyState>
                    )}
                  </>
                ) : null}
              </div>
            </div>
          )}

          <div className={styles.commitBox}>
            <Field label="Commit message">
              {(control) => (
                <TextArea
                  {...control}
                  value={message}
                  onChange={(event) => setMessage(event.target.value)}
                  placeholder="Describe the staged change"
                  aria-label="Commit message"
                  rows={2}
                />
              )}
            </Field>
            <ButtonRow>
              <Button
                disabled={busy || data.staged.length === 0 || message.trim().length === 0}
                onClick={() => runAction(() => commit.mutateAsync(message.trim()), 'Committed staged changes.')}
              >
                Commit staged ({data.staged.length})
              </Button>
            </ButtonRow>
            {data.staged.length === 0 ? <p className={styles.groupEmpty}>Stage at least one file to commit.</p> : null}
          </div>
        </>
      ) : null}
    </Panel>
  );
}
