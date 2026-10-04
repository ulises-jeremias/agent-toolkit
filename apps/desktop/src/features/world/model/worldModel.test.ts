import { describe, expect, it } from 'vitest';
import { buildWorldModel, jobBelongsToProject } from './buildWorld';
import { layoutWorld } from './layout';
import { parseProjectListMessage } from './parseProjects';
import { paintTerrain } from './terrain';
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
  it('shows only explicitly supplied live Person sessions at their real project house', () => {
    const project = { name: 'alpha', target: '/repos/alpha', status: 'ok' as const };
    const base = baseInput({
      projects: [project],
      personSessions: [
        {
          id: 'pty-1',
          personId: 'lina',
          name: 'Lina',
          role: 'reviewer',
          cwd: '/repos/alpha/src',
          projectId: 'alpha',
          provider: 'opencode',
          model: 'model-x',
          avatarCharacter: 'char-scholar',
        },
      ],
    });
    const grounds = buildWorldModel(base);
    const character = grounds.entities.find((entity) => entity.id === 'character:person:lina:pty-1');
    expect(character).toMatchObject({
      name: 'Lina',
      characterSprite: 'char-scholar',
      state: 'session open',
      hrefPath: '/people',
      hrefExtra: { person: 'lina', session: 'pty-1' },
      projectId: 'alpha',
      standAtId: 'place:project:alpha',
    });
    expect(character?.detail).toContain('reviewer · opencode · model-x');
    const layout = layoutWorld(grounds);
    const laidCharacter = layout.entities.find((entity) => entity.id === character?.id)!;
    const house = layout.entities.find((entity) => entity.id === 'place:project:alpha')!;
    expect(laidCharacter.x).toBeGreaterThanOrEqual(house.x);
    expect(laidCharacter.x).toBeLessThan(house.x + house.w);
    expect(laidCharacter.y).toBeGreaterThanOrEqual(house.y);
    expect(grounds.entities.find((entity) => entity.id === 'place:project:alpha')?.state).toBe('1 Person session open');

    const noRuntime = buildWorldModel(baseInput({ projects: [project] }));
    expect(noRuntime.entities.some((entity) => entity.kind === 'character')).toBe(false);

    const wrongProject = buildWorldModel(
      baseInput({
        projects: [project],
        personSessions: [
          {
            id: 'pty-2',
            personId: 'lina',
            name: 'Lina',
            role: 'reviewer',
            cwd: '/repos/elsewhere',
            projectId: 'alpha',
          },
        ],
      }),
    );
    expect(wrongProject.entities.some((entity) => entity.id.startsWith('character:person:'))).toBe(false);

    const wrongCase = buildWorldModel(
      baseInput({
        projects: [project],
        personSessions: [
          {
            id: 'pty-3',
            personId: 'lina',
            name: 'Lina',
            role: 'reviewer',
            cwd: '/repos/ALPHA/src',
            projectId: 'alpha',
          },
        ],
      }),
    );
    expect(wrongCase.entities.some((entity) => entity.id.startsWith('character:person:'))).toBe(false);
  });

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

  it('opens a project interior with its own memory, terminal, files, and live work', () => {
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
    expect(model.entities.find((e) => e.id === 'object:files-project:alpha')).toMatchObject({
      concept: 'Project files',
      themeKey: 'files.project',
      hrefPath: '/workspace',
      hrefExtra: { panel: 'files', project: 'alpha' },
    });
    expect(ids).not.toContain('object:workshop');
    expect(ids).not.toContain('object:tool:cursor');
    expect(ids).not.toContain('object:tool:ghost');
    expect(ids).not.toContain('place:project:beta');
    expect(ids).not.toContain('object:library');
    expect(ids).not.toContain('place:memory');
    expect(ids).not.toContain('place:knowledge-workspace');
    expect(ids).toContain('character:job:j1');
    expect(model.entities.find((e) => e.id === 'place:project:alpha')?.concept).toBe('Project overview board');
  });

  it('places detected coding tools in one shared workshop, outside project houses', () => {
    const model = buildWorldModel(
      baseInput({
        projects: [
          { name: 'alpha', target: '/r/alpha', status: 'ok' },
          { name: 'beta', target: '/r/beta', status: 'ok' },
        ],
        toolsKnown: true,
        tools: [
          {
            id: 'opencode',
            toolName: 'OpenCode',
            detected: true,
            configured: false,
            enabled: 'unknown',
            verified: true,
            version: '1.0',
          },
          {
            id: 'claude-code',
            toolName: 'Claude Code',
            detected: true,
            configured: true,
            enabled: 'unknown',
            verified: false,
            version: '',
          },
          {
            id: 'missing',
            toolName: 'Missing',
            detected: false,
            configured: false,
            enabled: 'unknown',
            verified: false,
            version: '',
          },
        ],
      }),
    );
    const workshop = model.entities.find((entity) => entity.id === 'object:workshop');
    expect(workshop).toMatchObject({
      kind: 'place',
      name: 'Workshop',
      state: '2 detected',
      availability: 'present',
      hrefPath: '/library',
      facade: 'landmark-workshop',
    });
    expect(workshop?.detail).toContain('2 coding-tool runtimes detected');
    expect(model.entities.some((entity) => entity.id.startsWith('object:tool:'))).toBe(false);
    expect(model.entities.filter((entity) => entity.id === 'object:workshop')).toHaveLength(1);
    expect(
      model.entities.filter((entity) => entity.id.startsWith('place:project:')).map((entity) => entity.name),
    ).toEqual(['alpha', 'beta']);
  });

  it('shows the workshop inventory as empty or unavailable without inventing tool objects', () => {
    const empty = buildWorldModel(baseInput({ toolsKnown: true, tools: [] }));
    expect(empty.entities.find((entity) => entity.id === 'object:workshop')).toMatchObject({
      state: 'empty',
      availability: 'empty',
    });
    expect(empty.entities.some((entity) => entity.id.startsWith('object:tool:'))).toBe(false);

    const unavailable = buildWorldModel(baseInput({ toolsKnown: false }));
    expect(unavailable.entities.find((entity) => entity.id === 'object:workshop')).toMatchObject({
      state: 'unknown',
      availability: 'unavailable',
    });
  });

  it('lays out one shared workshop before the creek and project houses', () => {
    const layout = layoutWorld(
      buildWorldModel(
        baseInput({
          toolsKnown: true,
          tools: [
            {
              id: 'opencode',
              toolName: 'OpenCode',
              detected: true,
              configured: false,
              enabled: 'unknown',
              verified: true,
              version: '1.0',
            },
          ],
          projects: [{ name: 'alpha', target: '/r/alpha', status: 'ok' }],
        }),
      ),
    );
    const workshop = layout.entities.find((entity) => entity.id === 'object:workshop')!;
    const house = layout.entities.find((entity) => entity.id === 'place:project:alpha')!;
    expect(workshop).toMatchObject({ w: 5, h: 4, facade: 'landmark-workshop' });
    expect(house.x).toBeGreaterThan(workshop.x + workshop.w);
    expect(layout.entities.filter((entity) => entity.id.startsWith('object:tool:'))).toHaveLength(0);
    const water = new Set(
      paintTerrain(layout.entities, layout.cols, layout.rows)
        .cells.filter((cell) => cell.tile === 'water')
        .map((cell) => `${cell.x},${cell.y}`),
    );
    for (let y = workshop.y; y < workshop.y + workshop.h; y++) {
      for (let x = workshop.x; x < workshop.x + workshop.w; x++) {
        expect(water.has(`${x},${y}`)).toBe(false);
      }
    }
    const waterColumns = [...water].map((cell) => Number(cell.split(',')[0]));
    expect(house.x).toBeGreaterThan(Math.max(...waterColumns));
    expect(waterColumns.some((x) => x >= workshop.x + workshop.w && x < house.x)).toBe(true);
  });

  it('keeps project interiors free of shared workshop fixtures and fake characters', () => {
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
    expect(model.entities.some((e) => e.id === 'object:workshop' || e.id.startsWith('object:tool:'))).toBe(false);
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

  it('lays projects in a fixed-width neighborhood across the creek from the commons', () => {
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
    const b = layout.entities.find((e) => e.id === 'place:project:b')!;
    const e = layout.entities.find((e) => e.id === 'place:project:e')!;
    const memory = layout.entities.find((e) => e.id === 'place:memory')!;
    const library = layout.entities.find((e) => e.id === 'object:library')!;
    // Commons landmarks read as real buildings (4×4 library); projects sit south.
    expect(library.w).toBe(4);
    expect(library.h).toBe(4);
    expect(b.y).toBe(a.y + 2);
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
    expect(eighth.x).toBe(first.x + 2);
    expect(a.y).toBeGreaterThan(memory.y);
    expect(a.x).toBeGreaterThan(library.x + library.w);
  });

  it('fits camera bounds to occupied project lots without moving existing houses', () => {
    const layoutFor = (names: string[]) =>
      layoutWorld(
        buildWorldModel(
          baseInput({
            projects: names.map((name) => ({ name, target: `/${name}`, status: 'ok' as const })),
            memory: emptyMemory(true, []),
          }),
        ),
      );
    const one = layoutFor(['alpha']);
    const two = layoutFor(['alpha', 'beta']);
    expect(two.cols).toBeGreaterThanOrEqual(one.cols);
    const firstAlpha = one.entities.find((entity) => entity.id === 'place:project:alpha')!;
    const secondAlpha = two.entities.find((entity) => entity.id === 'place:project:alpha')!;
    expect(secondAlpha).toMatchObject({ x: firstAlpha.x, y: firstAlpha.y, w: firstAlpha.w, h: firstAlpha.h });
    const compactTeam = layoutFor(['alpha', 'beta', 'gamma']);
    expect(compactTeam.cols).toBeLessThanOrEqual(28);
    expect(compactTeam.rows).toBeLessThanOrEqual(13);
  });

  it('keeps the project neighborhood stable, separated, and collision-free at every scale', () => {
    for (const count of [0, 1, 2, 5, 12, 24]) {
      const layout = layoutWorld(
        buildWorldModel(
          baseInput({
            projects: Array.from({ length: count }, (_, i) => ({
              name: `project-${String(i).padStart(2, '0')}`,
              target: `/project-${i}`,
              status: 'ok' as const,
            })),
          }),
        ),
      );
      const houses = layout.entities.filter((entity) => entity.id.startsWith('place:project:'));
      expect(new Set(houses.map(({ x, y }) => `${x},${y}`)).size).toBe(houses.length);
      for (const [index, a] of houses.entries()) {
        for (const b of houses.slice(index + 1)) {
          expect(a.x + a.w <= b.x || b.x + b.w <= a.x || a.y + a.h <= b.y || b.y + b.h <= a.y).toBe(true);
        }
      }
      expect(layout.cols).toBeGreaterThan(0);
      expect(layout.rows).toBeGreaterThan(0);
      for (const entity of layout.entities) {
        expect(entity.x).toBeGreaterThanOrEqual(0);
        expect(entity.y).toBeGreaterThanOrEqual(0);
        expect(entity.x + entity.w).toBeLessThanOrEqual(layout.cols);
        expect(entity.y + entity.h).toBeLessThanOrEqual(layout.rows);
      }
    }
  });

  it('makes the no-project building lead to the real project linking workflow', () => {
    const model = buildWorldModel(baseInput({ projects: [] }));
    const marker = model.entities.find((entity) => entity.id === 'place:projects-empty');
    expect(marker).toMatchObject({ hrefPath: '/workspace', hrefExtra: { panel: 'projects' } });
    const layout = layoutWorld(model);
    const plan = paintTerrain(layout.entities, layout.cols, layout.rows);
    const laidMarker = layout.entities.find((entity) => entity.id === marker?.id)!;
    const pathFront = `${laidMarker.x + Math.floor(laidMarker.w / 2)},${laidMarker.y + laidMarker.h}`;
    expect(plan.cells.some(({ tile }) => tile.startsWith('trail'))).toBe(true);
    expect(plan.cells.some(({ x, y, tile }) => `${x},${y}` === pathFront && tile.startsWith('trail'))).toBe(true);
    const trailCells = plan.cells.filter(({ tile }) => tile.startsWith('trail'));
    expect(Math.max(...trailCells.map(({ x }) => x))).toBeLessThanOrEqual(
      laidMarker.x + Math.floor(laidMarker.w / 2) + 1,
    );
    const bridge = plan.decor.find((sprite) => sprite.sprite === 'bridge');
    expect(bridge).toBeTruthy();
    expect(bridge!.y + 1).toBe(laidMarker.y + laidMarker.h);
    expect(bridge!.y + 1).toBeLessThan(layout.rows);
    // The crossing must join the civic quarter as well as the empty project
    // lot; a bridge with only an east-bank road is decorative, not navigation.
    expect(
      plan.cells.some(({ x, y, tile }) => x === bridge!.x - 1 && y === bridge!.y + 1 && tile.startsWith('trail')),
    ).toBe(true);
  });

  it('makes shared and project memory archives focus their real world index', () => {
    const grounds = layoutWorld(buildWorldModel(baseInput({ memory: emptyMemory(true, []) })));
    expect(grounds.entities.find((entity) => entity.id === 'place:memory')).toMatchObject({
      hrefPath: '/world',
      hrefExtra: { place: 'place:memory' },
    });

    const interior = layoutWorld(
      buildWorldModel(
        baseInput({
          projects: [{ name: 'alpha', target: '/alpha', status: 'ok' }],
          focusProjectId: 'alpha',
          memory: emptyMemory(true, []),
        }),
      ),
    );
    expect(interior.entities.find((entity) => entity.id === 'place:memory-project:alpha')).toMatchObject({
      hrefPath: '/world',
      hrefExtra: { project: 'alpha', place: 'place:memory-project:alpha' },
    });
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

  it('adds a small project garden only where the real house lot has free ground', () => {
    const layout = layoutWorld(
      buildWorldModel(
        baseInput({
          projects: [{ name: 'solo', target: '/solo', status: 'ok' }],
          memory: emptyMemory(true, []),
        }),
      ),
    );
    const plan = paintTerrain(layout.entities, layout.cols, layout.rows);
    expect(plan.decor.some((sprite) => sprite.id.startsWith('project-fence:place:project:solo:'))).toBe(true);
    expect(plan.cells.some(({ tile }) => tile.startsWith('flowers-'))).toBe(true);
  });

  it('composes narrow connected footpaths and stable creek crossings', () => {
    const layout = layoutWorld(
      buildWorldModel(
        baseInput({
          projects: ['north', 'east', 'south', 'west'].map((name) => ({
            name,
            target: `/${name}`,
            status: 'ok' as const,
          })),
        }),
      ),
    );
    const first = paintTerrain(layout.entities, layout.cols, layout.rows);
    const second = paintTerrain(layout.entities, layout.cols, layout.rows);
    expect(first.cells).toEqual(second.cells);
    expect(first.decor).toEqual(second.decor);
    expect(first.cells.some((cell) => cell.tile.startsWith('trail'))).toBe(true);
    const bridge = first.decor.find((sprite) => sprite.sprite === 'bridge');
    expect(bridge).toBeTruthy();
    const waterRows = new Map<number, number[]>();
    for (const cell of first.cells.filter(({ tile }) => tile === 'water')) {
      waterRows.set(cell.y, [...(waterRows.get(cell.y) ?? []), cell.x]);
    }
    expect(new Set([...waterRows.values()].map((xs) => Math.min(...xs))).size).toBeGreaterThan(1);
    expect([...waterRows.values()].every((xs) => xs.length === 2 || xs.length === 3)).toBe(true);
    expect([...waterRows.values()].some((xs) => xs.length === 3)).toBe(true);
    expect(new Set(first.cells.filter(({ tile }) => tile.startsWith('trail')).map(({ y }) => y)).size).toBeGreaterThan(
      1,
    );
    const trails = new Set(first.cells.filter((cell) => cell.tile.startsWith('trail')).map(({ x, y }) => `${x},${y}`));
    const water = new Set(first.cells.filter(({ tile }) => tile === 'water').map(({ x, y }) => `${x},${y}`));
    const sparkles = first.decor.filter((sprite) => sprite.sprite === 'water-sparkle');
    expect(sparkles.length).toBeGreaterThan(0);
    expect(sparkles.length).toBeLessThanOrEqual(5);
    for (const sparkle of sparkles) expect(water.has(`${sparkle.x},${sparkle.y}`)).toBe(true);
    const bridgeLanterns = first.decor.filter((sprite) => sprite.id.startsWith('bridge-lantern:'));
    expect(bridgeLanterns.length).toBe(2);
    for (const lantern of bridgeLanterns) expect(water.has(`${lantern.x},${lantern.y}`)).toBe(false);
    expect(first.decor.filter((sprite) => sprite.sprite === 'mote').length).toBeLessThanOrEqual(4);
    const reached = new Set<string>();
    const queue = [trails.values().next().value as string];
    while (queue.length) {
      const at = queue.shift()!;
      if (reached.has(at)) continue;
      reached.add(at);
      const [x = 0, y = 0] = at.split(',').map(Number);
      for (const next of [`${x},${y - 1}`, `${x - 1},${y}`, `${x + 1},${y}`, `${x},${y + 1}`]) {
        if (trails.has(next) && !reached.has(next)) queue.push(next);
      }
    }
    expect(reached).toEqual(trails);
    const bridgeRoadY = bridge!.y + 1;
    for (let dx = 0; dx < 3; dx++) {
      expect(trails.has(`${bridge!.x + dx},${bridgeRoadY}`)).toBe(true);
    }
    for (const project of layout.entities.filter((entity) => entity.id.startsWith('place:project:'))) {
      const doorX = project.x + Math.floor(project.w / 2);
      const doorFrontY = project.y + project.h;
      expect(trails.has(`${doorX},${doorFrontY}`)).toBe(true);
      expect(project.x).toBeGreaterThan(bridge!.x + bridge!.w / 16 - 1);
      for (let y = project.y; y < project.y + project.h; y++) {
        for (let x = project.x; x < project.x + project.w; x++) {
          expect(water.has(`${x},${y}`)).toBe(false);
        }
      }
    }
  });

  it('clusters meadow color patches instead of changing grass palette every tile', () => {
    const layout = layoutWorld(buildWorldModel(baseInput({ projects: [] })));
    const cells = paintTerrain(layout.entities, layout.cols, layout.rows).cells;
    expect(new Set(cells.filter(({ tile }) => tile.startsWith('grass-')).map(({ tile }) => tile)).size).toBeGreaterThan(
      6,
    );
    const tiles = new Map(cells.map(({ x, y, tile }) => [`${x},${y}`, tile]));
    let adjacentPairs = 0;
    let paletteChanges = 0;
    for (const { x, y, tile } of cells) {
      if (!tile.startsWith('grass-')) continue;
      for (const neighbor of [`${x + 1},${y}`, `${x},${y + 1}`]) {
        const next = tiles.get(neighbor);
        if (!next?.startsWith('grass-')) continue;
        adjacentPairs += 1;
        if (next !== tile) paletteChanges += 1;
      }
    }
    expect(adjacentPairs).toBeGreaterThan(100);
    expect(paletteChanges / adjacentPairs).toBeLessThan(0.65);
  });

  it('adds readable flower glades without covering the connected footpaths', () => {
    const layout = layoutWorld(buildWorldModel(baseInput({ projects: [] })));
    const cells = paintTerrain(layout.entities, layout.cols, layout.rows).cells;
    const tiles = new Map(cells.map(({ x, y, tile }) => [`${x},${y}`, tile]));
    const trails = new Set(cells.filter(({ tile }) => tile.startsWith('trail')).map(({ x, y }) => `${x},${y}`));
    const flowers = cells.filter(({ tile }) => tile.startsWith('flowers-'));
    let matchingNeighbors = 0;

    for (const { x, y, tile } of flowers) {
      expect(trails.has(`${x},${y}`)).toBe(false);
      if (tiles.get(`${x + 1},${y}`) === tile) matchingNeighbors += 1;
      if (tiles.get(`${x},${y + 1}`) === tile) matchingNeighbors += 1;
    }

    expect(flowers.length).toBeGreaterThan(20);
    expect(matchingNeighbors).toBeGreaterThan(8);
  });

  it('keeps tall tree canopies inside the framed world edge', () => {
    const layout = layoutWorld(buildWorldModel(baseInput({ projects: [] })));
    const decor = paintTerrain(layout.entities, layout.cols, layout.rows).decor;
    const trees = decor.filter((sprite) => sprite.sprite.startsWith('tree-'));
    expect(trees.length).toBeGreaterThan(0);
    for (const tree of trees) {
      expect(tree.x).toBeGreaterThanOrEqual(1);
      expect(tree.x).toBeLessThan(layout.cols - 1);
      expect(tree.y).toBeGreaterThanOrEqual(3);
      expect(tree.w).toBe(48);
      expect(tree.h).toBe(48);
    }
    expect(decor.find((sprite) => sprite.id === 'hornero:hall')?.y).toBeGreaterThanOrEqual(0);
  });

  it('lays out a project interior without shared Library or Workshop fixtures', () => {
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
    expect(ids).not.toContain('object:workshop');
    expect(ids).not.toContain('object:tool:gh');
    expect(ids).not.toContain('object:library');
    const exit = layout.entities.find((e) => e.id === 'object:exit-grounds');
    const room = layout.entities.find((e) => e.id === 'place:project:alpha');
    const records = layout.entities.find((e) => e.id === 'place:memory-project:alpha');
    const terminal = layout.entities.find((e) => e.id === 'object:terminal-project:alpha');
    const files = layout.entities.find((e) => e.id === 'object:files-project:alpha');
    expect(exit && room).toBeTruthy();
    expect(exit!.x).toBe(1);
    expect(room!.x).toBeGreaterThan(exit!.x);
    expect(records?.x).toBe(13);
    expect(terminal?.y).toBe(8);
    expect(files?.y).toBe(8);
    expect(files!.x - terminal!.x).toBeGreaterThanOrEqual(4);
    expect(layout.cols).toBe(18);
    expect(layout.rows).toBe(12);
  });
});
