import { useQuery } from '@tanstack/react-query';
import { useLayoutEffect, useMemo, useRef, useState, type CSSProperties } from 'react';
import { useNavigate } from 'react-router';
import { requireClient, useBackend } from '../../data/backend';
import { useFocusThreads } from '../../data/focus';
import { useJobs, activeJobIds } from '../../data/jobs';
import { useLinkProject, useProjects } from '../../data/projects';
import { activePersonSessionsForWorkspace } from '../../data/personSessionScope';
import { useTerminalSessions } from '../../data/terminal';
import { useSwarms } from '../../data/swarms';
import { swarmPersonWorldEntries } from '../world/swarmPersonWorld';
import { OPEN_TERMINAL_DOCK_EVENT } from '../../shell/events';
import { useSessionContext } from '../../shell/useSessionContext';
import { useAttention } from '../office/useAttention';
import { Button } from '../../ui';
import { useAppearance } from '../../design/theme';
import { buildValley, SPRITE_SIZE, type ValleyPersonFigure, type ValleyPlace, type ValleyScene } from './model';
import { manifestEntry, valleyUrl, type ValleyManifestEntry } from './assets';
import styles from './valley.module.css';

/** Art coordinates: the lane (ground line) sits at this row of the 200 px scene. */
const LANE = 146;
const SCENE_HEIGHT = 200;
/** Art pixels per screen pixel, chosen from the window so the scene stays readable. */
function scaleFor(height: number): number {
  return height >= 760 ? 3 : 2;
}

/** Where a house's chimney mouth is, in sprite coordinates (from the art build). */
const CHIMNEY: Record<string, [number, number]> = {
  house_a: [46, 1],
  house_b: [47, 9],
  house_c: [44, 6],
  house_d: [49, 8],
};

function Sprite({
  name,
  x,
  bottom,
  scale,
  animate = false,
  className,
}: {
  name: string;
  x: number;
  bottom: number;
  scale: number;
  animate?: boolean;
  className?: string;
}) {
  const entry = manifestEntry(name);
  if (!entry) return null;
  const total = entry.frames * entry.w;
  const style = {
    left: x * scale,
    top: (bottom - entry.h) * scale,
    width: entry.w * scale,
    height: entry.h * scale,
    backgroundImage: `url(${valleyUrl(entry.file)})`,
    backgroundSize: `${total * scale}px ${entry.h * scale}px`,
    '--frames': entry.frames,
    '--fw': `${entry.w * scale}px`,
    '--duration': `${entry.frameMs?.reduce((sum, ms) => sum + ms, 0) ?? 1000}ms`,
  } as CSSProperties;
  return (
    <span
      className={`${styles.sprite} ${animate && entry.frames > 1 ? styles.animated : ''} ${className ?? ''}`}
      style={style}
      aria-hidden="true"
    />
  );
}

function placeSprite(place: ValleyPlace, lit: boolean): string {
  if (place.kind === 'project' || place.kind === 'workshop' || place.kind === 'library' || place.kind === 'lodge') {
    return lit && manifestEntry(`${place.sprite}_lit`) ? `${place.sprite}_lit` : place.sprite;
  }
  return place.sprite;
}

/**
 * The World. A side-on village built only from what is true in the workspace
 * (see model.ts). Every place is also a real button with its actions in the
 * panel below, so nothing requires walking.
 */
