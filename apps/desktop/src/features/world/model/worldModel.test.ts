import { describe, expect, it } from 'vitest';
import { buildWorldModel } from './buildWorld';
import { layoutWorld } from './layout';
import { parseProjectListMessage } from './parseProjects';

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
  it('builds grounds, projects, knowledge, and job characters only', () => {
    const model = buildWorldModel({
      workspacePath: '/home/me/.ai-workspace',
      projects: [
        { name: 'alpha', target: '/r/alpha', status: 'ok' },
        { name: 'beta', target: '/r/beta', status: 'ok' },
      ],
      projectsKnown: true,
      memory: { available: true, entryCount: 3, projectKeys: ['alpha'] },
      jobs: [
        { id: 'j1', cmd: 'doctor', args: [], status: 'running', workspace: '/home/me/.ai-workspace' },
        { id: 'j2', cmd: 'install', args: [], status: 'completed', workspace: '/home/me/.ai-workspace' },
        { id: 'j3', cmd: 'build', args: [], status: 'failed', workspace: '/home/me/.ai-workspace' },
      ],
    });

    const ids = model.entities.map((e) => e.id);
    expect(ids).toContain('place:workspace');
    expect(ids).toContain('place:knowledge-workspace');
    expect(ids).toContain('place:project:alpha');
    expect(ids).toContain('place:project:beta');
    expect(ids).toContain('character:job:j1');
    expect(ids).toContain('character:job:j3');
    expect(ids).not.toContain('character:job:j2');
    expect(model.entities.find((e) => e.id === 'character:job:j1')?.themeKey).toBe('agent.working');
    expect(model.entities.find((e) => e.id === 'character:job:j3')?.themeKey).toBe('agent.blocked');
  });

  it('omits knowledge place when memory API is unavailable', () => {
    const model = buildWorldModel({
      workspacePath: '/ws',
      projects: [],
      projectsKnown: true,
      memory: { available: false, entryCount: 0, projectKeys: [] },
      jobs: [],
    });
    expect(model.entities.map((e) => e.id)).not.toContain('place:knowledge-workspace');
    expect(model.entities.map((e) => e.id)).toContain('place:projects-empty');
  });

  it('enters a project space with knowledge and terminal representations', () => {
    const model = buildWorldModel({
      workspacePath: '/ws',
      projects: [{ name: 'alpha', target: '/r/alpha', status: 'ok' }],
      projectsKnown: true,
      memory: { available: true, entryCount: 1, projectKeys: ['alpha'] },
      jobs: [],
      focusProjectId: 'alpha',
    });
    const ids = model.entities.map((e) => e.id);
    expect(ids).toContain('place:project:alpha');
    expect(ids).not.toContain('place:project:beta');
    expect(ids).toContain('place:knowledge-project:alpha');
    expect(ids).toContain('object:terminal-project:alpha');
  });

  it('never invents characters without jobs', () => {
    const model = buildWorldModel({
      workspacePath: '/ws',
      projects: [{ name: 'only', target: '/r', status: 'ok' }],
      projectsKnown: true,
      memory: { available: true, entryCount: 0, projectKeys: [] },
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
      memory: { available: true, entryCount: 0, projectKeys: [] },
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
        memory: { available: false, entryCount: 0, projectKeys: [] },
        jobs: [],
      }),
    );
    const five = layoutWorld(
      buildWorldModel({
        workspacePath: '/ws',
        projects: ['a', 'b', 'c', 'd', 'e'].map((name) => ({ name, target: `/${name}`, status: 'ok' as const })),
        projectsKnown: true,
        memory: { available: false, entryCount: 0, projectKeys: [] },
        jobs: [],
      }),
    );
    const a1 = one.entities.find((e) => e.id === 'place:project:a');
    const a5 = five.entities.find((e) => e.id === 'place:project:a');
    expect(a1 && a5).toBeTruthy();
    expect({ x: a1!.x, y: a1!.y }).toEqual({ x: a5!.x, y: a5!.y });
  });
});
