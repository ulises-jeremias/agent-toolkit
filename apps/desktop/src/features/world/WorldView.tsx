import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router';
import { useQuery } from '@tanstack/react-query';
import { requireClient, useBackend } from '../../data/backend';
import { useTools } from '../../data/catalog';
import { sortJobs, useJobs } from '../../data/jobs';
import { useMemoryFile, useMemoryList } from '../../data/memory';
import { useProjects } from '../../data/projects';
import { useTerminalSessions } from '../../data/terminal';
import { personCharacterSprite } from '../people/avatar';
import { useSessionContext } from '../../shell/useSessionContext';
import { EmptyState, ErrorState } from '../../ui';
import { installTargetForTool, worldDetailBackExtra, worldDetailBackLabel } from './inspectors';
import { MemoryRecordInspector } from './MemoryRecordInspector';
import {
  buildWorldModel,
  layoutWorld,
  pathIsWithin,
  type LaidOutEntity,
  type MemorySummary,
  type ToolRecord,
} from './model';
import { cozyValleyTheme } from './theme/cozyValley';
import { ToolRecordInspector } from './ToolRecordInspector';
import { useWorldDetailEscape } from './useWorldDetailEscape';
import { WorldEntityList, WorldEntityMap } from './WorldEntityMap';
import styles from './world.module.css';

/**
 * World: semantic spatial home. Domain → model → layout → theme →
 * terrain canvas + pixel sprites. The world is the screen; memory/tool
 * detail inspectors stay on `/world` query params and call real APIs.
 */
