import { useMemo, useState } from 'react';
import { useWorkspaceFile, useWorkspaceFileSearch, useWorkspaceFiles } from '../../data/files';
import { EmptyState, ErrorState, Field, LoadingState, Mono, Panel, Stack, StatusBadge, TextInput } from '../../ui';
import styles from './files.module.css';

/**
 * Workspace files browser — GET /api/v1/files (+ content / hits).
 * Real backend tree only; masked/binary nodes stay honest.
 */
export function FilesPanel({ project }: { project?: string }) {
  const [dir, setDir] = useState('');
  const [selected, setSelected] = useState('');
  const [query, setQuery] = useState('');
  const tree = useWorkspaceFiles({ path: dir || undefined, depth: 2, project });
  const file = useWorkspaceFile(selected, { project, enabled: selected.length > 0 });
  const search = useWorkspaceFileSearch(query, { project, enabled: query.trim().length > 0 });

  const nodes = useMemo(() => tree.data?.nodes ?? [], [tree.data?.nodes]);
  const dirs = nodes.filter((node) => node.kind === 'dir');
  const files = nodes.filter((node) => node.kind === 'file');

  return (
    <Stack>
      <Panel
        tone="notice"
        title={project ? `${project} files` : 'Files'}
        meta={
          tree.data?.root ? `root ${tree.data.root}` : project ? `registered project ${project}` : 'GET /api/v1/files'
        }
      >
        <p className={styles.lede}>
          {project
            ? 'Files are read from this workspace-registered project link. Secret names stay masked; binary files are marked without inventing text.'
            : 'Workspace-contained tree from the serve files API. Secret names stay masked; binary files are marked without inventing text.'}
        </p>
        <div className={styles.toolbar}>
          <Field label="Directory">
            {(control) => (
              <TextInput
                {...control}
                value={dir}
                onChange={(event) => setDir(event.target.value)}
                placeholder="(workspace root)"
                aria-label="Files directory path"
              />
            )}
          </Field>
          <Field label="Search">
            {(control) => (
              <TextInput
                {...control}
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="filename or line text"
                aria-label="Search workspace files"
              />
            )}
          </Field>
        </div>
        {tree.isPending ? <LoadingState label="Listing workspace files" /> : null}
        {tree.isError ? (
          <ErrorState title="Could not list files" error={tree.error} onRetry={() => void tree.refetch()} />
        ) : null}
        {tree.isSuccess && nodes.length === 0 ? (
          <EmptyState title="No files here.">This path is empty or unavailable inside the selected root.</EmptyState>
        ) : null}
        {tree.isSuccess && nodes.length > 0 ? (
          <div className={styles.split}>
            <ul className={styles.tree} aria-label="Workspace file tree">
              {dir ? (
                <li>
                  <button
                    type="button"
                    className={styles.row}
                    onClick={() => {
                      const parent = dir.replace(/\/+$/, '').split('/').slice(0, -1).join('/');
                      setDir(parent);
                      setSelected('');
                    }}
                  >
                    ↑ Parent
                  </button>
                </li>
              ) : null}
              {dirs.map((node) => (
                <li key={`d:${node.path}`}>
                  <button
                    type="button"
                    className={styles.row}
                    onClick={() => {
                      setDir(node.path);
                      setSelected('');
                    }}
                  >
                    <StatusBadge tone="idle" label="dir" />
                    <span>{node.name || node.path}</span>
                    <Mono>d{node.depth}</Mono>
                  </button>
                </li>
              ))}
              {files.map((node) => (
                <li key={`f:${node.path}`}>
                  <button
                    type="button"
                    className={node.path === selected ? `${styles.row} ${styles.selected}` : styles.row}
                    aria-current={node.path === selected ? 'true' : undefined}
                    onClick={() => setSelected(node.path)}
                  >
                    <StatusBadge tone="idle" label="file" />
                    <span>{node.name || node.path}</span>
                    {node.masked ? <StatusBadge tone="warn" label="masked" /> : null}
                    <Mono>{node.size} B</Mono>
                  </button>
                </li>
              ))}
            </ul>
            <div className={styles.preview} aria-live="polite">
              {!selected ? (
                <EmptyState title="Select a file.">Choose a file from the tree to read its contents.</EmptyState>
              ) : file.isPending ? (
                <LoadingState label={`Reading ${selected}`} />
              ) : file.isError ? (
                <ErrorState title="Could not read file" error={file.error} onRetry={() => void file.refetch()} />
              ) : file.data ? (
                <>
                  <p className={styles.meta}>
                    <strong>{file.data.name || file.data.path}</strong>
                    {file.data.binary ? <StatusBadge tone="warn" label="binary" /> : null}
                    {file.data.truncated ? <StatusBadge tone="warn" label="truncated" /> : null}
                    {file.data.masked ? <StatusBadge tone="warn" label="masked" /> : null}
                    <Mono>{file.data.size} B</Mono>
                  </p>
                  {file.data.binary || file.data.masked ? (
                    <EmptyState title="Contents not shown.">
                      {file.data.masked
                        ? 'This path looks secret and is masked by the files API.'
                        : 'Binary files return no text content.'}
                    </EmptyState>
                  ) : (
                    <pre className={styles.content}>{file.data.content || '(empty file)'}</pre>
                  )}
                </>
              ) : null}
            </div>
          </div>
        ) : null}
      </Panel>

      {query.trim() ? (
        <Panel title="Search hits" meta={`q=${query.trim()}`}>
          {search.isPending ? <LoadingState label="Searching files" /> : null}
          {search.isError ? (
            <ErrorState title="Could not search files" error={search.error} onRetry={() => void search.refetch()} />
          ) : null}
          {search.isSuccess && search.data.hits.length === 0 ? (
            <EmptyState title="No hits.">Nothing matched that query in workspace files.</EmptyState>
          ) : null}
          {search.isSuccess && search.data.hits.length > 0 ? (
            <ul className={styles.hits} aria-label="File search hits">
              {search.data.hits.map((hit) => (
                <li key={`${hit.path}:${hit.line}`}>
                  <button type="button" className={styles.row} onClick={() => setSelected(hit.path)}>
                    <Mono>
                      {hit.path}:{hit.line}
                    </Mono>
                    <span>{hit.snippet}</span>
                  </button>
                </li>
              ))}
            </ul>
          ) : null}
        </Panel>
      ) : null}
    </Stack>
  );
}
