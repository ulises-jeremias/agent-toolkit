import { describe, expect, it } from 'vitest';
import { buildWorldModel } from './buildWorld';
import { layoutWorld } from './layout';
import { jobStandAtId, projectScopedMemory, workspaceLevelMemory } from './memoryScope';
import type { MemoryEntryRecord, ToolRecord, WorldDomainInput } from './types';

function entry(
  partial: Omit<Partial<MemoryEntryRecord>, 'provenance' | 'id' | 'title'> &
    Pick<MemoryEntryRecord, 'id' | 'title'> & {
      provenance?: Partial<MemoryEntryRecord['provenance']>;
    },
): MemoryEntryRecord {
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

describe('memory scope partition', () => {
  const projects = [
    { name: 'alpha', target: '/r/alpha', status: 'ok' as const },
    { name: 'hornero', target: '/r/hornero', status: 'ok' as const },
  ];

  it('keeps workspace-level and no-location records on the world archive only', () => {
    const rows = [
      entry({ id: 'knowledge/learnings/a.md', title: 'Harness', provenance: { project: '.ai-workspace' } }),
      entry({ id: 'knowledge/learnings/b.md', title: 'No loc', provenance: { project: '' } }),
      entry({ id: 'knowledge/learnings/c.md', title: 'Alpha', provenance: { project: 'alpha' } }),
    ];
    const workspace = workspaceLevelMemory(rows, projects);
    expect(workspace.map((r) => r.id)).toEqual(['knowledge/learnings/a.md', 'knowledge/learnings/b.md']);
    expect(projectScopedMemory(rows, 'alpha').map((r) => r.id)).toEqual(['knowledge/learnings/c.md']);
    expect(projectScopedMemory(rows, 'hornero')).toEqual([]);
  });

  it('does not copy no-location records into every house', () => {
    const rows = [entry({ id: 'x.md', title: 'X', provenance: { project: '' } })];
    expect(projectScopedMemory(rows, 'alpha')).toEqual([]);
    expect(projectScopedMemory(rows, 'hornero')).toEqual([]);
    expect(workspaceLevelMemory(rows, projects)).toHaveLength(1);
  });
});

describe('jobStandAtId', () => {
  const tools: ToolRecord[] = [
    {
      id: 'cursor',
      toolName: 'Cursor',
      detected: true,
      configured: true,
      enabled: 'true',
      verified: true,
      version: '1',
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

  it('anchors on memory, terminal, or a detected tool when cmd names them', () => {
    expect(
      jobStandAtId(
        { cmd: 'memory', args: ['list'] },
        { tools, memoryPlaceId: 'place:memory-project:alpha', terminalObjectId: 'object:terminal-project:alpha' },
      ),
    ).toBe('place:memory-project:alpha');
    expect(
      jobStandAtId(
        { cmd: 'terminal', args: [] },
        { tools, memoryPlaceId: 'place:memory', terminalObjectId: 'object:terminal' },
      ),
    ).toBe('object:terminal');
    expect(jobStandAtId({ cmd: 'cursor', args: [] }, { tools })).toBe('object:tool:cursor');
    expect(jobStandAtId({ cmd: 'Cursor', args: [] }, { tools })).toBe('object:tool:cursor');
  });

  it('stays unanchored when cmd does not name a known object', () => {
    expect(jobStandAtId({ cmd: 'doctor', args: [] }, { tools, memoryPlaceId: 'place:memory' })).toBeUndefined();
    expect(jobStandAtId({ cmd: 'ghost', args: [] }, { tools })).toBeUndefined();
    expect(jobStandAtId({ cmd: '', args: ['cursor'] }, { tools })).toBeUndefined();
  });
});

describe('buildWorldModel memory + standAt', () => {
  function base(overrides: Partial<WorldDomainInput> = {}): WorldDomainInput {
    return {
      workspacePath: '/ws/.ai-workspace',
      projects: [
        { name: 'alpha', target: '/r/alpha', status: 'ok' },
        { name: 'beta', target: '/r/beta', status: 'ok' },
      ],
      projectsKnown: true,
      memory: { available: false, entries: [], projectKeys: [] },
      tools: [],
      toolsKnown: false,
      jobs: [],
      ...overrides,
    };
  }

  it('puts project-scoped memory only in that house and workspace-level only on grounds', () => {
    const memory = {
      available: true,
      projectKeys: ['alpha', '.ai-workspace'],
      entries: [
        entry({ id: 'ws.md', title: 'WS', provenance: { project: '.ai-workspace' } }),
        entry({ id: 'none.md', title: 'None', provenance: { project: '' } }),
        entry({ id: 'a.md', title: 'A', provenance: { project: 'alpha' } }),
        entry({ id: 'b.md', title: 'B', provenance: { project: 'beta' } }),
      ],
    };

    const grounds = buildWorldModel(base({ memory }));
    expect(grounds.entities.find((e) => e.id === 'place:memory')?.state).toBe('2 records');
    expect(grounds.entities.map((e) => e.id)).toContain('object:memory:ws.md');
    expect(grounds.entities.map((e) => e.id)).toContain('object:memory:none.md');
    expect(grounds.entities.map((e) => e.id)).not.toContain('object:memory:a.md');
    expect(grounds.entities.map((e) => e.id)).not.toContain('object:memory:b.md');

    const alpha = buildWorldModel(base({ memory, focusProjectId: 'alpha' }));
    expect(alpha.entities.find((e) => e.id === 'place:memory-project:alpha')?.state).toBe('1 records');
    expect(alpha.entities.map((e) => e.id)).toContain('object:memory:a.md');
    expect(alpha.entities.map((e) => e.id)).not.toContain('object:memory:ws.md');
    expect(alpha.entities.map((e) => e.id)).not.toContain('object:memory:b.md');
    expect(alpha.entities.map((e) => e.id)).not.toContain('object:memory:none.md');

    const beta = buildWorldModel(base({ memory, focusProjectId: 'beta' }));
    expect(beta.entities.find((e) => e.id === 'place:memory-project:beta')?.state).toBe('1 records');
    expect(beta.entities.map((e) => e.id)).toContain('object:memory:b.md');
  });

  it('places a character at the interior object named by job.cmd', () => {
    const tools: ToolRecord[] = [
      {
        id: 'cursor',
        toolName: 'Cursor',
        detected: true,
        configured: true,
        enabled: 'true',
        verified: true,
        version: '1',
      },
    ];
    const model = buildWorldModel(
      base({
        tools,
        toolsKnown: true,
        jobs: [{ id: 'j1', cmd: 'cursor', args: [], status: 'running', workspace: '/r/alpha' }],
        focusProjectId: 'alpha',
      }),
    );
    const character = model.entities.find((e) => e.id === 'character:job:j1');
    expect(character?.standAtId).toBe('object:tool:cursor');
    const laid = layoutWorld(model);
    const tool = laid.entities.find((e) => e.id === 'object:tool:cursor')!;
    const body = laid.entities.find((e) => e.id === 'character:job:j1')!;
    expect(body.x).toBe(tool.x + tool.w - 1);
    expect(body.y).toBe(tool.y + tool.h - 1);
  });

  it('keeps a failed house enterable without retaining a finished worker', () => {
    const model = buildWorldModel(
      base({
        jobs: [{ id: 'j2', cmd: 'doctor', args: [], status: 'failed', workspace: '/r/alpha' }],
      }),
    );
    const character = model.entities.find((e) => e.id === 'character:job:j2');
    expect(character).toBeUndefined();
    expect(model.entities.find((e) => e.id === 'place:project:alpha')?.hrefPath).toBe('/world');
  });
});