export default function WorldView() {
  const { backend, client } = useBackend();
  const { context, href } = useSessionContext();
  const terminalSessions = useTerminalSessions();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const focusProject = params.get('project');
  const focusPlace = params.get('place');
  const memoryPath = params.get('memory')?.trim() || '';
  const toolId = params.get('tool')?.trim() || '';

  const workspacePath = context.workspace || backend?.harness?.path || '';
  const projectsQuery = useProjects(workspacePath);
  const memoryQuery = useMemoryList();
  const memoryFileQuery = useMemoryFile(memoryPath, { enabled: memoryPath.length > 0 });
  const jobsQuery = useJobs();
  const toolsQuery = useTools();
  const livePersonPtys = useMemo(
    () => terminalSessions.sessions.filter((session) => session.personId && session.exitCode === null),
    [terminalSessions.sessions],
  );
  const peopleQuery = useQuery({
    queryKey: ['people', context.workspace],
    queryFn: () => requireClient(client).people(context.workspace),
    enabled: Boolean(client && context.workspace && livePersonPtys.length > 0),
    staleTime: 15_000,
  });
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const projects = useMemo(() => {
    if (!projectsQuery.isSuccess || !projectsQuery.data) return [];
    return projectsQuery.data.projects;
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

  const personSessions = useMemo(() => {
    if (!peopleQuery.data) return [];
    const peopleById = new Map(peopleQuery.data.people.map((person) => [person.id, person]));
    return livePersonPtys.flatMap((session) => {
      const person = session.personId ? peopleById.get(session.personId) : undefined;
      const project = projects.find(
        (candidate) => candidate.name === session.projectId && pathIsWithin(session.cwd, candidate.target),
      );
      if (!person || !project) return [];
      return [
        {
          id: session.id,
          personId: person.id,
          name: person.name,
          role: person.role,
          cwd: session.cwd,
          projectId: project.name,
          provider: session.provider,
          model: session.model,
          avatarCharacter: personCharacterSprite(person),
        },
      ];
    });
  }, [livePersonPtys, peopleQuery.data, projects]);

  const harnessNotice = backend?.harness?.notice ?? null;

  const model = useMemo(
    () =>
      buildWorldModel({
        workspacePath,
        harnessNotice,
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
        personSessions,
        focusProjectId: focusProject,
      }),
    [
      workspacePath,
      harnessNotice,
      projects,
      projectsQuery.isSuccess,
      memory,
      tools,
      toolsQuery.isSuccess,
      jobs,
      personSessions,
      focusProject,
    ],
  );

  const layout = useMemo(() => layoutWorld(model), [model]);
  const selected = layout.entities.find((entity) => entity.id === selectedId) ?? null;
  const inspectedTool = toolsQuery.data?.tools.find((tool) => tool.id === toolId) ?? null;

  useEffect(() => {
    if (memoryPath) {
      const hit = layout.entities.find((entity) => entity.hrefExtra?.memory === memoryPath);
      if (hit) setSelectedId(hit.id);
      return;
    }
    if (toolId) {
      const hit = layout.entities.find((entity) => entity.hrefExtra?.tool === toolId);
      if (hit) setSelectedId(hit.id);
      return;
    }
    if (focusPlace && focusPlace !== 'projects') {
      if (layout.entities.some((entity) => entity.id === focusPlace)) {
        setSelectedId(focusPlace);
      }
      return;
    }
    if (focusProject) {
      const roomId = `place:project:${focusProject}`;
      if (layout.entities.some((entity) => entity.id === roomId)) {
        setSelectedId(roomId);
      }
    }
  }, [memoryPath, toolId, focusPlace, focusProject, layout.entities]);

  const gathering =
    projectsQuery.isPending ||
    jobsQuery.isPending ||
    memoryQuery.isPending ||
    toolsQuery.isPending ||
    (livePersonPtys.length > 0 && peopleQuery.isPending);

  const openEntity = (entity: LaidOutEntity) => {
    if (!entity.hrefPath) return;
    navigate(href(entity.hrefPath, entity.hrefExtra));
  };

  const detailOpen = Boolean(memoryPath || toolId);
  const backLabel = worldDetailBackLabel(focusProject);
  const goBackFromDetail = useCallback(() => {
    navigate(href('/world', worldDetailBackExtra(focusProject)));
  }, [navigate, href, focusProject]);
  const goBackFromWorld = useCallback(() => {
    if (detailOpen) {
      goBackFromDetail();
      return;
    }
    if (focusProject) {
      navigate(href('/world'));
    }
  }, [detailOpen, goBackFromDetail, focusProject, navigate, href]);
  // Escape: leave memory/tool detail first; else leave project interior to grounds.
  useWorldDetailEscape(goBackFromWorld, detailOpen || Boolean(focusProject));

  const title = model.focusProjectId ? `${model.focusProjectId} house` : model.workspaceLabel || 'Workspace world';

  return (
    <div className={styles.world} data-focus={model.focusProjectId ? 'interior' : 'grounds'}>
      <header className={styles.worldHeader}>
        <h1 className={styles.worldTitle}>{title}</h1>
        <span className={styles.worldMeta}>
          {model.focusProjectId ? 'project interior' : 'workspace valley'} · {layout.entities.length} places
        </span>
        {selected ? (
          <span className={styles.selectedChip} aria-live="polite">
            Selected: <strong>{selected.name}</strong> — {selected.concept}
            {selected.state ? ` · ${selected.state}` : ''}
          </span>
        ) : null}
        <Link className={styles.worldHeaderLink} to={model.focusProjectId ? href('/world') : href('/workspace')}>
          {model.focusProjectId ? '← grounds' : 'Workspace inspector'}
        </Link>
      </header>

      <div className={styles.mapWrap} aria-busy={gathering}>
        {layout.entities.length === 0 ? (
          <EmptyState title="Nothing to place yet.">Waiting on workspace context.</EmptyState>
        ) : (
          <WorldEntityMap
            entities={layout.entities}
            selectedId={selectedId}
            theme={cozyValleyTheme}
            cols={layout.cols}
            rows={layout.rows}
            ariaLabel={model.focusProjectId ? `Interior of ${model.focusProjectId}` : 'Semantic workspace world'}
            mode={model.focusProjectId ? 'interior' : 'grounds'}
            suspended={detailOpen}
            onSelect={setSelectedId}
            onActivate={openEntity}
          />
        )}
        {gathering && layout.entities.length > 0 ? (
          <p className={styles.worldLoadStatus} role="status" aria-live="polite">
            Checking live workspace details…
          </p>
        ) : null}
        {projectsQuery.isError ? (
          <ErrorState
            title="Could not list projects"
            error={projectsQuery.error}
            onRetry={() => void projectsQuery.refetch()}
          />
        ) : null}
        {livePersonPtys.length > 0 && peopleQuery.isError ? (
          <ErrorState
            title="Person presence is temporarily unavailable"
            error={peopleQuery.error}
            onRetry={() => void peopleQuery.refetch()}
          />
        ) : null}
      </div>

      {memoryPath ? (
        <MemoryRecordInspector
          path={memoryPath}
          data={memoryFileQuery.data}
          error={memoryFileQuery.error}
          isPending={memoryFileQuery.isPending}
          onBack={goBackFromDetail}
          backLabel={backLabel}
          onRetry={() => void memoryFileQuery.refetch()}
        />
      ) : null}

      {toolId && !memoryPath ? (
        <ToolRecordInspector
          toolId={toolId}
          tool={inspectedTool}
          isPending={toolsQuery.isPending}
          error={toolsQuery.error}
          onReviewInstall={() => {
            const target = installTargetForTool(toolId);
            navigate(href('/library', { install_target: target ?? undefined }));
          }}
          onBack={goBackFromDetail}
          backLabel={backLabel}
          onRetry={() => void toolsQuery.refetch()}
        />
      ) : null}

      <details className={styles.entityListWrap}>
        <summary>
          <span className={styles.worldTitle}>World index</span>{' '}
          <span className={styles.worldMeta}>— {layout.entities.length} places, resources, and active workers</span>
        </summary>
        {layout.entities.length === 0 ? (
          <EmptyState title="Nothing to place yet.">Waiting on workspace context.</EmptyState>
        ) : (
          <WorldEntityList entities={layout.entities} selectedId={selectedId} href={href} onSelect={setSelectedId} />
        )}
      </details>
    </div>
  );
}
