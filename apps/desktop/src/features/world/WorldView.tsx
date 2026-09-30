import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router';
import { useBackend } from '../../data/backend';
import { useTools } from '../../data/catalog';
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
} from '../../ui';
import { entityAccessibleName } from './inspectors';
import {
  buildWorldModel,
  layoutWorld,
  parseProjectListMessage,
  type LaidOutEntity,
  type MemorySummary,
  type ToolRecord,
} from './model';
import { cozyTopdownTheme } from './theme/cozyTopdown';
import { WorldEntityList, WorldEntityMap } from './WorldEntityMap';
import styles from './world.module.css';

/**
 * World: semantic spatial home. Domain → model → layout → cozy theme → DOM tiles.
 * Inspectors stay on existing destinations via href(); entities without a path
 * stay non-activating (no invented screens).
 */
export default function WorldView() {
  const { backend } = useBackend();
  const { context, href } = useSessionContext();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const focusProject = params.get('project');
  const focusPlace = params.get('place');

  const projectsQuery = useSubQuery('project', 'list');
  const memoryQuery = useMemoryList();
  const jobsQuery = useJobs();
  const toolsQuery = useTools();
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
    if (memoryQuery.isError) return { available: false, entries: [], projectKeys: [] };
    if (!memoryQuery.isSuccess || !memoryQuery.data) return { available: false, entries: [], projectKeys: [] };
    const entries = (memoryQuery.data.entries ?? []).map((entry) => ({
      id: entry.id,
      kind: entry.kind,
      title: entry.title,
      snippet: entry.snippet,
      tags: entry.tags,
      provenance: entry.provenance,
    }));
    const projectKeys = [...new Set(entries.map((entry) => entry.provenance.project).filter(Boolean))];
    return { available: true, entries, projectKeys };
  }, [memoryQuery.data, memoryQuery.isError, memoryQuery.isSuccess]);

  const tools: ToolRecord[] = useMemo(() => {
    if (!toolsQuery.isSuccess || !toolsQuery.data) return [];
    return toolsQuery.data.tools.map((tool) => ({
      id: tool.id,
      toolName: tool.tool_name,
      detected: tool.detected,
      configured: tool.configured,
      enabled: tool.enabled,
      verified: tool.verified,
      version: tool.version,
    }));
  }, [toolsQuery.data, toolsQuery.isSuccess]);

  const jobs = useMemo(() => sortJobs(jobsQuery.data), [jobsQuery.data]);

  const model = useMemo(
    () =>
      buildWorldModel({
        workspacePath,
        projects,
        projectsKnown: projectsQuery.isSuccess,
        memory,
        tools,
        toolsKnown: toolsQuery.isSuccess,
        jobs: jobs.map((job) => ({
          id: job.id,
          cmd: job.cmd,
          args: job.args,
          status: job.status,
          workspace: job.workspace,
        })),
        focusProjectId: focusProject,
      }),
    [
      workspacePath,
      projects,
      projectsQuery.isSuccess,
      memory,
      tools,
      toolsQuery.isSuccess,
      jobs,
      focusProject,
    ],
  );

  const layout = useMemo(() => layoutWorld(model), [model]);
  const selected = layout.entities.find((entity) => entity.id === selectedId) ?? null;

  useEffect(() => {
    if (!focusPlace || focusPlace === 'projects') return;
    if (layout.entities.some((entity) => entity.id === focusPlace)) {
      setSelectedId(focusPlace);
    }
  }, [focusPlace, layout.entities]);

  useEffect(() => {
    if (!focusProject) return;
    const roomId = `place:project:${focusProject}`;
    if (layout.entities.some((entity) => entity.id === roomId)) {
      setSelectedId(roomId);
    }
  }, [focusProject, layout.entities]);

  const gathering = projectsQuery.isPending || jobsQuery.isPending;

  const openEntity = (entity: LaidOutEntity) => {
    if (!entity.hrefPath) return;
    navigate(href(entity.hrefPath, entity.hrefExtra));
  };

  return (
    <div className={styles.world} data-focus={model.focusProjectId ? 'interior' : 'grounds'}>
      <PageHeader
        eyebrow={model.focusProjectId ? 'Project interior' : 'World'}
        title={model.focusProjectId ? `${model.focusProjectId} house` : model.workspaceLabel || 'Workspace world'}
        lede={
          model.focusProjectId
            ? 'Inside this project house — Paper Co. room with memory records, terminal, and detected tools only. No fake dashboard.'
            : 'Paper Co. grounds: real project houses, memory archive when the API exists, Library annex for capabilities. Calm when idle.'
        }
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
          Theme <strong>{cozyTopdownTheme.label}</strong> · semantic keys only · characters only for proven jobs · calm
          houses when idle · click opens existing inspectors only.
        </p>

        <Panel
          tone="manila"
          title={model.focusProjectId ? 'Interior map' : 'Spatial map'}
          meta={`${layout.entities.length} entities · ${cozyTopdownTheme.tileSize}px tiles`}
        >
          {gathering ? (
            <LoadingState label="Reading workspace, projects, memory, tools, and jobs" />
          ) : layout.entities.length === 0 ? (
            <EmptyState title="Nothing to place yet.">Waiting on workspace context.</EmptyState>
          ) : (
            <WorldEntityMap
              entities={layout.entities}
              selectedId={selectedId}
              theme={cozyTopdownTheme}
              cols={layout.cols}
              rows={layout.rows}
              ariaLabel={model.focusProjectId ? `Interior of ${model.focusProjectId}` : 'Semantic workspace world'}
              mode={model.focusProjectId ? 'interior' : 'grounds'}
              onSelect={setSelectedId}
              onActivate={openEntity}
            />
          )}
          {selected ? (
            <p className={styles.hint}>
              Selected: <strong>{selected.name}</strong> — {entityAccessibleName(selected)}.
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
            <WorldEntityList
              entities={layout.entities}
              selectedId={selectedId}
              href={href}
              onSelect={setSelectedId}
            />
          )}
        </Panel>
      </Stack>
    </div>
  );
}
