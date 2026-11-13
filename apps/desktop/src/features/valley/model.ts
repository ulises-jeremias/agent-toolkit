import type { FocusProviderId, FocusThread } from '../../types/focus';

/**
 * The World as data. A pure function from what is really true in the
 * workspace (linked projects, live sessions, running jobs) to a side-on
 * village: each project is a house on the lane, shared places are the
 * landmarks, and a figure stands outside a house only while a real session
 * is working or waiting there. Nothing here invents activity.
 *
 * All coordinates are art pixels along the lane; the renderer scales them.
 */

export type PlaceKind = 'lodge' | 'library' | 'project' | 'empty-lot' | 'workshop';

export type FigureFamily = 'ember' | 'river' | 'moss';

export interface ValleyFigure {
  id: string;
  /** What the figure is, in words: a session title, a person's name and what they run. */
  title: string;
  /** Where clicking it goes: the exact session or run that is live. */
  to: string;
  params: Record<string, string>;
  family: FigureFamily;
  state: 'working' | 'asking';
  /** Lane x of the figure's left edge. */
  x: number;
}

/** A live Person session or swarm worker, already scoped to the workspace by the caller. */
export interface ValleyPersonFigure {
  id: string;
  name: string;
  /** Who it is: "Person session" or "Swarm worker". */
  kind: string;
  projectId: string;
  provider: FocusProviderId | string;
  to: string;
  params: Record<string, string>;
}

export type PlaceAction =
  | { id: string; label: string; primary?: boolean; to: string; params?: Record<string, string> }
  | { id: string; label: string; primary?: boolean; run: 'link-project' | 'open-terminal' };

export interface ValleyPlace {
  id: string;
  kind: PlaceKind;
  /** Project name, or the landmark's name. */
  title: string;
  /** One line of current, true state. */
  summary: string;
  sprite: string;
  x: number;
  w: number;
  h: number;
  /** Windows lit and chimney smoking: a real session is working inside. */
  lit: boolean;
  /** How many sessions here are waiting for an answer. */
  asking: number;
  broken: boolean;
  projectName: string | null;
  figures: ValleyFigure[];
  /** Live sessions beyond the figures drawn. */
  moreFigures: number;
  actions: PlaceAction[];
}

export interface ValleyDecor {
  sprite: string;
  x: number;
  /** `back` draws behind buildings (trees), `front` in the foreground strip. */
  layer: 'back' | 'front';
  flip: boolean;
}

export interface ValleyScene {
  width: number;
  places: ValleyPlace[];
  decor: ValleyDecor[];
  riverX: number;
  bridgeX: number;
  /** The mill wheel turns only while a job is actually running. */
  wheelTurning: boolean;
  nestX: number;
  lamps: number[];
}

export interface ValleyInput {
  projects: ReadonlyArray<{ name: string; status: string }>;
  threads: ReadonlyArray<Pick<FocusThread, 'id' | 'title' | 'projectName' | 'provider' | 'status'>>;
  personFigures: readonly ValleyPersonFigure[];
  jobsRunning: number;
  attention: number;
  people: number;
  /** Visible lane width in art pixels; the scene is at least this wide. */
  minWidth: number;
}

export const SPRITE_SIZE = {
  lodge: { w: 96, h: 76 },
  library: { w: 80, h: 104 },
  house: { w: 64, h: 72 },
  workshop: { w: 96, h: 80 },
  river: { w: 64, h: 64 },
  bridge: { w: 80, h: 28 },
  agent: { w: 16, h: 24 },
} as const;

export const HOUSE_SPRITES = ['house_a', 'house_b', 'house_c', 'house_d'] as const;

const FAMILY: Record<string, FigureFamily> = { claude: 'ember', codex: 'river', opencode: 'moss' };
const MARGIN = 28;
const GAP = 30;
const MAX_FIGURES = 3;

/** Small stable hash so a project keeps its house and its trees between launches. */
export function hash(text: string): number {
  let value = 2166136261;
  for (let index = 0; index < text.length; index += 1) {
    value ^= text.charCodeAt(index);
    value = Math.imul(value, 16777619);
  }
  return value >>> 0;
}

function plural(count: number, one: string, many: string): string {
  return count === 1 ? `1 ${one}` : `${count} ${many}`;
}

