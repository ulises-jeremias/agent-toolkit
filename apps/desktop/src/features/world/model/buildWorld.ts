import { isTerminalJobStatus } from '../../../lib/api';
import { memoryFilePath, memoryInspectExtra } from '../inspectors';
import { projectFacades } from './facades';
import { jobStandAtId, projectScopedMemory, workspaceLevelMemory } from './memoryScope';
import type {
  MemoryEntryRecord,
  PlaceActivity,
  ProjectRecord,
  SemanticEntity,
  ToolRecord,
  WorldDomainInput,
  WorldModel,
} from './types';

function workspaceLabel(path: string): string {
  const trimmed = path.replace(/[/\\]+$/, '');
  const parts = trimmed.split(/[/\\]/).filter(Boolean);
  return parts[parts.length - 1] ?? (path || 'Workspace');
}

function jobCommandLine(job: WorldDomainInput['jobs'][number]): string {
  return [job.cmd, ...job.args].filter(Boolean).join(' ');
}

function characterTheme(status: string): SemanticEntity['themeKey'] {
  if (status === 'failed' || status === 'rejected') return 'agent.blocked';
  if (status === 'queued' || status === 'running') return 'agent.working';
  return 'agent.idle';
}

function provenanceDetail(entry: MemoryEntryRecord): string {
  const parts = [
    entry.kind,
    entry.provenance.project ? `project ${entry.provenance.project}` : '',
    entry.provenance.author ? `by ${entry.provenance.author}` : '',
    entry.provenance.file || '',
  ].filter(Boolean);
  return parts.join(' · ') || entry.id;
}

/** Match a job to a project via workspace path — never invent ownership. */
export function jobBelongsToProject(job: { workspace: string }, project: ProjectRecord): boolean {
  const ws = job.workspace.trim();
  if (!ws) return false;
  if (
    project.target &&
    (ws === project.target || ws.startsWith(`${project.target}/`) || ws.startsWith(`${project.target}\\`))
  ) {
    return true;
  }
  const needle = `/${project.name}`;
  const needleWin = `\\${project.name}`;
  return ws.includes(needle) || ws.includes(needleWin) || ws.endsWith(project.name);
}

function activityForJobs(jobs: WorldDomainInput['jobs']): PlaceActivity {
  let working = 0;
  let blocked = 0;
  for (const job of jobs) {
    if (job.status === 'failed' || job.status === 'rejected') blocked += 1;
    else if (!isTerminalJobStatus(job.status)) working += 1;
  }
  if (blocked > 0) return 'blocked';
  if (working > 0) return 'working';
  return 'calm';
}

function projectWorldState(
  project: ProjectRecord,
  activity: PlaceActivity,
  jobCount: number,
  personCount: number,
): string {
  if (project.status === 'broken') return 'broken';
  if (activity === 'working') return `${jobCount} job${jobCount === 1 ? '' : 's'} active`;
  if (activity === 'blocked') return 'needs attention';
  if (personCount > 0) return `${personCount} Person session${personCount === 1 ? '' : 's'} open`;
  return 'calm';
}

function pushPersonCharacters(
  entities: SemanticEntity[],
  sessions: NonNullable<WorldDomainInput['personSessions']>,
  projectId?: string,
  standAtId?: string,
): void {
  for (const session of sessions) {
    entities.push({
      id: `character:person:${session.personId}:${session.id}`,
      kind: 'character',
      concept: 'Person session',
      name: session.name,
      state: 'session open',
      themeKey: 'agent.idle',
      characterSprite: session.avatarCharacter,
      availability: 'present',
      hrefPath: '/people',
      hrefExtra: { person: session.personId, session: session.id },
      projectId,
      detail: `${session.role} · ${session.provider ?? 'runner unknown'}${session.model ? ` · ${session.model}` : ''} · PTY ${session.id}`,
      standAtId,
    });
  }
}

function visibleTools(tools: ToolRecord[]): ToolRecord[] {
  // Only tools the API actually detected — never invent rack slots.
  return tools.filter((tool) => tool.detected).sort((a, b) => a.id.localeCompare(b.id));
}

function pushJobCharacters(
  entities: SemanticEntity[],
  jobs: WorldDomainInput['jobs'],
  opts: {
    projectId?: string;
    tools: readonly ToolRecord[];
    memoryPlaceId?: string;
    terminalObjectId?: string;
  },
): void {
  for (const job of jobs) {
    // A failed/rejected job remains an Operations record, not a live worker.
    if (isTerminalJobStatus(job.status)) continue;
    const standAtId = jobStandAtId(job, {
      tools: opts.tools,
      memoryPlaceId: opts.memoryPlaceId,
      terminalObjectId: opts.terminalObjectId,
    });
    entities.push({
      id: `character:job:${job.id}`,
      kind: 'character',
      concept: 'Job',
      name: jobCommandLine(job) || job.id,
      state: job.status,
      themeKey: characterTheme(job.status),
      availability: 'present',
      hrefPath: '/operations',
      hrefExtra: { job: job.id },
      projectId: opts.projectId,
      detail: `Job ${job.id}`,
      activity: 'working',
      standAtId,
    });
  }
}

