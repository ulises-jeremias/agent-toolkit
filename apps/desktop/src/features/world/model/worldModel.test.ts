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
  it('surfaces harness notices on the workspace grounds tile', () => {
    const model = buildWorldModel(
      baseInput({
        workspacePath: '/tmp/fallback-cwd',
        harnessNotice: 'Default harness /home/me/.ai-workspace not found; serve starts in /tmp/fallback-cwd',
      }),
    );
    const grounds = model.entities.find((e) => e.id === 'place:workspace');
    expect(grounds?.state).toBe('notice');
    expect(grounds?.detail).toContain('Default harness');
  });

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
    expect(ids).not.toContain('character:job:j3');
    expect(ids).not.toContain('character:job:j2');
    expect(ids).not.toContain('object:exit-grounds');
    expect(ids).not.toContain('place:knowledge-workspace');
    expect(model.entities.find((e) => e.id === 'object:library')?.hrefPath).toBe('/library');
    expect(model.entities.find((e) => e.id === 'object:library')?.concept).toBe('Capability library');
    expect(model.entities.find((e) => e.id === 'object:library')?.kind).toBe('place');
    expect(model.entities.find((e) => e.id === 'object:library')?.facade).toBe('landmark-library');
    expect(model.entities.find((e) => e.id === 'object:operations')?.facade).toBe('landmark-operations');
    expect(model.entities.find((e) => e.id === 'place:project:alpha')?.facade).toMatch(/^house-/);
    expect(model.entities.find((e) => e.id === 'place:project:alpha')?.activity).toBe('working');
    expect(model.entities.find((e) => e.id === 'place:project:beta')?.activity).toBe('blocked');
    expect(model.entities.find((e) => e.id === 'character:job:j1')?.projectId).toBe('alpha');
    // Project-scoped memory stays off the world archive (partition).
    expect(model.entities.find((e) => e.id === 'place:memory')?.state).toBe('empty');
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

  it('caps workspace memory ledgers on the grounds so the campus stays scannable', () => {
    const entries = [1, 2, 3, 4, 5].map((n) =>
      entry({
        id: `ws/${n}.md`,
        title: `Note ${n}`,
        provenance: { file: `knowledge/${n}.md`, author: '', timestamp: '', project: '', agent: '' },
      }),
    );
    const model = buildWorldModel(
      baseInput({
        memory: emptyMemory(true, entries),
      }),
    );
    expect(model.entities.find((e) => e.id === 'place:memory')?.state).toBe('5 records');
    expect(model.entities.filter((e) => e.id.startsWith('object:memory:'))).toHaveLength(3);
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

  it('locks house activity to real API job statuses', () => {
    const projects = [
      { name: 'alpha', target: '/r/alpha', status: 'ok' as const },
      { name: 'beta', target: '/r/beta', status: 'ok' as const },
      { name: 'gamma', target: '/r/gamma', status: 'ok' as const },
      { name: 'delta', target: '/r/delta', status: 'ok' as const },
    ];
    const model = buildWorldModel(
      baseInput({
        projects,
        jobs: [
          { id: 'q1', cmd: 'lint', args: [], status: 'queued', workspace: '/r/alpha' },
          { id: 'r1', cmd: 'test', args: [], status: 'running', workspace: '/r/beta' },
          { id: 'f1', cmd: 'build', args: [], status: 'failed', workspace: '/r/gamma' },
          { id: 'x1', cmd: 'ship', args: [], status: 'rejected', workspace: '/r/delta' },
          { id: 'c1', cmd: 'done', args: [], status: 'completed', workspace: '/r/alpha' },
          { id: 'z1', cmd: 'stop', args: [], status: 'canceled', workspace: '/r/beta' },
        ],
      }),
    );

    const byId = Object.fromEntries(model.entities.map((e) => [e.id, e]));

    // queued / running → character + working lamp at that house
    expect(byId['character:job:q1']?.themeKey).toBe('agent.working');
    expect(byId['character:job:q1']?.projectId).toBe('alpha');
    expect(byId['character:job:q1']?.hrefPath).toBe('/operations');
    expect(byId['place:project:alpha']?.activity).toBe('working');
    expect(byId['place:project:alpha']?.hrefPath).toBe('/world');

    expect(byId['character:job:r1']?.themeKey).toBe('agent.working');
    expect(byId['place:project:beta']?.activity).toBe('working');

    // Failed work marks the house for attention; no finished process remains as a character.
    expect(byId['character:job:f1']).toBeUndefined();
    expect(byId['place:project:gamma']?.activity).toBe('blocked');
    expect(byId['place:project:gamma']?.state).toBe('needs attention');
    expect(byId['place:project:gamma']?.hrefPath).toBe('/world');
    expect(byId['place:project:gamma']?.hrefExtra).toEqual({ project: 'gamma' });

    expect(byId['character:job:x1']).toBeUndefined();
    expect(byId['place:project:delta']?.hrefPath).toBe('/world');

    // completed / canceled → no character (calm wins only when no live jobs)
    expect(byId['character:job:c1']).toBeUndefined();
    expect(byId['character:job:z1']).toBeUndefined();
  });

  it('stays calm for completed and canceled when nothing else is live', () => {
    const model = buildWorldModel(
      baseInput({
        projects: [{ name: 'solo', target: '/r/solo', status: 'ok' }],
        jobs: [
          { id: 'c1', cmd: 'a', args: [], status: 'completed', workspace: '/r/solo' },
          { id: 'z1', cmd: 'b', args: [], status: 'canceled', workspace: '/r/solo' },
        ],
      }),
    );
    expect(model.entities.filter((e) => e.kind === 'character')).toEqual([]);
    expect(model.entities.find((e) => e.id === 'place:project:solo')?.activity).toBe('calm');
    expect(model.entities.find((e) => e.id === 'place:project:solo')?.hrefPath).toBe('/world');
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

  it('keeps stable house slots when project count grows past √n thresholds', () => {
    const names9 = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i'];
    const names10 = [...names9, 'j'];
    const nine = layoutWorld(
      buildWorldModel(
        baseInput({
          projects: names9.map((name) => ({ name, target: `/${name}`, status: 'ok' as const })),
        }),
      ),
    );
    const ten = layoutWorld(
      buildWorldModel(
        baseInput({
          projects: names10.map((name) => ({ name, target: `/${name}`, status: 'ok' as const })),
        }),
      ),
    );
    for (const name of names9) {
      const left = nine.entities.find((e) => e.id === `place:project:${name}`);
      const right = ten.entities.find((e) => e.id === `place:project:${name}`);
      expect({ id: name, x: left!.x, y: left!.y }).toEqual({ id: name, x: right!.x, y: right!.y });
    }
  });

  it('lays projects on a fixed-width district under the commons strip', () => {
    const layout = layoutWorld(
      buildWorldModel(
        baseInput({
          projects: ['a', 'b', 'c', 'd', 'e'].map((name) => ({
            name,
            target: `/${name}`,
            status: 'ok' as const,
          })),
          memory: emptyMemory(true, []),
        }),
      ),
    );
    const a = layout.entities.find((e) => e.id === 'place:project:a')!;
    const e = layout.entities.find((e) => e.id === 'place:project:e')!;
    const memory = layout.entities.find((e) => e.id === 'place:memory')!;
    const library = layout.entities.find((e) => e.id === 'object:library')!;
    // Commons landmarks read as real buildings (4×4 library); projects sit south.
    expect(library.w).toBe(4);
    expect(library.h).toBe(4);
    // With ≤10 projects the district uses 5 lanes — the fifth stays on row 1.
    expect(e.y).toBe(a.y);
    // A 16-project roster wraps to row 2 (7 lanes).
    const wide = layoutWorld(
      buildWorldModel(
        baseInput({
          projects: Array.from({ length: 16 }, (_, i) => ({
            name: `p${String(i).padStart(2, '0')}`,
            target: `/p${i}`,
            status: 'ok' as const,
          })),
          memory: emptyMemory(true, []),
        }),
      ),
    );
    const first = wide.entities.find((row) => row.id === 'place:project:p00')!;
    const eighth = wide.entities.find((row) => row.id === 'place:project:p07')!;
    expect(eighth.y).toBeGreaterThan(first.y);
    expect(a.y).toBeGreaterThan(memory.y);
    expect(a.y).toBeGreaterThan(library.y);
  });

  it('never invents decorative characters on an idle grounds', () => {
    const layout = layoutWorld(
      buildWorldModel(
        baseInput({
          projects: [{ name: 'solo', target: '/solo', status: 'ok' }],
          memory: emptyMemory(true, []),
          jobs: [],
        }),
      ),
    );
    expect(layout.entities.filter((e) => e.kind === 'character')).toEqual([]);
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
