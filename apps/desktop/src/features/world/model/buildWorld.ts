import { isTerminalJobStatus } from '../../../lib/api';
import type { MemoryEntryRecord, SemanticEntity, WorldDomainInput, WorldModel } from './types';

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

/**
 * DOMAIN STATE → SEMANTIC WORLD MODEL.
 * Characters only for proven jobs. Memory archive only when the typed
 * memory API exists (omit on 404). Knowledge stays the Library annex —
 * never collapse memory into knowledge.
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

    // Card index — retrieval surface for GET /api/v1/memory/hits.
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

    for (const entry of input.memory.entries) {
      entities.push({
        id: `object:memory:${entry.id}`,
        kind: 'object',
        concept: 'Memory entry',
        name: entry.title || entry.id,
        state: entry.kind || 'listed',
        themeKey: 'memory.entry',
        availability: 'present',
        hrefPath: '/workspace',
        projectId: entry.provenance.project || undefined,
        detail: provenanceDetail(entry),
      });
    }
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

  // Library stays capabilities — not memory.
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
        const projectMemory = input.memory.available
          ? input.memory.entries.some((entry) => entry.provenance.project === project.name)
          : false;
        if (input.memory.available) {
          entities.push({
            id: `place:memory-project:${project.name}`,
            kind: 'place',
            concept: 'Project memory records',
            name: `${project.name} records`,
            state: projectMemory ? 'present' : 'empty',
            themeKey: 'memory.entry',
            availability: projectMemory ? 'present' : 'empty',
            hrefPath: '/workspace',
            projectId: project.name,
            detail: projectMemory
              ? 'Memory entries reference this project'
              : 'No memory records scoped to this project',
          });
        }
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
