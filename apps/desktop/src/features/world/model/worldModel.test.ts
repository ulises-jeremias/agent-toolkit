import { describe, expect, it } from 'vitest';
import { buildWorldModel, jobBelongsToProject } from './buildWorld';
import { layoutWorld } from './layout';
import { parseProjectListMessage } from './parseProjects';
import type { MemoryEntryRecord, MemorySummary, ToolRecord, WorldDomainInput } from './types';

function emptyMemory(available: boolean, entries: MemoryEntryRecord[] = []): MemorySummary {
  const projectKeys = [...new Set(entries.map((entry) => entry.provenance.project).filter(Boolean))];
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

function baseInput(overrides: Partial<WorldDomainInput> = {}): WorldDomainInput {
  return {
    workspacePath: '/ws',
    projects: [],
    projectsKnown: true,
    memory: emptyMemory(false),
    tools: [],
    toolsKnown: false,
    jobs: [],
    ...overrides,
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

describe('jobBelongsToProject', () => {
  it('matches by target path and by project name segment', () => {
    const project = { name: 'alpha', target: '/repos/alpha', status: 'ok' as const };
    expect(jobBelongsToProject({ workspace: '/repos/alpha' }, project)).toBe(true);
    expect(jobBelongsToProject({ workspace: '/repos/alpha/src' }, project)).toBe(true);
    expect(jobBelongsToProject({ workspace: '/ws/projects/alpha' }, project)).toBe(true);
    expect(jobBelongsToProject({ workspace: '/repos/beta' }, project)).toBe(false);
  });
});

describe('buildWorldModel', () => {
  it('builds grounds with memory archive and job characters', () => {
    const model = buildWorldModel(
      baseInput({
        workspacePath: '/home/me/.ai-workspace',
        projects: [
          { name: 'alpha', target: '/r/alpha', status: 'ok' },
          { name: 'beta', target: '/r/beta', status: 'ok' },
        ],
        memory: emptyMemory(true, [
          entry({
            id: 'learnings/a.md',
            title: 'Alpha note',
            provenance: {
              file: 'knowledge/learnings/a.md',
              author: 'me',
              timestamp: '2026-01-01',
              project: 'alpha',
              agent: '',
            },
          }),
        ]),
        jobs: [
          { id: 'j1', cmd: 'doctor', args: [], status: 'running', workspace: '/r/alpha' },
          { id: 'j2', cmd: 'install', args: [], status: 'completed', workspace: '/home/me/.ai-workspace' },
          { id: 'j3', cmd: 'build', args: [], status: 'failed', workspace: '/r/beta' },
        ],
      }),
    );

    const ids = model.entities.map((e) => e.id);
    expect(ids).toContain('place:workspace');
    expect(ids).toContain('place:memory');
    expect(ids).toContain('place:project:alpha');
    expect(ids).toContain('place:project:beta');
    expect(ids).toContain('character:job:j1');
    expect(ids).toContain('character:job:j3');
    expect(ids).not.toContain('character:job:j2');
    expect(ids).not.toContain('object:exit-grounds');
    expect(ids).not.toContain('place:knowledge-workspace');
    expect(model.entities.find((e) => e.id === 'object:library')?.hrefPath).toBe('/library');
    expect(model.entities.find((e) => e.id === 'object:library')?.concept).toBe('Capability library');
    expect(model.entities.find((e) => e.id === 'place:project:alpha')?.activity).toBe('working');
    expect(model.entities.find((e) => e.id === 'place:project:beta')?.activity).toBe('blocked');
    expect(model.entities.find((e) => e.id === 'character:job:j1')?.projectId).toBe('alpha');
  });

  it('shows a memory location when the endpoint is present', () => {
    const model = buildWorldModel(
      baseInput({
        memory: emptyMemory(true, [entry({ id: 'x.md', title: 'One' })]),
      }),
    );
    const memory = model.entities.find((e) => e.id === 'place:memory');
    expect(memory?.concept).toBe('Memory archive');
    expect(memory?.themeKey).toBe('memory.index');
    expect(model.entities.map((e) => e.id)).not.toContain('place:knowledge-workspace');
  });

  it('omits the memory location when the endpoint 404s / is unavailable', () => {
    const model = buildWorldModel(baseInput({ memory: emptyMemory(false) }));
    const ids = model.entities.map((e) => e.id);
    expect(ids).not.toContain('place:memory');
    expect(ids).not.toContain('place:knowledge-workspace');
    expect(ids).toContain('object:library');
  });

  it('shows an honest empty archive with zero fake items when the list is empty', () => {
    const model = buildWorldModel(
      baseInput({
        projects: [{ name: 'only', target: '/r', status: 'ok' }],
        memory: emptyMemory(true, []),
      }),
    );
    const memory = model.entities.find((e) => e.id === 'place:memory');
    expect(memory?.state).toBe('empty');
    expect(model.entities.filter((e) => e.id.startsWith('object:memory:'))).toEqual([]);
  });

  it('opens a project interior with memory, terminal, and detected tools only', () => {
    const tools: ToolRecord[] = [
      {
        id: 'cursor',
        toolName: 'Cursor',
        detected: true,
        configured: true,
        enabled: 'true',
        verified: false,
        version: '1.0',
      },
      {
        id: 'ghost',
        toolName: 'Ghost',
        detected: false,
        configured: false,
        enabled: 'unknown',
        verified: false,
        version: '',
      },
    ];
    const model = buildWorldModel(
      baseInput({
        projects: [
          { name: 'alpha', target: '/r/alpha', status: 'ok' },
          { name: 'beta', target: '/r/beta', status: 'ok' },
        ],
        memory: emptyMemory(true, [
          entry({
            id: 'p.md',
            title: 'Scoped',
            provenance: { file: 'p.md', author: '', timestamp: '', project: 'alpha', agent: '' },
          }),
          entry({
            id: 'other.md',
            title: 'Other',
            provenance: { file: 'o.md', author: '', timestamp: '', project: 'beta', agent: '' },
          }),
        ]),
        tools,
        toolsKnown: true,
        jobs: [{ id: 'j1', cmd: 'test', args: [], status: 'running', workspace: '/r/alpha' }],
        focusProjectId: 'alpha',
      }),
    );
    const ids = model.entities.map((e) => e.id);
    expect(ids).toContain('object:exit-grounds');
    expect(ids).toContain('place:project:alpha');
    expect(ids).toContain('place:memory-project:alpha');
    expect(ids).not.toContain('place:knowledge-project:alpha');
    expect(ids).toContain('object:memory:p.md');
    expect(ids).not.toContain('object:memory:other.md');
    expect(ids).toContain('object:terminal-project:alpha');
    expect(ids).toContain('object:tool:cursor');
    expect(ids).not.toContain('object:tool:ghost');
    expect(ids).not.toContain('place:project:beta');
    expect(ids).not.toContain('object:library');
    expect(ids).not.toContain('place:memory');
    expect(ids).not.toContain('place:knowledge-workspace');
    expect(ids).toContain('character:job:j1');
    expect(model.entities.find((e) => e.id === 'place:project:alpha')?.concept).toBe('Project interior');
  });

  it('keeps interiors calm with no fake tools or characters', () => {
    const model = buildWorldModel(
      baseInput({
        projects: [{ name: 'only', target: '/r', status: 'ok' }],
        memory: emptyMemory(true, []),
        tools: [],
        toolsKnown: true,
        focusProjectId: 'only',
      }),
    );
    expect(model.entities.filter((e) => e.kind === 'character')).toEqual([]);
    expect(model.entities.find((e) => e.id === 'object:tools-empty')?.availability).toBe('empty');
    expect(model.entities.find((e) => e.id === 'place:project:only')?.activity).toBe('calm');
  });

  it('never invents characters without jobs on the grounds', () => {
    const model = buildWorldModel(
      baseInput({
        projects: [{ name: 'only', target: '/r', status: 'ok' }],
        memory: emptyMemory(true, []),
      }),
    );
    expect(model.entities.filter((e) => e.kind === 'character')).toEqual([]);
    expect(model.entities.find((e) => e.id === 'place:project:only')?.activity).toBe('calm');
  });
});

describe('layoutWorld', () => {
  it('is deterministic for the same projects and jobs', () => {
    const input = baseInput({
      projects: [
        { name: 'c', target: '/c', status: 'ok' },
        { name: 'a', target: '/a', status: 'ok' },
        { name: 'b', target: '/b', status: 'ok' },
      ],
      memory: emptyMemory(true, []),
      jobs: [
        { id: 'j2', cmd: 'x', args: [], status: 'running', workspace: '/a' },
        { id: 'j1', cmd: 'y', args: [], status: 'queued', workspace: '/ws' },
      ],
    });
    const a = layoutWorld(buildWorldModel(input));
    const b = layoutWorld(buildWorldModel(input));
    expect(a.entities.map((e) => ({ id: e.id, x: e.x, y: e.y }))).toEqual(
      b.entities.map((e) => ({ id: e.id, x: e.x, y: e.y })),
    );
  });

  it('keeps stable house slots when project count grows', () => {
    const one = layoutWorld(
      buildWorldModel(
        baseInput({
          projects: [{ name: 'a', target: '/a', status: 'ok' }],
        }),
      ),
    );
    const five = layoutWorld(
      buildWorldModel(
        baseInput({
          projects: ['a', 'b', 'c', 'd', 'e'].map((name) => ({
            name,
            target: `/${name}`,
            status: 'ok' as const,
          })),
        }),
      ),
    );
    const a1 = one.entities.find((e) => e.id === 'place:project:a');
    const a5 = five.entities.find((e) => e.id === 'place:project:a');
    expect(a1 && a5).toBeTruthy();
    expect({ x: a1!.x, y: a1!.y }).toEqual({ x: a5!.x, y: a5!.y });
  });

  it('lays out an interior without outdoor library annex', () => {
    const layout = layoutWorld(
      buildWorldModel(
        baseInput({
          projects: [{ name: 'alpha', target: '/r/alpha', status: 'ok' }],
          memory: emptyMemory(true, []),
          toolsKnown: true,
          tools: [
            {
              id: 'gh',
              toolName: 'gh',
              detected: true,
              configured: true,
              enabled: 'true',
              verified: true,
              version: '2',
            },
          ],
          focusProjectId: 'alpha',
        }),
      ),
    );
    const ids = layout.entities.map((e) => e.id);
    expect(ids).toContain('object:exit-grounds');
    expect(ids).toContain('object:tool:gh');
    expect(ids).not.toContain('object:library');
    const exit = layout.entities.find((e) => e.id === 'object:exit-grounds');
    const room = layout.entities.find((e) => e.id === 'place:project:alpha');
    expect(exit && room).toBeTruthy();
    expect(exit!.x).toBe(0);
    expect(room!.x).toBeGreaterThan(exit!.x);
  });
});