function buildGrounds(input: WorldDomainInput): SemanticEntity[] {
  const entities: SemanticEntity[] = [];

  entities.push({
    id: 'place:workspace',
    kind: 'place',
    concept: 'Active harness / workspace root',
    name: workspaceLabel(input.workspacePath) || 'Workspace',
    state: input.harnessNotice ? 'notice' : input.workspacePath ? 'known' : 'missing',
    themeKey: 'workspace.grounds',
    availability: input.workspacePath ? 'present' : 'empty',
    hrefPath: '/workspace',
    detail: input.harnessNotice || input.workspacePath || 'No workspace path in session context',
    facade: 'landmark-workspace',
  });

  if (input.memory.available) {
    // World archive: workspace-level only (empty project or non-roster label).
    const archive = workspaceLevelMemory(input.memory.entries, input.projects);
    const count = archive.length;
    entities.push({
      id: 'place:memory',
      kind: 'place',
      concept: 'Memory archive',
      name: 'Memory archive',
      state: count > 0 ? `${count} records` : 'empty',
      themeKey: 'memory.index',
      availability: count > 0 ? 'present' : 'empty',
      hrefPath: '/world',
      hrefExtra: { place: 'place:memory' },
      // Overview only — open a record tile (or stay selected). Never pretend Workspace is memory.
      detail:
        count > 0
          ? `${count} workspace-level memory record${count === 1 ? '' : 's'} (typed memory API)`
          : 'Memory API reachable; archive is empty',
      facade: 'landmark-archive',
    });

    // Keep the grounds scannable — a few recent ledgers beside the archive, not a card wall.
    const GROUNDS_MEMORY_LEDGERS = 3;
    for (const entry of archive.slice(0, GROUNDS_MEMORY_LEDGERS)) {
      const path = memoryFilePath(entry);
      const more = count > GROUNDS_MEMORY_LEDGERS ? ` · showing ${GROUNDS_MEMORY_LEDGERS} of ${count} on grounds` : '';
      entities.push({
        id: `object:memory:${entry.id}`,
        kind: 'object',
        concept: 'Memory entry',
        name: entry.title || entry.id,
        state: entry.kind || 'listed',
        themeKey: 'memory.entry',
        availability: 'present',
        hrefPath: '/world',
        hrefExtra: memoryInspectExtra(entry),
        detail: (provenanceDetail(entry) || path) + more,
      });
    }
  }

  // Shared landmarks are places (3×3 footprints) so silhouettes read as buildings.
  entities.push({
    id: 'object:terminal',
    kind: 'place',
    concept: 'Terminal / PTY workstation',
    name: 'Terminal',
    state: 'ready',
    themeKey: 'tool.terminal',
    availability: 'present',
    hrefPath: '/terminal',
    detail: 'Open the Terminal destination or dock',
    facade: 'landmark-terminal',
  });

  // Library is the knowledge/capability inspector — not a second invented room.
  entities.push({
    id: 'object:library',
    kind: 'place',
    concept: 'Capability library',
    name: 'Library',
    state: 'catalog',
    themeKey: 'capability.shelf',
    availability: 'present',
    hrefPath: '/library',
    detail: 'Skills, agents, packs — reusable catalog capabilities',
    facade: 'landmark-library',
  });

  const tools = input.toolsKnown ? visibleTools(input.tools) : [];
  const toolDetail = `${tools.length} coding-tool runtime${tools.length === 1 ? '' : 's'} detected · inspect in Library`;
  entities.push({
    id: 'object:workshop',
    kind: 'place',
    concept: 'Shared coding-tool workshop',
    name: 'Workshop',
    state: input.toolsKnown ? (tools.length ? `${tools.length} detected` : 'empty') : 'unknown',
    themeKey: 'tool.coding',
    availability: input.toolsKnown ? (tools.length ? 'present' : 'empty') : 'unavailable',
    hrefPath: '/library',
    detail: input.toolsKnown
      ? tools.length
        ? toolDetail
        : 'No coding-tool runtime detected · browse available capabilities in Library'
      : 'Coding-tool inventory is unavailable · retry from Library',
    facade: 'landmark-workshop',
  });
  // Files use the typed workspace tree API — open Workspace Files panel.
  entities.push({
    id: 'object:files',
    kind: 'place',
    concept: 'Workspace files',
    name: 'Files',
    state: 'ready',
    themeKey: 'files.workspace',
    availability: 'present',
    hrefPath: '/workspace',
    hrefExtra: { panel: 'files' },
    detail: 'Workspace-contained tree via GET /api/v1/files',
    facade: 'landmark-files',
  });

  // Operations is the shared runtime building — not a second home.
  entities.push({
    id: 'object:operations',
    kind: 'place',
    concept: 'Operations / runtime',
    name: 'Operations',
    state: 'ready',
    themeKey: 'ops.crate',
    availability: 'present',
    hrefPath: '/operations',
    detail: 'Jobs, loops, swarms, and doctor — real serve state only',
    facade: 'landmark-operations',
  });

  entities.push({
    id: 'object:settings',
    kind: 'place',
    concept: 'Settings',
    name: 'Settings',
    state: 'ready',
    themeKey: 'ops.lamp',
    availability: 'present',
    hrefPath: '/settings',
    detail: 'Appearance, harness, and coding-tool connections',
    facade: 'landmark-settings',
  });

  entities.push({
    id: 'object:attention',
    kind: 'place',
    concept: 'Attention inbox',
    name: 'Needs you',
    state: 'inspector',
    themeKey: 'attention.inbox',
    availability: 'present',
    hrefPath: '/office',
    detail: 'Failures and blocked work — attention inspector, not home',
    facade: 'landmark-attention',
  });

  const groundsStand = {
    tools: [],
    memoryPlaceId: input.memory.available ? 'place:memory' : undefined,
    terminalObjectId: 'object:terminal',
  };

  if (!input.projectsKnown) {
    // Omit fabricated project buildings when the list call failed.
  } else if (input.projects.length === 0) {
    entities.push({
      id: 'place:projects-empty',
      kind: 'marker',
      concept: 'Project roster',
      name: 'No projects yet',
      state: 'empty',
      themeKey: 'project.building',
      availability: 'empty',
      hrefPath: '/workspace',
      hrefExtra: { panel: 'projects' },
      detail: 'Add or open a project — the world stays quiet until then',
    });
  } else {
    const facades = projectFacades(input.projects.map((project) => project.name));
    for (const project of input.projects) {
      const projectJobs = input.jobs.filter((job) => jobBelongsToProject(job, project));
      const projectSessions = (input.personSessions ?? []).filter(
        (session) => session.projectId === project.name && pathIsWithin(session.cwd, project.target),
      );
      const activity = activityForJobs(projectJobs);
      const liveCount = projectJobs.filter((job) => !isTerminalJobStatus(job.status)).length;
      const projectPlaceId = `place:project:${project.name}`;
      entities.push({
        id: projectPlaceId,
        kind: 'place',
        concept: 'Project',
        name: project.name,
        state: projectWorldState(project, activity, liveCount, projectSessions.length),
        themeKey: 'project.building',
        availability: 'present',
        hrefPath: '/world',
        hrefExtra: { project: project.name },
        projectId: project.name,
        detail: `${project.status} → ${project.target}${liveCount ? ` · ${liveCount} job(s)` : ''}${projectSessions.length ? ` · ${projectSessions.length} Person session(s)` : ''}`,
        activity,
        facade: facades.get(project.name),
      });

      // Real project sessions belong at their project house. Coding tools are
      // shared workspace resources and must not pull project work back to the
      // global workshop.
      pushJobCharacters(entities, projectJobs, {
        projectId: project.name,
        tools: [],
        terminalObjectId: projectPlaceId,
      });
      pushPersonCharacters(entities, projectSessions, project.name, projectPlaceId);
    }
  }

  // Workspace-scoped jobs (no project match) still appear on the grounds.
  const unmatched = input.jobs.filter((job) => !input.projects.some((project) => jobBelongsToProject(job, project)));
  pushJobCharacters(entities, unmatched, groundsStand);
  return entities;
}

