import { isTerminalJobStatus } from '../../../lib/api';
import type { SemanticEntity, WorldDomainInput, WorldModel } from './types';

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

/**
 * DOMAIN STATE → SEMANTIC WORLD MODEL.
 * Characters only for proven jobs. Knowledge places only when memory API
 * evidence exists (or honest empty after a successful empty list).
 */
export function buildWorldModel(input: WorldDomainInput): WorldModel {
  const focus = input.focusProjectId?.trim() || null;
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
    entities.push({
      id: 'place:knowledge-workspace',
      kind: 'place',
      concept: 'Workspace knowledge / memory',
      name: 'Shared knowledge',
      state: input.memory.entryCount > 0 ? `${input.memory.entryCount} entries` : 'empty',
      themeKey: 'knowledge.workspace',
      availability: input.memory.entryCount > 0 ? 'present' : 'empty',
      hrefPath: '/workspace',
      detail:
        input.memory.entryCount > 0
          ? `${input.memory.entryCount} memory file${input.memory.entryCount === 1 ? '' : 's'}`
          : 'Memory API reachable; no entries yet',
    });
  }

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
    concept: 'Capability library',
    name: 'Library annex',
    state: 'catalog',
    themeKey: 'capability.shelf',
    availability: 'present',
    hrefPath: '/library',
    detail: 'Skills, agents, packs',
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
      if (focus && project.name !== focus) continue;
      entities.push({
        id: `place:project:${project.name}`,
        kind: 'place',
        concept: 'Project',
        name: project.name,
        state: project.status,
        themeKey: 'project.building',
        availability: 'present',
        hrefPath: '/world',
        hrefExtra: { project: project.name },
        projectId: project.name,
        detail: `${project.status} → ${project.target}`,
      });

      if (focus === project.name) {
        const projectMemory = input.memory.available ? input.memory.projectKeys.includes(project.name) : false;
        entities.push({
          id: `place:knowledge-project:${project.name}`,
          kind: 'place',
          concept: 'Project knowledge / memory',
          name: `${project.name} knowledge`,
          state: !input.memory.available ? 'unavailable' : projectMemory ? 'present' : 'empty',
          themeKey: 'knowledge.project',
          availability: !input.memory.available ? 'unavailable' : projectMemory ? 'present' : 'empty',
          hrefPath: '/workspace',
          projectId: project.name,
          detail: !input.memory.available
            ? 'Memory API unavailable'
            : projectMemory
              ? 'Memory entries reference this project'
              : 'No memory entries scoped to this project',
        });
        entities.push({
          id: `object:terminal-project:${project.name}`,
          kind: 'object',
          concept: 'Project terminal',
          name: `${project.name} terminal`,
          state: 'ready',
          themeKey: 'tool.terminal',
          availability: 'present',
          hrefPath: '/terminal',
          projectId: project.name,
          detail: 'Open Terminal in this session',
        });
      }
    }
  }

  for (const job of input.jobs) {
    // Characters only for proven runtime rows that still need presence, or
    // recent failures that map to blocked (Operations still owns the table).
    const active = !isTerminalJobStatus(job.status);
    const blocked = job.status === 'failed' || job.status === 'rejected';
    if (!active && !blocked) continue;
    if (focus && job.workspace && !job.workspace.includes(focus) && job.workspace !== input.workspacePath) {
      // Keep job visible at workspace scope; project focus only filters when
      // the job workspace path clearly names another project folder.
    }
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
      detail: `Job ${job.id}`,
    });
  }

  return {
    workspacePath: input.workspacePath,
    workspaceLabel: workspaceLabel(input.workspacePath),
    focusProjectId: focus,
    entities,
  };
}
