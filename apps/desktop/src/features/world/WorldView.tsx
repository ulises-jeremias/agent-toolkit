import { useMemo, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router';
import { useBackend } from '../../data/backend';
import { useSubQuery } from '../../data/commands';
import { sortJobs, useJobs } from '../../data/jobs';
import { useMemoryList } from '../../data/memory';
import { envelopeText } from '../../lib/api';
import { useSessionContext } from '../../shell/useSessionContext';
import {
  EmptyState,
  ErrorState,
  LoadingState,
  PageHeader,
  Panel,
  Stack,
  StatusBadge,
  Table,
  VisuallyHidden,
} from '../../ui';
import { buildWorldModel, layoutWorld, parseProjectListMessage, type LaidOutEntity, type MemorySummary } from './model';
import { cozyTopdownTheme, resolveThemeAsset } from './theme/cozyTopdown';
import styles from './world.module.css';

function toneForState(state: string): 'ok' | 'warn' | 'err' | 'idle' | 'info' {
  if (state === 'ok' || state === 'running' || state === 'known' || state === 'ready' || state === 'present') {
    return 'ok';
  }
  if (state === 'broken' || state === 'failed' || statusErr(state) || state === 'missing') return 'err';
  if (state === 'queued' || state === 'notice' || state === 'empty' || state === 'unavailable') return 'warn';
  if (state === 'inspector' || state === 'catalog') return 'info';
  return 'idle';
}

function statusErr(state: string): boolean {
  return state === 'rejected' || state === 'err';
}

/**
 * World: semantic spatial home. Domain → model → layout → cozy theme → DOM tiles.
 * Inspectors stay on existing destinations via href().
 */
export default function WorldView() {
  const { backend } = useBackend();
  const { context, href } = useSessionContext();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const focusProject = params.get('project');

  const projectsQuery = useSubQuery('project', 'list');
  const memoryQuery = useMemoryList();
  const jobsQuery = useJobs();
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const workspacePath =
    context.workspace ||
    backend?.harness?.path ||
    (typeof projectsQuery.data?.data['workspace'] === 'string' ? projectsQuery.data.data['workspace'] : '') ||
    '';

  const projects = useMemo(() => {
    if (!projectsQuery.isSuccess || !projectsQuery.data) return [];
    return parseProjectListMessage(envelopeText(projectsQuery.data));
  }, [projectsQuery.data, projectsQuery.isSuccess]);

  const memory: MemorySummary = useMemo(() => {
    if (memoryQuery.isError) return { available: false, entryCount: 0, projectKeys: [] };
    if (!memoryQuery.isSuccess || !memoryQuery.data) return { available: false, entryCount: 0, projectKeys: [] };
    const entries = memoryQuery.data.entries ?? [];
    const projectKeys = [
      ...new Set(entries.map((entry) => entry.provenance?.project).filter((value): value is string => Boolean(value))),
    ];
    return { available: true, entryCount: entries.length, projectKeys };
  }, [memoryQuery.data, memoryQuery.isError, memoryQuery.isSuccess]);

  const jobs = useMemo(() => sortJobs(jobsQuery.data), [jobsQuery.data]);

  const model = useMemo(
    () =>
      buildWorldModel({
        workspacePath,
        harnessNotice: backend?.harness?.notice ?? null,
        projects,
        projectsKnown: projectsQuery.isSuccess,
        memory,
        jobs,
        focusProjectId: focusProject,
      }),
    [backend?.harness?.notice, focusProject, jobs, memory, projects, projectsQuery.isSuccess, workspacePath],
  );

  const layout = useMemo(() => layoutWorld(model), [model]);
  const selected = layout.entities.find((entity) => entity.id === selectedId) ?? null;
  const tile = cozyTopdownTheme.tileSize;

  const gathering = projectsQuery.isPending && jobsQuery.isPending && memoryQuery.isPending;

  const openEntity = (entity: LaidOutEntity) => {
    setSelectedId(entity.id);
    navigate(href(entity.hrefPath, entity.hrefExtra));
  };

  return (
    <div className={styles.world}>
      <PageHeader
        eyebrow="World"
        title={model.focusProjectId ? `${model.focusProjectId} space` : model.workspaceLabel || 'Workspace world'}
        lede="Places and characters are real Agent Toolkit concepts. Click opens an inspector — no walking required."
        actions={
          model.focusProjectId ? (
            <Link to={href('/world')}>Back to workspace grounds</Link>
          ) : (
            <Link to={href('/workspace')}>Open Workspace inspector</Link>
          )
        }
      />
      <Stack>
        <p className={styles.hint}>
          Theme <strong>{cozyTopdownTheme.label}</strong> · semantic keys only · characters appear only for proven jobs
          · calm empty world is valid.
        </p>

        <Panel
          tone="manila"
          title="Spatial map"
          meta={`${layout.entities.length} entities · ${cozyTopdownTheme.tileSize}px tiles`}
        >
          {gathering ? (
            <LoadingState label="Reading workspace, projects, memory, and jobs" />
          ) : (
            <div
              className={styles.mapRegion}
              role="application"
              aria-label="Semantic workspace world"
              data-theme={cozyTopdownTheme.id}
            >
              <div
                className={styles.map}
                style={{
                  width: layout.cols * tile,
                  height: layout.rows * tile,
                }}
              >
                {layout.entities.map((entity) => {
                  const asset = resolveThemeAsset(cozyTopdownTheme, entity.themeKey);
                  const tileClass =
                    asset.kind === 'css' && asset.className in styles
                      ? styles[asset.className as keyof typeof styles]
                      : styles.worldTileFallback;
                  const className = `${styles.entity} ${tileClass}`;
                  return (
                    <button
                      key={entity.id}
                      type="button"
                      className={className}
                      data-kind={entity.kind}
                      data-theme-key={entity.themeKey}
                      title={`${entity.name} · ${entity.concept} · ${entity.state}`}
                      aria-label={`${entity.name}, ${entity.concept}, ${entity.state}. Activate to inspect.`}
                      style={{
                        left: entity.x * tile,
                        top: entity.y * tile,
                        width: entity.w * tile,
                        height: entity.h * tile,
                      }}
                      onClick={() => openEntity(entity)}
                      onFocus={() => setSelectedId(entity.id)}
                    >
                      <span className={styles.entityState} data-tone={toneForState(entity.state)} aria-hidden="true" />
                      <span className={styles.entityLabel}>{entity.name}</span>
                    </button>
                  );
                })}
              </div>
            </div>
          )}
          {selected ? (
            <p className={styles.hint}>
              Selected: <strong>{selected.name}</strong> — {selected.concept}. State: {selected.state}.{' '}
              {selected.detail}
            </p>
          ) : null}
          {projectsQuery.isError ? (
            <ErrorState
              title="Could not list projects"
              error={projectsQuery.error}
              onRetry={() => void projectsQuery.refetch()}
            />
          ) : null}
        </Panel>

        <Panel title="Structured list" meta="Accessibility fallback for every spatial entity">
          {layout.entities.length === 0 ? (
            <EmptyState title="Nothing to place yet.">Waiting on workspace context.</EmptyState>
          ) : (
            <Table>
              <thead>
                <tr>
                  <th scope="col">Name</th>
                  <th scope="col">Concept</th>
                  <th scope="col">State</th>
                  <th scope="col">Kind</th>
                  <th scope="col">
                    <VisuallyHidden>Open</VisuallyHidden>
                  </th>
                </tr>
              </thead>
              <tbody>
                {layout.entities.map((entity) => (
                  <tr key={`list:${entity.id}`} data-selected={entity.id === selectedId ? 'true' : undefined}>
                    <th scope="row">{entity.name}</th>
                    <td>{entity.concept}</td>
                    <td>
                      <StatusBadge tone={toneForState(entity.state)} label={entity.state} />
                    </td>
                    <td>{entity.kind}</td>
                    <td data-align="end">
                      <Link to={href(entity.hrefPath, entity.hrefExtra)} onClick={() => setSelectedId(entity.id)}>
                        Inspect
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </Table>
          )}
        </Panel>
      </Stack>
    </div>
  );
}