export default function ValleyView() {
  const navigate = useNavigate();
  const { backend, client } = useBackend();
  const { href } = useSessionContext();
  const workspace = backend?.harness?.path ?? '';
  const projects = useProjects(workspace);
  const { threads } = useFocusThreads();
  const jobs = useJobs();
  const attention = useAttention();
  const terminals = useTerminalSessions();
  const link = useLinkProject(workspace);
  const people = useQuery({
    queryKey: ['people', workspace],
    queryFn: () => requireClient(client).people(workspace),
    enabled: client !== null && workspace.length > 0,
    staleTime: 15_000,
  });

  // Live Person sessions and swarm workers, scoped to this workspace. A character needs a real session.
  const canonical = useQuery({
    queryKey: ['person-sessions', workspace],
    queryFn: () => requireClient(client).personSessions(workspace),
    enabled: client !== null && workspace.length > 0,
    refetchInterval: 5_000,
  });
  const swarms = useSwarms();
  const livePersonPtys = useMemo(
    () => activePersonSessionsForWorkspace(terminals.sessions, workspace),
    [terminals.sessions, workspace],
  );
  const personFigures: ValleyPersonFigure[] = useMemo(() => {
    const roster = people.data?.people ?? [];
    const peopleById = new Map(roster.map((person) => [person.id, person]));
    const projectNames = (projects.data?.projects ?? []).map((project) => project.name);
    const pty = livePersonPtys.flatMap((session) => {
      const person = session.personId ? peopleById.get(session.personId) : undefined;
      const projectId = session.projectId;
      if (!person || !projectId || !projectNames.includes(projectId)) return [];
      return [
        {
          id: session.id,
          name: person.name,
          kind: 'Person session',
          projectId,
          provider: session.provider ?? 'claude',
          // The person's own page shows the live session and its terminal.
          to: '/people',
          params: { person: person.id, session: session.id },
        },
      ];
    });
    const swarm = swarmPersonWorldEntries({
      sessions: canonical.data?.sessions ?? [],
      runs: swarms.data?.runs ?? [],
      people: roster,
      projectNames,
    }).map((entry) => ({
      id: entry.id,
      name: entry.name,
      kind: 'Person session in a swarm',
      projectId: entry.projectId,
      provider: entry.provider || 'claude',
      to: '/operations',
      params: { swarm: entry.runId },
    }));
    return [...pty, ...swarm];
  }, [livePersonPtys, people.data, projects.data, canonical.data, swarms.data]);

  const viewport = useRef<HTMLDivElement>(null);
  const [viewportSize, setViewportSize] = useState({ width: 0, height: 0 });
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const appearance = useAppearance();

  useLayoutEffect(() => {
    const element = viewport.current;
    if (!element) return;
    const measure = () => setViewportSize({ width: element.clientWidth, height: window.innerHeight });
    const observer = new ResizeObserver(measure);
    observer.observe(element);
    window.addEventListener('resize', measure);
    measure();
    return () => {
      observer.disconnect();
      window.removeEventListener('resize', measure);
    };
  }, []);

  const sceneInput = useMemo(
    () => ({
      projects: projects.data?.projects ?? [],
      threads,
      personFigures,
      jobsRunning: activeJobIds(jobs.data).length,
      attention: attention.items.length,
      people: people.data?.people.length ?? 0,
    }),
    [projects.data, threads, personFigures, jobs.data, attention.items.length, people.data],
  );
  const baseScene = useMemo(() => buildValley({ ...sceneInput, minWidth: 400 }), [sceneInput]);
  const availableWidth = viewportSize.width || window.innerWidth;
  const desiredScale = scaleFor(viewportSize.height || window.innerHeight);
  const scale = Math.max(1, Math.min(desiredScale, Math.floor((availableWidth / baseScene.width) * 4) / 4));

  const scene: ValleyScene = useMemo(
    () => buildValley({ ...sceneInput, minWidth: Math.max(400, Math.round(availableWidth / scale)) }),
    [sceneInput, availableWidth, scale],
  );

  const selected = scene.places.find((place) => place.id === selectedId) ?? null;
  const width = scene.width * scale;

  const runAction = async (place: ValleyPlace, action: 'link-project' | 'open-terminal') => {
    if (action === 'link-project') {
      link.mutate(undefined, {
        onSuccess: (linked) => linked && navigate(href('/workspace', { project: linked.name })),
      });
      return;
    }
    if (!place.projectName) return;
    const project = projects.data?.projects.find((entry) => entry.name === place.projectName);
    if (!project) return;
    const session = await terminals
      .create({ agent: 'shell', cmd: '@shell', cwd: project.target, projectId: project.name })
      .catch(() => null);
    if (session) window.dispatchEvent(new Event(OPEN_TERMINAL_DOCK_EVENT));
  };

  return (
    <div className={styles.page}>
      <div className={styles.head}>
        <div>
          <h1 className={styles.title}>{workspace ? folderName(workspace) : 'Workspace'}</h1>
          <p className={styles.lede}>
            {scene.places.filter((place) => place.kind === 'project').length} projects ·{' '}
            {
              threads.filter(
                (thread) =>
                  thread.status === 'running' ||
                  thread.status === 'awaiting-approval' ||
                  thread.status === 'awaiting-input',
              ).length
            }{' '}
            sessions working
          </p>
        </div>
        <div className={styles.headActions}>
          <Button
            variant="secondary"
            onClick={() =>
              link.mutate(undefined, {
                onSuccess: (linked) => linked && navigate(href('/workspace', { project: linked.name })),
              })
            }
            busy={link.isPending}
            busyLabel="Linking…"
          >
            Link a repository
          </Button>
          {link.error ? (
            <p className={styles.linkError} role="alert">
              {link.error.message}
            </p>
          ) : null}
        </div>
      </div>

      <div className={styles.viewport} ref={viewport} data-testid="valley-viewport">
        <div
          className={styles.scene}
          data-theme={appearance.resolvedTheme}
          style={{ width, height: SCENE_HEIGHT * scale }}
          role="group"
          aria-label="Workspace village"
        >
          <div
            className={styles.sky}
            aria-hidden="true"
            data-testid="valley-sky"
            data-art={appearance.resolvedTheme === 'dusk' ? 'sky_dusk' : 'sky_day'}
            style={{
              backgroundImage: `url(${valleyUrl(appearance.resolvedTheme === 'dusk' ? 'sky_dusk.png' : 'sky_day.png')})`,
              backgroundSize: `${16 * scale}px ${SCENE_HEIGHT * scale}px`,
            }}
          />
          <div className={styles.cloud} aria-hidden="true">
            <Sprite name="cloud_2" x={60} bottom={40} scale={scale} />
            <Sprite name="cloud_1" x={260} bottom={28} scale={scale} />
          </div>
          <Band name="hills_far" bottom={LANE - 10} width={width} scale={scale} />
          <Band name="hills_mid" bottom={LANE - 10} width={width} scale={scale} />
          <Band name="ground" bottom={LANE + 54} width={width} scale={scale} />

          {scene.decor
            .filter((item) => item.layer === 'back')
            .map((item, index) => (
              <Sprite
                key={`b${index}`}
                name={item.sprite}
                x={item.x}
                bottom={LANE}
                scale={scale}
                className={item.flip ? styles.flip : ''}
              />
            ))}

          <Sprite name="river" x={scene.riverX} bottom={LANE + 54} scale={scale} />
          <Sprite name="bridge" x={scene.bridgeX} bottom={LANE + 18} scale={scale} />
          {scene.lamps.map((x, index) => (
            <Sprite
              key={`lamp-${index}`}
              name={appearance.resolvedTheme === 'dusk' ? 'lamp_post_lit' : 'lamp_post'}
              x={x}
              bottom={LANE}
              scale={scale}
              className={appearance.resolvedTheme === 'dusk' ? styles.lit : undefined}
            />
          ))}

          {scene.places.map((place) => {
            const lit = place.lit;
            const spriteName = placeSprite(place, lit);
            const isHouse = place.kind === 'project';
            return (
              <div key={place.id}>
                <Sprite
                  name={spriteName}
                  x={place.x}
                  bottom={LANE}
                  scale={scale}
                  className={lit ? styles.lit : undefined}
                />
                {isHouse && lit && CHIMNEY[place.sprite] ? (
                  <Sprite
                    name="smoke"
                    x={place.x + (CHIMNEY[place.sprite]?.[0] ?? 0) - 8}
                    bottom={LANE - (SPRITE_SIZE.house.h - (CHIMNEY[place.sprite]?.[1] ?? 0))}
                    scale={scale}
                    animate
                  />
                ) : null}
                {place.kind === 'workshop' ? (
                  <Sprite name="wheel" x={place.x} bottom={LANE - 16} scale={scale} animate={scene.wheelTurning} />
                ) : null}
                <button
                  type="button"
                  className={styles.hit}
                  data-entity-id={`place:${place.id}`}
                  aria-pressed={selected?.id === place.id}
                  aria-label={`${place.title}: ${place.summary}`}
                  style={{
                    left: place.x * scale,
                    top: (LANE - place.h) * scale,
                    width: place.w * scale,
                    height: place.h * scale,
                  }}
                  onClick={() => setSelectedId(place.id)}
                  data-broken={place.broken || undefined}
                />
                <span
                  className={styles.label}
                  style={{ left: (place.x + place.w / 2) * scale, top: (LANE - place.h - 4) * scale }}
                >
                  {place.title}
                  {place.asking > 0 ? <span className={styles.asking}>{place.asking}</span> : null}
                </span>
              </div>
            );
          })}

          {scene.places.flatMap((place) =>
            place.figures.map((figure) => {
              const state = figure.state === 'asking' ? 'ask' : 'work';
              const name = `agent_${state}_${figure.family}`;
              return (
                <button
                  key={figure.id}
                  type="button"
                  className={styles.figure}
                  aria-label={`${figure.title} · session open · ${figure.state === 'asking' ? 'needs your answer' : 'working'}`}
                  style={{
                    left: figure.x * scale,
                    top: (LANE - SPRITE_SIZE.agent.h) * scale,
                    width: SPRITE_SIZE.agent.w * scale,
                    height: SPRITE_SIZE.agent.h * scale,
                  }}
                  onClick={() => navigate(href(figure.to, figure.params))}
                >
                  <Sprite name={name} x={0} bottom={SPRITE_SIZE.agent.h} scale={scale} animate />
                </button>
              );
            }),
          )}

          {scene.decor
            .filter((item) => item.layer === 'front')
            .map((item, index) => (
              <Sprite key={`f${index}`} name={item.sprite} x={item.x} bottom={LANE + 4} scale={scale} />
            ))}
        </div>
      </div>

      <section className={styles.panel} aria-live="polite" aria-label="Selected place">
        {selected ? (
          <>
            <div className={styles.panelText}>
              <h2 className={styles.panelTitle}>{selected.title}</h2>
              <p className={styles.panelSummary}>{selected.summary}</p>
            </div>
            <div className={styles.actions}>
              {selected.actions.map((action) =>
                'to' in action ? (
                  <button
                    key={action.id}
                    type="button"
                    data-primary={action.primary || undefined}
                    onClick={() => navigate(href(action.to, action.params))}
                  >
                    {action.label}
                  </button>
                ) : (
                  <button
                    key={action.id}
                    type="button"
                    data-primary={action.primary || undefined}
                    onClick={() => void runAction(selected, action.run)}
                  >
                    {action.label}
                  </button>
                ),
              )}
            </div>
          </>
        ) : (
          <p className={styles.panelSummary}>
            Choose a place to see what is true there and what you can do. Characters appear only while a session is
            running.
          </p>
        )}
      </section>
    </div>
  );
}

/** A horizontally tiling strip along the bottom of the scene. */
function Band({ name, bottom, width, scale }: { name: string; bottom: number; width: number; scale: number }) {
  const entry: ValleyManifestEntry | undefined = manifestEntry(name);
  if (!entry) return null;
  return (
    <span
      aria-hidden="true"
      className={styles.band}
      style={{
        bottom: (SCENE_HEIGHT - bottom) * scale,
        width,
        height: entry.h * scale,
        backgroundImage: `url(${valleyUrl(entry.file)})`,
        backgroundSize: `${entry.w * scale}px ${entry.h * scale}px`,
      }}
    />
  );
}

function folderName(path: string): string {
  return path.split(/[\\/]/).filter(Boolean).at(-1) ?? path;
}
