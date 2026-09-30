import { describe, expect, it } from 'vitest';
import { buildWorldModel } from './buildWorld';
import { layoutWorld } from './layout';
import { parseProjectListMessage } from './parseProjects';
import type { MemoryEntryRecord, MemorySummary } from './types';

function emptyMemory(available: boolean, entries: MemoryEntryRecord[] = []): MemorySummary {
  const projectKeys = [
    ...new Set(entries.map((entry) => entry.provenance.project).filter(Boolean)),
  ];
  return { available, entries, projectKeys };
}

function entry(partial: Partial<MemoryEntryRecord> & Pick<MemoryEntryRecord, 'id' | 'title'>): MemoryEntryRecord {
  const { provenance: provenancePartial, ...rest } = partial;
  return {
    kind: 'learning',
    snippet: '',
    tags: [],
    ...rest,
    provenance: {
      file: '',
      author: '',
      timestamp: '',
      project: '',
      agent: '',
      ...provenancePartial,
    },
  };
}

describe('parseProjectListMessage', () => {
  it('parses ok and broken rows and sorts by name', () => {
    const message = `
=== Projects ===

  [ok]  zebra -> /repos/zebra
  [broken]  alpha -> /missing/alpha
  (noise)
`;
    expect(parseProjectListMessage(message)).toEqual([
      { name: 'alpha', target: '/missing/alpha', status: 'broken' },
      { name: 'zebra', target: '/repos/zebra', status: 'ok' },
    ]);
  });
});

describe('buildWorldModel', () => {
  it('builds grounds, projects, memory archive, and job characters only', () => {
    const model = buildWorldModel({
      workspacePath: '/home/me/.ai-workspace',
      projects: [
        { name: 'alpha', target: '/r/alpha', status: 'ok' },
        { name: 'beta', target: '/r/beta', status: 'ok' },
      ],
      projectsKnown: true,
      memory: emptyMemory(true, [
        entry({
          id: 'learnings/a.md',
          title: 'Alpha note',
          provenance: { file: 'knowledge/learnings/a.md', author: 'me', timestamp: '2026-01-01', project: 'alpha', agent: '' },
        }),
        entry({ id: 'learnings/b.md', title: 'Beta note' }),
        entry({ id: 'learnings/c.md', title: 'Gamma note' }),
      ]),
      jobs: [
        { id: 'j1', cmd: 'doctor', args: [], status: 'running', workspace: '/home/me/.ai-workspace' },
        { id: 'j2', cmd: 'install', args: [], status: 'completed', workspace: '/home/me/.ai-workspace' },
        { id: 'j3', cmd: 'build', args: [], status: 'failed', workspace: '/home/me/.ai-workspace' },
      ],
    });

    const ids = model.entities.map((e) => e.id);
    expect(ids).toContain('place:workspace');
    expect(ids).toContain('place:memory');
    expect(ids).toContain('object:memory-index');
    expect(ids).toContain('object:memory:learnings/a.md');
    expect(ids).toContain('place:project:alpha');
    expect(ids).toContain('place:project:beta');
    expect(ids).toContain('character:job:j1');
    expect(ids).toContain('character:job:j3');
    expect(ids).not.toContain('character:job:j2');
    expect(ids).not.toContain('place:knowledge-workspace');
    expect(model.entities.find((e) => e.id === 'place:memory')?.themeKey).toBe('memory.index');
    expect(model.entities.find((e) => e.id === 'object:library')?.themeKey).toBe('capability.shelf');
    expect(model.entities.find((e) => e.id === 'character:job:j1')?.themeKey).toBe('agent.working');
    expect(model.entities.find((e) => e.id === 'character:job:j3')?.themeKey).toBe('agent.blocked');
    expect(model.entities.find((e) => e.id === 'object:memory:learnings/a.md')?.detail).toContain('project alpha');
  });

  it('shows a memory location when the endpoint is present', () => {
    const model = buildWorldModel({
      workspacePath: '/ws',
      projects: [],
      projectsKnown: true,
      memory: emptyMemory(true, [entry({ id: 'x.md', title: 'One' })]),
      jobs: [],
    });
    const memory = model.entities.find((e) => e.id === 'place:memory');
    expect(memory).toBeTruthy();
    expect(memory?.concept).toBe('Memory archive');
    expect(memory?.availability).toBe('present');
    expect(memory?.themeKey).toBe('memory.index');
  });

  it('omits the memory location when the endpoint 404s / is unavailable', () => {
    const model = buildWorldModel({
      workspacePath: '/ws',
      projects: [],
      projectsKnown: true,
      memory: emptyMemory(false),
      jobs: [],
    });
    const ids = model.entities.map((e) => e.id);
    expect(ids).not.toContain('place:memory');
    expect(ids).not.toContain('object:memory-index');
    expect(ids.filter((id) => id.startsWith('object:memory:'))).toEqual([]);
    expect(ids).toContain('place:projects-empty');
    expect(ids).toContain('object:library');
  });

  it('shows an honest empty archive with zero fake items when the list is empty', () => {
    const model = buildWorldModel({
      workspacePath: '/ws',
      projects: [{ name: 'only', target: '/r', status: 'ok' }],
      projectsKnown: true,
      memory: emptyMemory(true, []),
      jobs: [],
    });
    const memory = model.entities.find((e) => e.id === 'place:memory');
    expect(memory?.state).toBe('empty');
    expect(memory?.availability).toBe('empty');
    expect(model.entities.filter((e) => e.id.startsWith('object:memory:'))).toEqual([]);
    expect(model.entities.filter((e) => e.kind === 'character')).toEqual([]);
  });

  it('enters a project space with memory records and terminal representations', () => {
    const model = buildWorldModel({
      workspacePath: '/ws',
      projects: [{ name: 'alpha', target: '/r/alpha', status: 'ok' }],
      projectsKnown: true,
      memory: emptyMemory(true, [
        entry({
          id: 'p.md',
          title: 'Scoped',
          provenance: { file: 'p.md', author: '', timestamp: '', project: 'alpha', agent: '' },
        }),
      ]),
      jobs: [],
      focusProjectId: 'alpha',
    });
    const ids = model.entities.map((e) => e.id);
    expect(ids).toContain('place:project:alpha');
    expect(ids).not.toContain('place:project:beta');
    expect(ids).toContain('place:memory-project:alpha');
    expect(ids).not.toContain('place:knowledge-project:alpha');
    expect(ids).toContain('object:terminal-project:alpha');
  });

  it('never invents characters without jobs', () => {
    const model = buildWorldModel({
      workspacePath: '/ws',
      projects: [{ name: 'only', target: '/r', status: 'ok' }],
      projectsKnown: true,
      memory: emptyMemory(true, []),
      jobs: [],
    });
    expect(model.entities.filter((e) => e.kind === 'character')).toEqual([]);
  });
});