/**
 * Project interior — inside one house. Not a dashboard: only places backed by
 * real capabilities for this project (memory API, terminal, project files, jobs).
 */
function buildInterior(input: WorldDomainInput, focus: string): SemanticEntity[] {
  const entities: SemanticEntity[] = [];
  const project = input.projects.find((row) => row.name === focus);

  entities.push({
    id: 'object:exit-grounds',
    kind: 'object',
    concept: 'Return to workspace grounds',
    name: 'Exit',
    state: 'ready',
    themeKey: 'workspace.grounds',
    availability: 'present',
    hrefPath: '/world',
    detail: 'Leave the project interior',
    facade: 'door-exit',
  });

  if (!project) {
    entities.push({
      id: 'place:projects-empty',
      kind: 'marker',
      concept: 'Project',
      name: focus,
      state: 'missing',
      themeKey: 'project.building',
      availability: 'unavailable',
      hrefPath: '/world',
      detail: 'Project not in the current roster',
    });
    return entities;
  }

  const projectJobs = input.jobs.filter((job) => jobBelongsToProject(job, project));
  const projectSessions = (input.personSessions ?? []).filter(
    (session) => session.projectId === project.name && pathIsWithin(session.cwd, project.target),
  );
  const activity = activityForJobs(projectJobs);
  const liveCount = projectJobs.filter(
    (job) => !isTerminalJobStatus(job.status) || job.status === 'failed' || job.status === 'rejected',
  ).length;

  entities.push({
    id: `place:project:${project.name}`,
    kind: 'place',
    concept: 'Project overview board',
    name: project.name,
    state: projectWorldState(project, activity, liveCount, projectSessions.length),
    themeKey: 'project.building',
    availability: 'present',
    hrefPath: '/workspace',
    hrefExtra: { panel: 'projects' },
    projectId: project.name,
    detail: `${project.status} → ${project.target}${projectSessions.length ? ` · ${projectSessions.length} Person session(s)` : ''}`,
    activity,
    facade: 'project-board',
  });

  if (input.memory.available) {
    const scoped = projectScopedMemory(input.memory.entries, project.name);
    entities.push({
      id: `place:memory-project:${project.name}`,
      kind: 'place',
      concept: 'Project memory records',
      name: 'Records',
      state: scoped.length > 0 ? `${scoped.length} records` : 'empty',
      themeKey: 'memory.index',
      availability: scoped.length > 0 ? 'present' : 'empty',
      hrefPath: '/world',
      hrefExtra: { project: project.name, place: `place:memory-project:${project.name}` },
      projectId: project.name,
      detail:
        scoped.length > 0
          ? `${scoped.length} memory record${scoped.length === 1 ? '' : 's'} for this project`
          : 'Memory API reachable; no records scoped to this project',
      facade: 'landmark-archive',
    });

    for (const entry of scoped) {
      const path = memoryFilePath(entry);
      entities.push({
        id: `object:memory:${entry.id}`,
        kind: 'object',
        concept: 'Memory entry',
        name: entry.title || entry.id,
        state: entry.kind || 'listed',
        themeKey: 'memory.entry',
        availability: 'present',
        hrefPath: '/world',
        hrefExtra: memoryInspectExtra(entry, project.name),
        projectId: project.name,
        detail: provenanceDetail(entry) || path,
      });
    }
  }

  entities.push({
    id: `object:terminal-project:${project.name}`,
    kind: 'object',
    concept: 'Terminal / PTY workstation',
    name: 'Terminal',
    state: 'ready',
    themeKey: 'tool.terminal',
    availability: 'present',
    hrefPath: '/terminal',
    projectId: project.name,
    detail: `Open Terminal · cwd hint ${project.target}`,
    facade: 'landmark-terminal',
  });

  entities.push({
    id: `object:files-project:${project.name}`,
    kind: 'object',
    concept: 'Project files',
    name: 'Files',
    state: 'ready',
    themeKey: 'files.project',
    availability: 'present',
    hrefPath: '/workspace',
    hrefExtra: { panel: 'files', project: project.name },
    projectId: project.name,
    detail: `Project files · ${project.target}`,
    facade: 'desk-files',
  });

  pushJobCharacters(entities, projectJobs, {
    projectId: project.name,
    tools: [],
    memoryPlaceId: input.memory.available ? `place:memory-project:${project.name}` : undefined,
    terminalObjectId: `object:terminal-project:${project.name}`,
  });
  pushPersonCharacters(entities, projectSessions, project.name, `object:terminal-project:${project.name}`);

  return entities;
}

