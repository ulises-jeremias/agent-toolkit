import { useMemo, useState } from 'react';
import { useBackend } from '../../data/backend';
import { useSubQuery } from '../../data/commands';
import { useMemoryFile, useMemoryList, useMemorySearch } from '../../data/memory';
import type { MemoryEntry } from '../../lib/api';
import { CommandReport, Grid, KeyValue, Panel, QueryView, Stack, StatusBadge, TextInput, type Tone } from '../../ui';
import { WorkspacePacksPanel } from '../workspace/WorkspacePacksPanel';
import styles from './context.module.css';

function riskTone(risk: string | undefined): Tone {
  switch (risk?.toUpperCase()) {
    case 'LOW':
      return 'ok';
    case 'MEDIUM':
      return 'warn';
    case 'HIGH':
      return 'err';
    default:
      return 'idle';
  }
}

const KIND_LABEL: Record<string, string> = {
  learning: 'Learning',
  todo: 'To do',
  process: 'Process',
};

function MemoryPanel() {
  const [query, setQuery] = useState('');
  const [open, setOpen] = useState<string | null>(null);
  const list = useMemoryList();
  const search = useMemorySearch(query);
  const file = useMemoryFile(open ?? '', { enabled: open !== null });
  const entries = useMemo(() => list.data?.entries ?? [], [list.data]);
  const searching = query.trim().length > 0;
  const hits = search.data?.hits ?? [];
  return (
    <Panel
      title="Memory"
      meta={
        list.data
          ? `${entries.length} ${entries.length === 1 ? 'note' : 'notes'} kept in this workspace`
          : 'Notes kept in this workspace'
      }
    >
      <p className={styles.note}>
        What the workspace remembers between sessions: things learned, things to do, and how work is done here. Agents
        read these notes when a session starts.
      </p>
      <div className={styles.search}>
        <TextInput
          type="search"
          aria-label="Search memory"
          placeholder="Search memory"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
      </div>
      {list.isPending ? <p role="status">Reading memory…</p> : null}
      {list.isError ? <p role="alert">Memory could not be read from this workspace.</p> : null}
      {searching ? (
        <ul className={styles.memoryList} aria-label="Memory search results">
          {search.isFetching && hits.length === 0 ? <li className={styles.note}>Searching…</li> : null}
          {!search.isFetching && hits.length === 0 ? <li className={styles.note}>Nothing matches “{query}”.</li> : null}
          {hits.map((hit) => (
            <li key={`${hit.path}:${hit.line}`}>
              <button type="button" className={styles.memoryRow} onClick={() => setOpen(hit.path)}>
                <span className={styles.memoryTitle}>{hit.snippet}</span>
                <span className={styles.memoryMeta}>
                  {hit.path}, line {hit.line}
                </span>
              </button>
            </li>
          ))}
        </ul>
      ) : (
        <ul className={styles.memoryList} aria-label="Memory notes">
          {list.isSuccess && entries.length === 0 ? (
            <li className={styles.note}>Nothing has been written down yet.</li>
          ) : null}
          {entries.map((entry: MemoryEntry) => (
            <li key={entry.id}>
              <button
                type="button"
                className={styles.memoryRow}
                aria-expanded={open === entry.provenance.file}
                onClick={() => setOpen(open === entry.provenance.file ? null : entry.provenance.file)}
              >
                <span className={styles.memoryTitle}>{entry.title}</span>
                <span className={styles.memoryMeta}>
                  {KIND_LABEL[entry.kind] ?? entry.kind}, {entry.provenance.file}
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}
      {open ? (
        <div className={styles.memoryBody} aria-live="polite">
          <p className={styles.memoryMeta}>{open}</p>
          {file.isPending ? <p role="status">Opening…</p> : null}
          {file.isError ? <p role="alert">This note could not be opened.</p> : null}
          {file.data ? <pre>{file.data.entry.body}</pre> : null}
        </div>
      ) : null}
    </Panel>
  );
}

/**
 * Context and memory: what every agent session in this workspace starts
 * with, how large that is, and the notes the workspace keeps between
 * sessions.
 */
export default function ContextView() {
  const { backend } = useBackend();
  const workspace = backend?.harness?.path ?? '';
  const context = useSubQuery('workspace', 'context');
  const budget = useSubQuery('workspace', 'budget');
  const validation = useSubQuery('workspace', 'validate', undefined, { failureIsData: true });
  const personas = useSubQuery('workspace', 'personas');
  const profiles = useSubQuery('workspace', 'profiles');

  return (
    <div className={styles.page}>
      <header>
        <h1 className={styles.title}>Context and memory</h1>
        <p className={styles.lede}>
          What an agent is told before your first message in this workspace, and what the workspace remembers.
        </p>
      </header>
      <Stack>
        <MemoryPanel />
        <Grid>
          <Panel title="Context size" meta="How much is added to every session before you type">
            <QueryView query={budget} loading="Measuring context" errorTitle="Could not measure the context">
              {(envelope) => (
                <KeyValue
                  items={[
                    {
                      label: 'Weight',
                      value: (
                        <StatusBadge
                          tone={riskTone(envelope.data['risk'])}
                          label={envelope.data['risk'] ?? 'Unknown'}
                        />
                      ),
                    },
                    {
                      label: 'Estimated tokens',
                      value: envelope.data['estimated_tokens']
                        ? Number(envelope.data['estimated_tokens']).toLocaleString()
                        : '—',
                    },
                    {
                      label: 'Characters',
                      value: envelope.data['total_chars'] ? Number(envelope.data['total_chars']).toLocaleString() : '—',
                    },
                  ]}
                />
              )}
            </QueryView>
          </Panel>
          <Panel
            title="Workspace check"
            meta="Whether the workspace files are well formed"
            actions={
              validation.data ? (
                <StatusBadge
                  tone={validation.data.ok ? 'ok' : 'err'}
                  label={
                    validation.data.ok
                      ? 'Valid'
                      : `${validation.data.data['errors'] ?? 'Some'} ${validation.data.data['errors'] === '1' ? 'problem' : 'problems'}`
                  }
                />
              ) : null
            }
          >
            <QueryView query={validation} loading="Checking workspace" errorTitle="Could not check the workspace">
              {(envelope) => (
                <details className={styles.disclosure}>
                  <summary>Show the full check</summary>
                  <CommandReport
                    envelope={{ ...envelope, ok: true }}
                    label="Validation output"
                    hideFields={['errors']}
                  />
                </details>
              )}
            </QueryView>
          </Panel>
        </Grid>
        {workspace ? <WorkspacePacksPanel workspace={workspace} /> : null}
        <Panel title="What a session starts with" meta="The exact text an agent receives">
          <QueryView query={context} loading="Reading start context" errorTitle="Could not read the start context">
            {(envelope) => (
              <details className={styles.disclosure}>
                <summary>Show the complete start context</summary>
                <CommandReport envelope={envelope} label="Session context" />
              </details>
            )}
          </QueryView>
        </Panel>
        <Grid>
          <Panel
            title="Personas"
            meta={personas.data?.data['count'] ? `${personas.data.data['count']} available` : undefined}
          >
            <QueryView query={personas} loading="Listing personas" errorTitle="Could not list personas">
              {(envelope) => (
                <details className={styles.disclosure}>
                  <summary>Show available work modes</summary>
                  <CommandReport envelope={envelope} label="Personas" hideFields={['count']} />
                </details>
              )}
            </QueryView>
          </Panel>
          <Panel
            title="Profiles"
            meta={profiles.data?.data['count'] ? `${profiles.data.data['count']} available` : undefined}
          >
            <QueryView query={profiles} loading="Listing profiles" errorTitle="Could not list profiles">
              {(envelope) => (
                <details className={styles.disclosure}>
                  <summary>Show configured model profiles</summary>
                  <CommandReport envelope={envelope} label="Profiles" hideFields={['count']} />
                </details>
              )}
            </QueryView>
          </Panel>
        </Grid>
      </Stack>
    </div>
  );
}
