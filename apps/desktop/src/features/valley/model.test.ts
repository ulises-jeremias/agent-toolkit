import { describe, expect, it } from 'vitest';
import { buildValley, cameraFor, hash, HOUSE_SPRITES, threadsForWorkspace, type ValleyInput } from './model';

const base: ValleyInput = {
  projects: [],
  threads: [],
  personFigures: [],
  jobsRunning: 0,
  attention: 0,
  people: 0,
  minWidth: 360,
};

const thread = (id: string, projectName: string, status: string, provider = 'claude') =>
  ({ id, title: `Task ${id}`, projectName, status, provider }) as ValleyInput['threads'][number];

describe('buildValley', () => {
  it('shows an empty lot that links a repository when nothing is linked', () => {
    const scene = buildValley(base);
    expect(scene.places.map((place) => place.kind)).toEqual(['lodge', 'library', 'empty-lot', 'workshop']);
    expect(scene.places[2]?.actions).toEqual([
      { id: 'link', label: 'Link a repository', primary: true, run: 'link-project' },
    ]);
    expect(scene.wheelTurning).toBe(false);
    expect(scene.places.every((place) => place.figures.length === 0 && !place.lit)).toBe(true);
  });

  it('gives each project a house that stays the same between runs', () => {
    const input = {
      ...base,
      projects: [
        { name: 'garden-api', status: 'ok' },
        { name: 'atlas', status: 'ok' },
      ],
    };
    const first = buildValley(input);
    const second = buildValley(input);
    expect(first).toEqual(second);
    const house = first.places.find((place) => place.id === 'project:garden-api');
    expect(house?.sprite).toBe(HOUSE_SPRITES[hash('garden-api') % HOUSE_SPRITES.length]);
    expect(house).toMatchObject({ lit: false, summary: 'No sessions yet', projectName: 'garden-api' });
    expect(house?.actions.map((action) => action.label)).toEqual(['New session', 'Changes', 'Terminal']);
  });

  it('lights a house and stands a figure outside only for sessions that are really live', () => {
    const scene = buildValley({
      ...base,
      projects: [{ name: 'garden-api', status: 'ok' }],
      threads: [
        thread('th_idle', 'garden-api', 'idle'),
        thread('th_stopped', 'garden-api', 'interrupted'),
        thread('th_failed', 'garden-api', 'error'),
        thread('th_run', 'garden-api', 'running', 'codex'),
        thread('th_ask', 'garden-api', 'awaiting-approval'),
        thread('th_input', 'garden-api', 'awaiting-input', 'codex'),
        thread('th_other', 'elsewhere', 'running'),
      ],
    });
    const house = scene.places.find((place) => place.kind === 'project');
    expect(house).toMatchObject({ lit: true, asking: 2, summary: '2 sessions need your answer' });
    // The session waiting for you stands first.
    expect(house?.figures.map((figure) => [figure.params['thread'], figure.state, figure.family])).toEqual([
      ['th_ask', 'asking', 'ember'],
      ['th_input', 'asking', 'river'],
      ['th_run', 'working', 'river'],
    ]);
  });

  it('stands a Person session or swarm worker at its project house, with its own destination', () => {
    const scene = buildValley({
      ...base,
      projects: [{ name: 'garden-api', status: 'ok' }],
      personFigures: [
        {
          id: 'pty-1',
          name: 'Lina',
          kind: 'Person session',
          projectId: 'garden-api',
          provider: 'claude',
          to: '/terminal',
          params: { pty: 'pty-1' },
        },
      ],
    });
    const house = scene.places.find((place) => place.kind === 'project');
    expect(house).toMatchObject({ lit: true, summary: '1 session working' });
    expect(house?.figures).toEqual([
      expect.objectContaining({
        title: 'Lina · Person session',
        to: '/terminal',
        params: { pty: 'pty-1' },
        state: 'working',
      }),
    ]);
  });

  it('draws at most three figures and counts the rest', () => {
    const threads = Array.from({ length: 5 }, (_, index) => thread(`th_${index}`, 'busy', 'running'));
    const house = buildValley({ ...base, projects: [{ name: 'busy', status: 'ok' }], threads }).places.find(
      (place) => place.kind === 'project',
    );
    expect(house?.figures).toHaveLength(3);
    expect(house?.moreFigures).toBe(2);
    expect(house?.summary).toBe('5 sessions working');
  });

  it('marks a project whose folder is gone and offers the fix, not a session', () => {
    const house = buildValley({ ...base, projects: [{ name: 'gone', status: 'broken' }] }).places.find(
      (place) => place.kind === 'project',
    );
    expect(house).toMatchObject({ broken: true, summary: 'The linked folder is missing' });
    expect(house?.actions.map((action) => action.label)).toEqual(['Fix in Projects']);
  });

  it('turns the mill wheel only while a job runs and surfaces what needs you', () => {
    const quiet = buildValley(base).places.at(-1);
    expect(quiet).toMatchObject({ kind: 'workshop', lit: false, summary: 'Jobs, loops and swarms. Nothing running' });
    const busy = buildValley({ ...base, jobsRunning: 2, attention: 0 });
    expect(busy.wheelTurning).toBe(true);
    expect(busy.places.at(-1)).toMatchObject({ lit: true, summary: '2 jobs running' });
    const needs = buildValley({ ...base, jobsRunning: 1, attention: 3 }).places.at(-1);
    expect(needs).toMatchObject({ asking: 3, summary: '3 things need you' });
    expect(needs?.actions.map((action) => action.label)).toContain('Needs you (3)');
  });

  it('never overlaps places and is at least as wide as the window', () => {
    const projects = Array.from({ length: 9 }, (_, index) => ({ name: `repo-${index}`, status: 'ok' }));
    const scene = buildValley({ ...base, projects, minWidth: 384 });
    const sorted = [...scene.places].sort((a, b) => a.x - b.x);
    for (let index = 1; index < sorted.length; index += 1) {
      const previous = sorted[index - 1];
      const current = sorted[index];
      expect(current && previous && current.x).toBeGreaterThanOrEqual((previous?.x ?? 0) + (previous?.w ?? 0));
    }
    expect(scene.riverX).toBeGreaterThan(sorted.at(-2)?.x ?? 0);
    expect(scene.width).toBeGreaterThan(900);
    expect(buildValley({ ...base, minWidth: 640 }).width).toBe(640);
  });
});

describe('threadsForWorkspace', () => {
  it('keeps sessions scoped to the selected workspace, even when project names match', () => {
    const threads = [
      { id: 'current', workspace: '/work/current', projectName: 'api' },
      { id: 'stale', workspace: '/work/previous', projectName: 'api' },
    ];

    expect(threadsForWorkspace(threads, '/work/current').map((thread) => thread.id)).toEqual(['current']);
    expect(threadsForWorkspace(threads, '')).toEqual([]);
  });
});

describe('cameraFor', () => {
  it('pans just enough to bring a place into view and stays inside the scene', () => {
    expect(cameraFor({ x: 40, w: 64 }, 360, 900, 0)).toBe(0);
    expect(cameraFor({ x: 500, w: 64 }, 360, 900, 0)).toBe(228);
    expect(cameraFor({ x: 40, w: 64 }, 360, 900, 300)).toBe(16);
    expect(cameraFor({ x: 880, w: 64 }, 360, 900, 0)).toBe(540);
    expect(cameraFor({ x: 10, w: 64 }, 360, 300, 0)).toBe(0);
  });
});
