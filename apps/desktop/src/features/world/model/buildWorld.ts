import { isTerminalJobStatus } from '../../../lib/api';
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

function houseState(project: ProjectRecord, activity: PlaceActivity, jobCount: number): string {
  if (project.status === 'broken') return 'broken';
  if (activity === 'working') return `${jobCount} active`;
  if (activity === 'blocked') return 'needs attention';
  return 'calm';
}

function visibleTools(tools: ToolRecord[]): ToolRecord[] {
  // Only tools the API actually detected — never invent rack slots.
  return tools.filter((tool) => tool.detected).sort((a, b) => a.id.localeCompare(b.id));
}

function pushJobCharacters(entities: SemanticEntity[], jobs: WorldDomainInput['jobs'], projectId?: string): void {
  for (const job of jobs) {
    const active = !isTerminalJobStatus(job.status);
    const blocked = job.status === 'failed' || job.status === 'rejected';
    if (!active && !blocked) continue;
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
      projectId,
      detail: `Job ${job.id}`,
      activity: blocked ? 'blocked' : 'working',
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
  });

  if (input.memory.available) {
    const count = input.memory.entries.length;
    entities.push({
      id: 'place:memory',
      kind: 'place',
      concept: 'Memory archive',
      name: 'Memory archive',
      state: count > 0 ? `${count} records` : 'empty',
      themeKey: 'memory.index',
      availability: count > 0 ? 'present' : 'empty',
      hrefPath: '/workspace',
      detail:
        count > 0
          ? `${count} memory record${count === 1 ? '' : 's'} (typed memory API)`
          : 'Memory API reachable; archive is empty',
    });

    entities.push({
      id: 'object:memory-index',
      kind: 'object',
      concept: 'Memory search / hits',
      name: 'Card index',
      state: count > 0 ? 'ready' : 'empty',
      themeKey: 'memory.index',
      availability: count > 0 ? 'present' : 'empty',
      hrefPath: '/workspace',
      detail: 'Search memory hits via GET /api/v1/memory/hits',
    });
  }

  // Knowledge annex — catalog inspector, independent of the memory API.
  entities.push({
    id: 'place:knowledge-workspace',
    kind: 'place',
    concept: 'Shared knowledge',
    name: 'Shared knowledge',
    state: 'catalog',
    themeKey: 'knowledge.workspace',
    availability: 'present',
    hrefPath: '/library',
    detail: 'Library inspector · catalog knowledge, not memory',
  });

  entities.push({
    id: 'object:terminal',
    kind: 'object',
    concept: 'Terminal / PTY workstation',
    name: 'Terminal',
    state: 'ready',
    themeKey: 'tool.terminal',
    availability: 'present',
    hrefPath: '/terminal',
    detail: 'Open the Terminal destination or dock',
  });

  entities.push({
    id: 'object:library',
    kind: 'object',
    concept: 'Shared knowledge inspector',
    name: 'Library annex',
    state: 'catalog',
    themeKey: 'capability.shelf',
    availability: 'present',
    hrefPath: '/library',
    detail: 'Catalog knowledge the world opens here',
  });

  entities.push({
    id: 'object:attention',
    kind: 'object',
    concept: 'Attention inbox',
    name: 'Needs you',
    state: 'inspector',
    themeKey: 'attention.inbox',
    availability: 'present',
    hrefPath: '/office',
    detail: 'Failures and blocked work',
  });

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
      detail: 'Run project clone / add, or open Workspace',
    });
  } else {
    for (const project of input.projects) {
      const projectJobs = input.jobs.filter((job) => jobBelongsToProject(job, project));
      const activity = activityForJobs(projectJobs);
      const liveCount = projectJobs.filter(
        (job) => !isTerminalJobStatus(job.status) || job.status === 'failed' || job.status === 'rejected',
      ).length;
      entities.push({
        id: `place:project:${project.name}`,
        kind: 'place',
        concept: 'Project',
        name: project.name,
        state: houseState(project, activity, liveCount),
        themeKey: 'project.building',
        availability: 'present',
        hrefPath: '/world',
        hrefExtra: { project: project.name },
        projectId: project.name,
        detail: `${project.status} → ${project.target}${liveCount ? ` · ${liveCount} job(s)` : ''}`,
        activity,
      });

      // Characters stand at the house when the job belongs to this project.
      pushJobCharacters(entities, projectJobs, project.name);
    }
  }

  // Workspace-scoped jobs (no project match) still appear on the grounds.
  const unmatched = input.jobs.filter((job) => !input.projects.some((project) => jobBelongsToProject(job, project)));
  pushJobCharacters(entities, unmatched);

  return entities;
}