describe('layoutWorld', () => {
  it('is deterministic for the same projects and jobs', () => {
    const input = {
      workspacePath: '/ws',
      projects: [
        { name: 'c', target: '/c', status: 'ok' as const },
        { name: 'a', target: '/a', status: 'ok' as const },
        { name: 'b', target: '/b', status: 'ok' as const },
      ],
      projectsKnown: true,
      memory: emptyMemory(true, []),
      jobs: [
        { id: 'j2', cmd: 'x', args: [], status: 'running', workspace: '/ws' },
        { id: 'j1', cmd: 'y', args: [], status: 'queued', workspace: '/ws' },
      ],
    };
    const a = layoutWorld(buildWorldModel(input));
    const b = layoutWorld(buildWorldModel(input));
    expect(a.entities.map((e) => ({ id: e.id, x: e.x, y: e.y }))).toEqual(
      b.entities.map((e) => ({ id: e.id, x: e.x, y: e.y })),
    );
  });

  it('keeps stable slots when project count grows', () => {
    const one = layoutWorld(
      buildWorldModel({
        workspacePath: '/ws',
        projects: [{ name: 'a', target: '/a', status: 'ok' }],
        projectsKnown: true,
        memory: emptyMemory(false),
        jobs: [],
      }),
    );
    const five = layoutWorld(
      buildWorldModel({
        workspacePath: '/ws',
        projects: ['a', 'b', 'c', 'd', 'e'].map((name) => ({ name, target: `/${name}`, status: 'ok' as const })),
        projectsKnown: true,
        memory: emptyMemory(false),
        jobs: [],
      }),
    );
    const a1 = one.entities.find((e) => e.id === 'place:project:a');
    const a5 = five.entities.find((e) => e.id === 'place:project:a');
    expect(a1 && a5).toBeTruthy();
    expect({ x: a1!.x, y: a1!.y }).toEqual({ x: a5!.x, y: a5!.y });
  });
});