export function pathIsWithin(path: string, root: string): boolean {
  const normalize = (value: string) => value.replace(/\\/g, '/').replace(/\/+$/, '') || '/';
  const candidate = normalize(path);
  const parent = normalize(root);
  const windowsPath = /^[a-z]:\//i.test(candidate) || /^[a-z]:\//i.test(parent);
  const left = windowsPath ? candidate.toLowerCase() : candidate;
  const right = windowsPath ? parent.toLowerCase() : parent;
  return left === right || (right === '/' ? left.startsWith('/') : left.startsWith(`${right}/`));
}

/**
 * DOMAIN STATE → SEMANTIC WORLD MODEL.
 * Grounds vs project interior. Characters only for proven jobs.
 * Memory archive only when the typed memory API exists (omit on 404).
 * Workspace files open the Workspace Files panel (GET /api/v1/files).
 * Operations and Settings are shared commons places (also on the dock).
 * Library is the capability/catalog inspector destination.
 */
export function buildWorldModel(input: WorldDomainInput): WorldModel {
  const focus = input.focusProjectId?.trim() || null;
  const entities = focus ? buildInterior(input, focus) : buildGrounds(input);

  return {
    workspacePath: input.workspacePath,
    workspaceLabel: workspaceLabel(input.workspacePath),
    focusProjectId: focus,
    entities,
  };
}