/**
 * Project interior — inside one house. Not a dashboard: only places backed by
 * real capabilities for this project (memory API, terminal, detected tools, jobs).
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
  const activity = activityForJobs(projectJobs);
  const liveCount = projectJobs.filter(
    (job) => !isTerminalJobStatus(job.status) || job.status === 'failed' || job.status === 'rejected',
  ).length;

  entities.push({
    id: `place:project:${project.name}`,
    kind: 'place',
    concept: 'Project interior',
    name: project.name,
    state: houseState(project, activity, liveCount),
    themeKey: 'project.building',
    availability: 'present',
    hrefPath: '/workspace',
    projectId: project.name,
    detail: `${project.status} → ${project.target}`,
    activity,
  });

  if (input.memory.available) {
    const scoped = input.memory.entries.filter((entry) => entry.provenance.project === project.name);
    entities.push({
      id: `place:memory-project:${project.name}`,
      kind: 'place',
      concept: 'Project memory records',
      name: 'Records',
      state: scoped.length > 0 ? `${scoped.length} records` : 'empty',
      themeKey: 'memory.index',
      availability: scoped.length > 0 ? 'present' : 'empty',
      hrefPath: '/workspace',
      projectId: project.name,
      detail:
        scoped.length > 0
          ? `${scoped.length} memory record${scoped.length === 1 ? '' : 's'} for this project`
          : 'Memory API reachable; no records scoped to this project',
    });

    for (const entry of scoped) {
      entities.push({
        id: `object:memory:${entry.id}`,
        kind: 'object',
        concept: 'Memory entry',
        name: entry.title || entry.id,
        state: entry.kind || 'listed',
        themeKey: 'memory.entry',
        availability: 'present',
        hrefPath: '/workspace',
        projectId: project.name,
        detail: provenanceDetail(entry),
      });
    }
  }

  entities.push({
    id: `place:knowledge-project:${project.name}`,
    kind: 'place',
    concept: 'Project knowledge',
    name: 'Knowledge',
    state: 'catalog',
    themeKey: 'knowledge.project',
    availability: 'present',
    hrefPath: '/library',
    projectId: project.name,
    detail: 'Library inspector · catalog knowledge, not memory',
  });

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
  });

  if (input.toolsKnown) {
    const tools = visibleTools(input.tools);
    if (tools.length === 0) {
      entities.push({
        id: 'object:tools-empty',
        kind: 'marker',
        concept: 'Coding tools',
        name: 'No tools detected',
        state: 'empty',
        themeKey: 'tool.coding',
        availability: 'empty',
        hrefPath: '/library',
        projectId: project.name,
        detail: 'GET /api/v1/tools returned no detected CLIs',
      });
    } else {
      for (const tool of tools) {
        const bits = [
          tool.detected ? 'detected' : '',
          tool.configured ? 'configured' : '',
          tool.verified ? 'verified' : '',
          tool.version || '',
        ].filter(Boolean);
        entities.push({
          id: `object:tool:${tool.id}`,
          kind: 'object',
          concept: 'Coding tool',
          name: tool.toolName || tool.id,
          state: bits.join(' · ') || 'detected',
          themeKey: 'tool.coding',
          availability: 'present',
          hrefPath: '/library',
          projectId: project.name,
          detail: tool.id,
        });
      }
    }
  }

  pushJobCharacters(entities, projectJobs, project.name);

  return entities;
}

/**
 * DOMAIN STATE → SEMANTIC WORLD MODEL.
 * Grounds vs project interior. Characters only for proven jobs.
 * Memory archive only when the typed memory API exists (omit on 404).
 * Shared knowledge opens the Library inspector — never a fake memory UI.
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