function projectSummary(sessions: number, working: number, asking: number, broken: boolean): string {
  if (broken) return 'The linked folder is missing';
  if (asking > 0) return `${plural(asking, 'session needs', 'sessions need')} your answer`;
  if (working > 0) return `${plural(working, 'session', 'sessions')} working`;
  if (sessions > 0) return `${plural(sessions, 'session', 'sessions')}, none running`;
  return 'No sessions yet';
}

export function buildValley(input: ValleyInput): ValleyScene {
  const places: ValleyPlace[] = [];
  const decor: ValleyDecor[] = [];
  let cursor = MARGIN;

  const place = (partial: Omit<ValleyPlace, 'x'>): ValleyPlace => {
    const placed = { ...partial, x: cursor };
    places.push(placed);
    cursor += partial.w + GAP;
    return placed;
  };

  decor.push({ sprite: 'tree_pine', x: 2, layer: 'back', flip: false });

  place({
    id: 'lodge',
    kind: 'lodge',
    title: 'People',
    summary:
      input.people === 0 ? 'No collaborators set up yet' : `${plural(input.people, 'collaborator', 'collaborators')}`,
    sprite: 'lodge',
    ...SPRITE_SIZE.lodge,
    lit: false,
    asking: 0,
    broken: false,
    projectName: null,
    figures: [],
    moreFigures: 0,
    actions: [{ id: 'people', label: 'Open People', primary: true, to: '/people' }],
  });

  const nestX = cursor - GAP + 6;

  place({
    id: 'library',
    kind: 'library',
    title: 'Library',
    summary: 'Skills, agents, tool connections, context and memory',
    sprite: 'library',
    ...SPRITE_SIZE.library,
    lit: false,
    asking: 0,
    broken: false,
    projectName: null,
    figures: [],
    moreFigures: 0,
    actions: [
      { id: 'library', label: 'Open Library', primary: true, to: '/library' },
      { id: 'context', label: 'Context and memory', to: '/context' },
    ],
  });

  const lamps: number[] = [cursor - GAP / 2 - 5];

  if (input.projects.length === 0) {
    place({
      id: 'empty-lot',
      kind: 'empty-lot',
      title: 'An empty lot',
      summary: 'Nothing linked yet. A linked repository becomes a house here',
      sprite: 'signpost',
      w: 48,
      h: 40,
      lit: false,
      asking: 0,
      broken: false,
      projectName: null,
      figures: [],
      moreFigures: 0,
      actions: [{ id: 'link', label: 'Link a repository', primary: true, run: 'link-project' }],
    });
  }

  input.projects.forEach((project, index) => {
    const seed = hash(project.name);
    const sessions = input.threads.filter((thread) => thread.projectName === project.name);
    const live = sessions.filter((thread) => thread.status === 'running' || thread.status === 'awaiting-approval');
    const people = input.personFigures.filter((figure) => figure.projectId === project.name);
    const asking = live.filter((thread) => thread.status === 'awaiting-approval').length;
    const working = live.length - asking + people.length;
    const broken = project.status !== 'ok';
    // A tree between some houses, chosen by the project's own name so it never moves.
    if (index > 0 && seed % 3 !== 0) {
      decor.push({
        sprite: seed % 2 === 0 ? 'tree_birch' : 'tree_oak',
        x: cursor - GAP - 8,
        layer: 'back',
        flip: seed % 5 === 0,
      });
    }
    const placed = place({
      id: `project:${project.name}`,
      kind: 'project',
      title: project.name,
      summary: projectSummary(sessions.length, working, asking, broken),
      sprite: HOUSE_SPRITES[seed % HOUSE_SPRITES.length] ?? 'house_a',
      ...SPRITE_SIZE.house,
      lit: working > 0 || asking > 0,
      asking,
      broken,
      projectName: project.name,
      figures: [],
      moreFigures: Math.max(0, live.length + people.length - MAX_FIGURES),
      actions: broken
        ? [
            {
              id: 'projects',
              label: 'Fix in Projects',
              primary: true,
              to: '/workspace',
              params: { project: project.name },
            },
          ]
        : [
            { id: 'new-session', label: 'New session', primary: true, to: '/focus', params: { project: project.name } },
            { id: 'changes', label: 'Changes', to: '/workspace', params: { project: project.name, tab: 'changes' } },
            { id: 'terminal', label: 'Terminal', run: 'open-terminal' },
          ],
    });
    // Sessions waiting for you stand first: they are the ones to notice.
    // Sessions waiting for you stand first: they are the ones to notice.
    const ordered: ValleyFigure[] = [
      ...live
        .sort((a, b) => Number(b.status === 'awaiting-approval') - Number(a.status === 'awaiting-approval'))
        .map((thread) => ({
          id: `figure:${thread.id}`,
          title: thread.title || 'New session',
          to: '/focus',
          params: { thread: thread.id },
          family: FAMILY[thread.provider] ?? 'ember',
          state: thread.status === 'awaiting-approval' ? ('asking' as const) : ('working' as const),
          x: 0,
        })),
      ...people.map((figure) => ({
        id: `figure:${figure.id}`,
        title: `${figure.name} · ${figure.kind}`,
        to: figure.to,
        params: figure.params,
        family: FAMILY[figure.provider] ?? ('ember' as FigureFamily),
        state: 'working' as const,
        x: 0,
      })),
    ];
    placed.figures = ordered.slice(0, MAX_FIGURES).map((figure, slot) => ({
      ...figure,
      x: placed.x + placed.w - 10 + slot * (SPRITE_SIZE.agent.w - 2),
    }));
    decor.push({
      sprite: seed % 2 === 0 ? 'flowers_1' : 'flowers_2',
      x: placed.x + (seed % 20),
      layer: 'front',
      flip: false,
    });
  });

  lamps.push(cursor - GAP / 2 - 5);
  const riverX = cursor;
  const bridgeX = riverX - (SPRITE_SIZE.bridge.w - SPRITE_SIZE.river.w) / 2;
  cursor += SPRITE_SIZE.river.w + 10;
  decor.push({ sprite: 'reeds', x: riverX - 12, layer: 'front', flip: false });

  place({
    id: 'workshop',
    kind: 'workshop',
    title: 'Workshop',
    summary:
      input.attention > 0
        ? `${plural(input.attention, 'thing needs', 'things need')} you`
        : input.jobsRunning > 0
          ? `${plural(input.jobsRunning, 'job', 'jobs')} running`
          : 'Jobs, loops and swarms. Nothing running',
    sprite: 'workshop',
    ...SPRITE_SIZE.workshop,
    lit: input.jobsRunning > 0,
    asking: input.attention,
    broken: false,
    projectName: null,
    figures: [],
    moreFigures: 0,
    actions: [
      { id: 'operations', label: 'Open Operations', primary: true, to: '/operations' },
      { id: 'needs-you', label: input.attention > 0 ? `Needs you (${input.attention})` : 'Needs you', to: '/office' },
      { id: 'health', label: 'Health', to: '/insights' },
    ],
  });

  decor.push({ sprite: 'tree_oak', x: cursor - GAP + 8, layer: 'back', flip: true });
  const content = cursor - GAP + 56 + MARGIN;
  const width = Math.max(content, Math.ceil(input.minWidth));
  // A wide window gets more woodland past the workshop, not stretched buildings.
  for (let x = content - 12, step = 0; x < width - 20; x += 44 + ((step * 13) % 17), step += 1) {
    decor.push({
      sprite: ['tree_pine', 'tree_oak', 'tree_birch'][step % 3] ?? 'tree_oak',
      x,
      layer: 'back',
      flip: step % 2 === 1,
    });
  }

  return { width, places, decor, riverX, bridgeX, wheelTurning: input.jobsRunning > 0, nestX, lamps };
}

/** Where the camera should sit so `place` is comfortably in view. */
export function cameraFor(
  place: Pick<ValleyPlace, 'x' | 'w'>,
  viewWidth: number,
  sceneWidth: number,
  current: number,
): number {
  const max = Math.max(0, sceneWidth - viewWidth);
  const pad = 24;
  let next = current;
  if (place.x - pad < current) next = place.x - pad;
  else if (place.x + place.w + pad > current + viewWidth) next = place.x + place.w + pad - viewWidth;
  return Math.min(max, Math.max(0, Math.round(next)));
}
