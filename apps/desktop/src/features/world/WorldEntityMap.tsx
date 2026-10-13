import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type KeyboardEvent as ReactKeyboardEvent,
  type ReactNode,
} from 'react';
import { Link } from 'react-router';
import { StatusBadge, Table, VisuallyHidden, type Tone } from '../../ui';
import { clampCamera, fitCamera, WORLD_ZOOMS, zoomCamera } from './camera';
import { entityActivateLabel, entityActivateVerb, entityHasInspector } from './inspectors';
import { paintInterior, paintTerrain, type DecorSprite, type LaidOutEntity } from './model';
import spriteManifest from './manifest.json';
import { TerrainCanvas } from './TerrainRenderer';
import { nearestWorldNeighbor, type WorldDirection } from './spatialNavigation';
import {
  findWorldSpawn,
  nearbyWorldTarget,
  restoreWorldPosition,
  findWorldPath,
  stepWorldPlayer,
  stepWorldPlayerToward,
  worldCellKey,
  type WorldPoint,
} from './player';
import { resolveEntityAsset, type WorldThemePack } from './theme/cozyValley';
import styles from './world.module.css';

export type WorldHref = (path: string, extra?: Record<string, string | undefined>) => string;

function toneForState(state: string): Tone {
  if (
    state === 'ok' ||
    state === 'running' ||
    state === 'known' ||
    state === 'ready' ||
    state === 'present' ||
    state === 'calm' ||
    state.endsWith(' active')
  ) {
    return 'ok';
  }
  if (
    state === 'broken' ||
    state === 'failed' ||
    state === 'rejected' ||
    state === 'err' ||
    state === 'missing' ||
    state === 'needs attention'
  ) {
    return 'err';
  }
  if (state === 'queued' || state === 'notice' || state === 'empty' || state === 'unavailable') return 'warn';
  if (state === 'inspector' || state === 'catalog') return 'info';
  return 'idle';
}

function activateEntity(
  entity: LaidOutEntity,
  onSelect: (id: string) => void,
  onActivate: (entity: LaidOutEntity) => void,
): void {
  onSelect(entity.id);
  if (entityHasInspector(entity)) onActivate(entity);
}

/** Character sprite variant by stable entity hash (never runtime state). */
function characterSprite(id: string, themeKey: string, durableSprite?: string): string {
  if (durableSprite) return durableSprite;
  let hash = 0;
  for (let i = 0; i < id.length; i += 1) hash = (hash * 31 + id.charCodeAt(i)) >>> 0;
  const variants = ['char-teal', 'char-gold', 'char-brick'];
  void themeKey;
  return variants[hash % variants.length]!;
}

export interface WorldEntityMapProps {
  entities: readonly LaidOutEntity[];
  selectedId: string | null;
  theme: WorldThemePack;
  cols: number;
  rows: number;
  ariaLabel: string;
  mode: 'grounds' | 'interior';
  persistKey?: string;
  /** Stable workspace identity shared by exterior/interior views. */
  appearanceKey?: string;
  /** Hidden inspector panel — pause terrain/CSS animation, keep manual zoom. */
  suspended?: boolean;
  onSelect: (id: string) => void;
  onActivate: (entity: LaidOutEntity) => void;
}

/** Integer zoom steps (display px per 16px source tile). */
const ZOOMS = WORLD_ZOOMS;
const PLAYER_APPEARANCES = ['river', 'grove', 'ember'] as const;
type PlayerAppearance = (typeof PLAYER_APPEARANCES)[number];

function isPlayerAppearance(value: string | null): value is PlayerAppearance {
  return value !== null && PLAYER_APPEARANCES.includes(value as PlayerAppearance);
}

/** Sprite manifest dimensions by sprite id (generator-owned; sprites keep their authored size). */
type SpriteManifestEntry = { file: string; w: number; h: number; frames: number };

function manifestEntry(spriteId: string | undefined): SpriteManifestEntry | undefined {
  if (!spriteId) return undefined;
  const sprites = spriteManifest.sprites as Record<string, SpriteManifestEntry>;
  return sprites[spriteId];
}

/**
 * The world is the screen: terrain canvas + décor + semantic entities inside
 * a camera viewport with integer zoom, drag/arrow pan, and fit-to-world.
 */
export function WorldEntityMap({
  entities,
  selectedId,
  theme,
  cols,
  rows,
  ariaLabel,
  mode,
  persistKey = 'workspace|grounds',
  appearanceKey = persistKey,
  suspended = false,
  onSelect,
  onActivate,
}: WorldEntityMapProps): ReactNode {
  const regionRef = useRef<HTMLDivElement>(null);
  const [zoom, setZoom] = useState<number>(48);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [cameraMode, setCameraMode] = useState<'frame' | 'fit' | 'manual' | 'follow'>('frame');
  const [hoveredId, setHoveredId] = useState<string | null>(null);
  const drag = useRef<{ x: number; y: number; panX: number; panY: number; moved: boolean } | null>(null);
  const suppressClick = useRef(false);
  const [tabVisible, setTabVisible] = useState(() => document.visibilityState !== 'hidden');
  const [playerPosition, setPlayerPosition] = useState<WorldPoint>({ x: 1.5, y: 1.5 });
  const [playerDirection, setPlayerDirection] = useState<'north' | 'south' | 'east' | 'west'>('south');
  const [playerWalking, setPlayerWalking] = useState(false);
  const [playerAppearance, setPlayerAppearance] = useState<PlayerAppearance>('river');
  const [playerReadyKey, setPlayerReadyKey] = useState('');
  const [nearbyId, setNearbyId] = useState<string | null>(null);
  const panFocusRef = useRef<HTMLButtonElement>(null);
  const startPathRef = useRef<() => void>(() => {});
  const followCameraRef = useRef<() => void>(() => {});
  const playerPositionRef = useRef(playerPosition);
  const restoredKeyRef = useRef<string | null>(null);
  const pathRef = useRef<WorldPoint[]>([]);

  useEffect(() => {
    let stored: string | null = null;
    try {
      stored = window.localStorage.getItem(`agent-toolkit:world-player-appearance:${appearanceKey}`);
    } catch {
      // Appearance storage is optional; the default remains available.
    }
    setPlayerAppearance(isPlayerAppearance(stored) ? stored : 'river');
  }, [appearanceKey]);

  useEffect(() => {
    const update = () => setTabVisible(document.visibilityState !== 'hidden');
    document.addEventListener('visibilitychange', update);
    return () => document.removeEventListener('visibilitychange', update);
  }, []);

  const sourceTile = theme.sourceTile;
  const worldW = cols * sourceTile;
  const worldH = rows * sourceTile;
  const scale = zoom / sourceTile;
  const viewW = worldW * scale;
  const viewH = worldH * scale;
  const animate = tabVisible && !suspended;

  const plan = useMemo(
    () => (mode === 'grounds' ? paintTerrain(entities, cols, rows) : paintInterior(entities, cols, rows)),
    [mode, entities, cols, rows],
  );
  const collisionMap = useMemo(
    () => ({ cols, rows, blocked: new Set(plan.collisionCells) }),
    [cols, rows, plan.collisionCells],
  );
  const movementStateRef = useRef({ collisionMap, entities, zoom, viewW, viewH, cameraMode });
  movementStateRef.current = { collisionMap, entities, zoom, viewW, viewH, cameraMode };
  followCameraRef.current = () => {
    const current = movementStateRef.current;
    if (current.cameraMode === 'follow') return;
    const closerZoom = ZOOMS.find((step) => step > current.zoom);
    if (closerZoom !== undefined) {
      movementStateRef.current = {
        ...current,
        zoom: closerZoom,
        viewW: cols * closerZoom,
        viewH: rows * closerZoom,
        cameraMode: 'follow',
      };
      setZoom(closerZoom);
    } else {
      movementStateRef.current = { ...current, cameraMode: 'follow' };
    }
    setCameraMode('follow');
  };
  const pathCells = useMemo(
    () =>
      new Set(
        plan.cells
          .filter((cell) => cell.tile.startsWith('trail-') || cell.tile === 'bridge')
          .map((cell) => worldCellKey(cell.x, cell.y)),
      ),
    [plan.cells],
  );
  const spawnPoint = useMemo(() => {
    const hall = entities.find((entity) => entity.id === 'place:workspace');
    const preferred =
      mode === 'interior'
        ? { x: cols / 2, y: Math.max(1, rows - 3) }
        : hall
          ? { x: hall.x + hall.w / 2, y: hall.y + hall.h + 2 }
          : { x: cols / 2, y: rows / 2 };
    return findWorldSpawn(collisionMap, preferred, pathCells);
  }, [collisionMap, cols, entities, mode, pathCells, rows]);
  const playerStartKey = useMemo(
    () => `${persistKey}:${cols}x${rows}:${spawnPoint.x},${spawnPoint.y}:${plan.collisionCells.join('|')}`,
    [cols, persistKey, plan.collisionCells, rows, spawnPoint.x, spawnPoint.y],
  );
  const playerReady = playerReadyKey === playerStartKey;
  const nearbyEntity = useMemo(() => entities.find((entity) => entity.id === nearbyId) ?? null, [entities, nearbyId]);
  const nearbyEntityRef = useRef(nearbyEntity);
  const activateRef = useRef({ onSelect, onActivate });
  nearbyEntityRef.current = nearbyEntity;
  activateRef.current = { onSelect, onActivate };

  useEffect(() => {
    let stored: string | null = null;
    try {
      stored = window.localStorage.getItem(`agent-toolkit:world-player:${persistKey}`);
    } catch {
      // Browser storage can be disabled; exploration remains available.
    }
    const currentPosition = restoredKeyRef.current === persistKey ? JSON.stringify(playerPositionRef.current) : stored;
    const restored = restoreWorldPosition(currentPosition, spawnPoint, collisionMap);
    restoredKeyRef.current = persistKey;
    playerPositionRef.current = restored;
    setPlayerPosition(restored);
    setNearbyId(null);
    setPlayerReadyKey(playerStartKey);
  }, [collisionMap, persistKey, playerStartKey, spawnPoint]);

  useEffect(() => {
    const target = nearbyWorldTarget(playerPosition, entities, entityHasInspector);
    setNearbyId((current) => (current === target?.id ? current : (target?.id ?? null)));
  }, [entities, playerPosition]);

  useEffect(() => {
    const region = regionRef.current;
    const focusTarget = panFocusRef.current;
    if (!region || !focusTarget) return;
    const held = new Map<string, 'north' | 'south' | 'east' | 'west'>();
    let animationFrame: number | null = null;
    let previousFrame = 0;
    let lastUiFrame = 0;
    let lastPersist = 0;
    const controls = new Map<string, 'north' | 'south' | 'east' | 'west'>([
      ['w', 'north'],
      ['arrowup', 'north'],
      ['s', 'south'],
      ['arrowdown', 'south'],
      ['a', 'west'],
      ['arrowleft', 'west'],
      ['d', 'east'],
      ['arrowright', 'east'],
    ]);
    const isFocused = () => region.contains(document.activeElement);
    const isTyping = (target: EventTarget | null) => {
      if (!(target instanceof HTMLElement)) return false;
      return target.isContentEditable || Boolean(target.closest('input, textarea, select, [role="dialog"], .xterm'));
    };
    const writePosition = (position: WorldPoint) => {
      playerPositionRef.current = position;
      setPlayerPosition(position);
      try {
        window.localStorage.setItem(`agent-toolkit:world-player:${persistKey}`, JSON.stringify(position));
      } catch {
        // Local persistence is optional; it must never block movement.
      }
    };
    const cancelMovement = () => {
      held.clear();
      pathRef.current = [];
      writePosition(playerPositionRef.current);
      if (animationFrame !== null) cancelAnimationFrame(animationFrame);
      animationFrame = null;
      setPlayerWalking(false);
    };
    const tick = (now: number) => {
      if (!isFocused() || (document.activeElement !== focusTarget && document.activeElement !== region)) {
        cancelMovement();
        return;
      }
      const elapsed = previousFrame ? Math.min(50, now - previousFrame) : 16;
      previousFrame = now;
      const { collisionMap, entities, zoom, viewW, viewH } = movementStateRef.current;
      const directions = [...held.values()];
      const input = {
        north: directions.includes('north'),
        south: directions.includes('south'),
        east: directions.includes('east'),
        west: directions.includes('west'),
      };
      let next: WorldPoint;
      if (held.size > 0) {
        next = stepWorldPlayer(playerPositionRef.current, input, elapsed, collisionMap);
      } else {
        let waypoint = pathRef.current[0];
        while (
          waypoint &&
          Math.hypot(waypoint.x - playerPositionRef.current.x, waypoint.y - playerPositionRef.current.y) < 0.03
        ) {
          pathRef.current.shift();
          waypoint = pathRef.current[0];
        }
        next = waypoint
          ? stepWorldPlayerToward(playerPositionRef.current, waypoint, elapsed, collisionMap)
          : playerPositionRef.current;
        if (waypoint) {
          const dx = waypoint.x - playerPositionRef.current.x;
          const dy = waypoint.y - playerPositionRef.current.y;
          setPlayerDirection(Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'east' : 'west') : dy > 0 ? 'south' : 'north');
        }
      }
      const moved = next.x !== playerPositionRef.current.x || next.y !== playerPositionRef.current.y;
      setPlayerWalking(moved);
      if (moved) {
        playerPositionRef.current = next;
        const target = nearbyWorldTarget(next, entities, entityHasInspector);
        setNearbyId((current) => (current === target?.id ? current : (target?.id ?? null)));
        if (now - lastUiFrame >= 32) {
          lastUiFrame = now;
          setPlayerPosition(next);
          const cameraPan = clampCamera(
            {
              x: Math.floor(region.clientWidth / 2 - next.x * zoom),
              y: Math.floor(region.clientHeight / 2 - next.y * zoom),
            },
            { x: region.clientWidth, y: region.clientHeight },
            { x: viewW, y: viewH },
          );
          setPan(cameraPan);
        }
        if (now - lastPersist > 750) {
          lastPersist = now;
          try {
            window.localStorage.setItem(`agent-toolkit:world-player:${persistKey}`, JSON.stringify(next));
          } catch {
            // Local persistence is optional.
          }
        }
      }
      if (held.size > 0 || pathRef.current.length > 0) animationFrame = requestAnimationFrame(tick);
      else {
        animationFrame = null;
        setPlayerWalking(false);
      }
    };
    startPathRef.current = () => {
      if (animationFrame !== null || pathRef.current.length === 0) return;
      previousFrame = 0;
      animationFrame = requestAnimationFrame(tick);
    };
    const onKeyDown = (event: globalThis.KeyboardEvent) => {
      if (!isFocused() || isTyping(event.target) || event.altKey || event.ctrlKey || event.metaKey) return;
      // Keep spatial focus navigation and screen-reader shortcuts intact.
      if (document.activeElement !== focusTarget && document.activeElement !== region) return;
      const direction = controls.get(event.key.toLowerCase());
      if (direction) {
        event.preventDefault();
        pathRef.current = [];
        followCameraRef.current();
        setPlayerDirection(direction);
        held.set(event.key.toLowerCase(), direction);
        if (animationFrame === null) {
          previousFrame = 0;
          animationFrame = requestAnimationFrame(tick);
        }
        return;
      }
      if (event.key.toLowerCase() === 'e' && nearbyEntityRef.current) {
        event.preventDefault();
        activateEntity(nearbyEntityRef.current, activateRef.current.onSelect, activateRef.current.onActivate);
        setPlayerWalking(false);
      }
    };
    const onKeyUp = (event: globalThis.KeyboardEvent) => {
      const direction = controls.get(event.key.toLowerCase());
      if (!direction) return;
      held.delete(event.key.toLowerCase());
      if (held.size === 0) {
        if (animationFrame !== null) cancelAnimationFrame(animationFrame);
        animationFrame = null;
        writePosition(playerPositionRef.current);
        setPlayerWalking(false);
      }
    };
    const onBlur = () => cancelMovement();
    const onVisibilityChange = () => {
      if (document.visibilityState === 'hidden') cancelMovement();
    };
    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);
    window.addEventListener('blur', onBlur);
    document.addEventListener('visibilitychange', onVisibilityChange);
    return () => {
      startPathRef.current = () => {};
      cancelMovement();
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('keyup', onKeyUp);
      window.removeEventListener('blur', onBlur);
      document.removeEventListener('visibilitychange', onVisibilityChange);
    };
  }, [persistKey]);

  const fitWorld = useCallback(() => {
    const region = regionRef.current;
    if (!region) return;
    // Use the largest crisp integer scale that shows the complete valley.
    const camera = fitCamera({ x: region.clientWidth, y: region.clientHeight }, { x: cols, y: rows });
    setZoom(camera.zoom);
    setPan(
      clampCamera(
        camera.pan,
        { x: region.clientWidth, y: region.clientHeight },
        { x: cols * camera.zoom, y: rows * camera.zoom },
      ),
    );
  }, [cols, rows]);

  useEffect(() => {
    if (cameraMode === 'manual' || cameraMode === 'follow') return;
    fitWorld();
  }, [cameraMode, fitWorld]);

  useEffect(() => {
    const region = regionRef.current;
    if (!region) return;
    const observer = new ResizeObserver(() => {
      // ResizeObserver may deliver a queued notification after walking switches
      // the camera to follow mode. Read the latest geometry and mode so a stale
      // frame-mode measurement cannot snap the camera back out of player follow.
      const current = movementStateRef.current;
      if (current.cameraMode === 'follow') {
        const viewport = { x: region.clientWidth, y: region.clientHeight };
        if (current.viewW < viewport.x && current.viewH < viewport.y) {
          const camera = fitCamera(viewport, { x: cols, y: rows });
          setZoom(camera.zoom);
          setPan(camera.pan);
        } else {
          setPan(
            clampCamera(
              {
                x: viewport.x / 2 - playerPositionRef.current.x * current.zoom,
                y: viewport.y / 2 - playerPositionRef.current.y * current.zoom,
              },
              viewport,
              { x: current.viewW, y: current.viewH },
            ),
          );
        }
      } else if (current.cameraMode !== 'manual') {
        fitWorld();
      } else {
        setPan((p) =>
          clampCamera(p, { x: region.clientWidth, y: region.clientHeight }, { x: current.viewW, y: current.viewH }),
        );
      }
    });
    observer.observe(region);
    return () => observer.disconnect();
  }, [cameraMode, cols, fitWorld, rows, viewW, viewH, zoom]);

  const clampPan = useCallback(
    (x: number, y: number) => {
      const region = regionRef.current;
      return clampCamera(
        { x, y },
        { x: region?.clientWidth ?? 0, y: region?.clientHeight ?? 0 },
        { x: viewW, y: viewH },
      );
    },
    [viewW, viewH],
  );

  const onPointerDown = (event: React.PointerEvent<HTMLDivElement>) => {
    if (event.button !== 0) return;
    if ((event.target as HTMLElement).closest('[aria-label="Map view controls"]')) return;
    suppressClick.current = false;
    drag.current = { x: event.clientX, y: event.clientY, panX: pan.x, panY: pan.y, moved: false };
  };
  const walkToPoint = (clientX: number, clientY: number, target: EventTarget | null) => {
    if (!(target instanceof HTMLElement)) return;
    if (target.closest('[data-activates="true"], [aria-label="Map view controls"]')) return;
    const region = regionRef.current;
    if (!region) return;
    const rect = region.getBoundingClientRect();
    const worldTarget = {
      x: (clientX - rect.left - pan.x) / zoom,
      y: (clientY - rect.top - pan.y) / zoom,
    };
    pathRef.current = findWorldPath(playerPositionRef.current, worldTarget, collisionMap);
    if (pathRef.current.length === 0) return;
    panFocusRef.current?.focus();
    followCameraRef.current();
    startPathRef.current();
  };
  const onPointerMove = (event: React.PointerEvent<HTMLDivElement>) => {
    if (!drag.current) return;
    const { x, y, panX, panY } = drag.current;
    // A sub-threshold move is still a click: only real drags pan and suppress activation.
    if (!drag.current.moved && Math.hypot(event.clientX - x, event.clientY - y) < 5) return;
    if (!drag.current.moved) {
      drag.current.moved = true;
      suppressClick.current = true;
      event.currentTarget.setPointerCapture?.(event.pointerId);
    }
    movementStateRef.current = { ...movementStateRef.current, cameraMode: 'manual' };
    setCameraMode('manual');
    setPan(clampPan(panX + event.clientX - x, panY + event.clientY - y));
  };
  const onPointerUp = (event: React.PointerEvent<HTMLDivElement>) => {
    const shouldWalk = event.type === 'pointerup' && event.button === 0 && drag.current !== null && !drag.current.moved;
    if (event.currentTarget.hasPointerCapture?.(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
    drag.current = null;
    if (shouldWalk) walkToPoint(event.clientX, event.clientY, event.target);
  };

  const onKeyDown = (event: ReactKeyboardEvent<HTMLElement>) => {
    if (event.key === 'Home') {
      movementStateRef.current = { ...movementStateRef.current, cameraMode: 'fit' };
      setCameraMode('fit');
      event.preventDefault();
    }
  };

  const moveEntityFocus = (currentId: string, direction: WorldDirection) => {
    const nextId = nearestWorldNeighbor(entities, currentId, direction);
    if (!nextId) return;
    const next = [...(regionRef.current?.querySelectorAll<HTMLButtonElement>('[data-activates="true"]') ?? [])].find(
      (button) => button.dataset.entityId === nextId,
    );
    next?.focus();
  };

  const changeZoom = (next: number) => {
    const region = regionRef.current;
    movementStateRef.current = {
      ...movementStateRef.current,
      zoom: next,
      viewW: cols * next,
      viewH: rows * next,
      cameraMode: 'manual',
    };
    setCameraMode('manual');
    if (region) {
      setPan(zoomCamera(pan, zoom, next, { x: region.clientWidth, y: region.clientHeight }, { x: cols, y: rows }));
    }
    setZoom(next);
  };
  const zoomIn = () => changeZoom(ZOOMS.find((s) => s > zoom) ?? ZOOMS[ZOOMS.length - 1]!);
  const zoomOut = () => changeZoom([...ZOOMS].reverse().find((s) => s < zoom) ?? 16);

  return (
    <div
      ref={regionRef}
      className={styles.mapRegion}
      style={
        mode === 'grounds'
          ? { backgroundImage: "url('/world/grass-a.png')", backgroundSize: `${zoom}px ${zoom}px` }
          : undefined
      }
      role="application"
      aria-label={ariaLabel}
      data-theme={theme.id}
      data-mode={mode}
      data-zoom={zoom}
      data-camera-mode={cameraMode}
      data-player-ready={playerReady ? 'true' : 'false'}
      data-suspended={!animate ? 'true' : undefined}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerUp}
      onClickCapture={(event) => {
        // A drag that started on an entity must not open its inspector.
        if (suppressClick.current && event.detail !== 0) {
          event.preventDefault();
          event.stopPropagation();
          suppressClick.current = false;
        }
      }}
    >
      {/* Keyboard pan lives on a real button so the map region itself stays non-interactive. */}
      <button
        ref={panFocusRef}
        type="button"
        className={styles.panFocus}
        aria-label="Explore the world. Use WASD or arrow keys to walk, E to interact, Home to fit the world. Tab to places for direct access."
        onKeyDown={onKeyDown}
      />
      <div
        className={styles.mapWorld}
        data-world-map="true"
        style={{ transform: `translate(${pan.x}px, ${pan.y}px)`, width: viewW, height: viewH }}
      >
        <TerrainCanvas
          theme={theme}
          cells={plan.cells}
          cols={cols}
          rows={rows}
          mode={mode}
          animate={animate}
          tileSize={zoom}
        />
        {plan.decor
          .filter((d) => !d.over)
          .map((d) => (
            <DecorSpriteView key={d.id} decor={d} theme={theme} scale={scale} />
          ))}
        {entities.map((entity) => (
          <EntityTile
            key={entity.id}
            entity={entity}
            theme={theme}
            selectedId={selectedId}
            mode={mode}
            tileSize={zoom}
            onSelect={onSelect}
            onActivate={onActivate}
            onHover={setHoveredId}
            onMoveFocus={moveEntityFocus}
          />
        ))}
        <span
          className={styles.playerActor}
          data-direction={playerDirection}
          data-ready={playerReady ? 'true' : undefined}
          data-walking={playerWalking ? 'true' : undefined}
          role="img"
          aria-label="You, exploring the workspace"
          style={{
            left: playerPosition.x * zoom,
            top: playerPosition.y * zoom,
            width: zoom,
            height: zoom * 1.5,
            backgroundImage: `url('/world/char-player-${playerAppearance}-${playerDirection}.png')`,
            visibility: playerReady ? 'visible' : 'hidden',
            ['--frames' as string]: 4,
          }}
        />
        {plan.decor
          .filter((d) => d.over)
          .map((d) => (
            <DecorSpriteView key={d.id} decor={d} theme={theme} scale={scale} />
          ))}
        {entities
          .filter((entity) => entity.kind !== 'character' && (entity.id === selectedId || entity.id === hoveredId))
          .map((entity) => (
            <span
              key={`label:${entity.id}`}
              className={styles.worldLabel}
              data-entity-label-for={entity.id}
              aria-hidden="true"
              data-label-kind={entity.kind}
              data-selected={entity.id === selectedId || entity.id === hoveredId ? 'true' : undefined}
              style={{
                left: (entity.x + entity.w / 2) * zoom,
                top: (entity.y + entity.h) * zoom + 2,
                ['--world-tile-size' as string]: `${zoom}px`,
              }}
            >
              {entity.name}
            </span>
          ))}
      </div>
      <div className={styles.cameraHud} role="group" aria-label="Map view controls">
        <button
          type="button"
          className={styles.hudButton}
          onClick={() => panFocusRef.current?.focus()}
          aria-label="Explore by walking"
          title="Walk with WASD or arrow keys"
        >
          Walk
        </button>
        <label className={styles.appearanceControl}>
          <span className={styles.appearanceLabel}>Coat</span>
          <select
            aria-label="Your appearance"
            className={styles.appearanceSelect}
            value={playerAppearance}
            onChange={(event) => {
              const value = event.currentTarget.value;
              if (!isPlayerAppearance(value)) return;
              setPlayerAppearance(value);
              try {
                window.localStorage.setItem(`agent-toolkit:world-player-appearance:${appearanceKey}`, value);
              } catch {
                // Customization remains available for this session if storage is disabled.
              }
            }}
          >
            <option value="river">River</option>
            <option value="grove">Grove</option>
            <option value="ember">Ember</option>
          </select>
        </label>
        <button type="button" className={styles.hudButton} onClick={zoomOut} aria-label="Zoom out">
          −
        </button>
        <button type="button" className={styles.hudButton} onClick={zoomIn} aria-label="Zoom in">
          +
        </button>
        <button
          type="button"
          className={styles.hudButton}
          onClick={() => {
            setCameraMode('fit');
            fitWorld();
          }}
          aria-label="Fit world"
        >
          ⌂
        </button>
      </div>
      <div className={styles.exploreHint} role="status" aria-live="polite">
        {nearbyEntity ? (
          <>
            <strong>{nearbyEntity.name}</strong>
            <span>
              Press <kbd>E</kbd> to {entityActivateVerb(nearbyEntity).toLowerCase()}
            </span>
          </>
        ) : (
          <span>
            Click ground or use <kbd>WASD</kbd> / <kbd>←↑↓→</kbd> to walk <i aria-hidden="true">·</i> move close and
            press <kbd>E</kbd> to interact
          </span>
        )}
      </div>
    </div>
  );
}

function DecorSpriteView({ decor, theme, scale }: { decor: DecorSprite; theme: WorldThemePack; scale: number }) {
  const asset = theme.decor?.[decor.sprite] ?? theme.interior?.[decor.sprite];
  if (!asset || asset.kind !== 'sprite') return null;
  return (
    <span
      aria-hidden="true"
      className={styles.decorSprite}
      data-ambient={decor.ambient ? 'true' : undefined}
      data-sprite={decor.sprite}
      style={{
        left: (decor.x * theme.sourceTile + decor.dx) * scale,
        top: (decor.y * theme.sourceTile + decor.dy) * scale,
        width: decor.w * scale,
        height: decor.h * scale,
        backgroundImage: `url(${asset.src})`,
        ['--frames' as string]: asset.frames ?? 1,
      }}
    />
  );
}

function EntityTile({
  entity,
  theme,
  selectedId,
  mode,
  tileSize,
  onSelect,
  onActivate,
  onHover,
  onMoveFocus,
}: {
  entity: LaidOutEntity;
  theme: WorldThemePack;
  selectedId: string | null;
  mode: 'grounds' | 'interior';
  tileSize: number;
  onSelect: (id: string) => void;
  onActivate: (entity: LaidOutEntity) => void;
  onHover: (id: string | null) => void;
  onMoveFocus: (id: string, direction: WorldDirection) => void;
}) {
  const asset = resolveEntityAsset(theme, entity);
  const isCharacter = entity.kind === 'character';
  const spriteName = isCharacter ? characterSprite(entity.id, entity.themeKey, entity.characterSprite) : null;
  const src =
    asset.kind === 'sprite'
      ? spriteName
        ? `/world/${spriteName}.png`
        : mode === 'interior'
          ? interiorOverride(theme, entity.themeKey, asset.src)
          : asset.src
      : null;
  // Sprites keep their manifest dimensions, scaled by the camera; the hit box
  // keeps its semantic footprint. Anchored bottom-center like a standing figure.
  const sprite = manifestEntry(
    src
      ?.split('/')
      .pop()
      ?.replace(/\.png$/, ''),
  );
  const frames = sprite?.frames ?? (asset.kind === 'sprite' ? (asset.frames ?? 1) : 1);
  const spriteScale = tileSize / theme.sourceTile;
  const canInspect = entityHasInspector(entity);
  const EntityControl = canInspect ? 'button' : 'span';
  const onKeyDown = (event: ReactKeyboardEvent<HTMLButtonElement>) => {
    const direction = event.key.replace('Arrow', '').toLowerCase() as WorldDirection;
    if (canInspect && ['up', 'down', 'left', 'right'].includes(direction)) {
      event.preventDefault();
      onMoveFocus(entity.id, direction);
      return;
    }
    if (canInspect && (event.key === 'Enter' || event.key === ' ')) {
      event.preventDefault();
      activateEntity(entity, onSelect, onActivate);
    }
  };
  return (
    <EntityControl
      type={canInspect ? 'button' : undefined}
      className={styles.entity}
      data-kind={entity.kind}
      data-theme-key={entity.themeKey}
      data-entity-id={entity.id}
      data-activity={entity.activity ?? 'calm'}
      data-state={entity.state}
      data-activates={canInspect ? 'true' : 'false'}
      data-selected={entity.id === selectedId ? 'true' : undefined}
      title={entityActivateLabel(entity)}
      aria-label={canInspect ? entityActivateLabel(entity) : undefined}
      aria-hidden={!canInspect}
      tabIndex={canInspect ? 0 : undefined}
      aria-describedby={canInspect ? `world-entity-tip-${encodeURIComponent(entity.id)}` : undefined}
      aria-keyshortcuts={canInspect ? 'ArrowUp ArrowDown ArrowLeft ArrowRight Enter' : undefined}
      style={{
        left: entity.x * tileSize,
        top: entity.y * tileSize,
        width: entity.w * tileSize,
        height: entity.h * tileSize,
        ['--world-tile-size' as string]: `${tileSize}px`,
      }}
      onClick={canInspect ? () => activateEntity(entity, onSelect, onActivate) : undefined}
      onKeyDown={canInspect ? onKeyDown : undefined}
      onMouseEnter={canInspect ? () => onHover(entity.id) : undefined}
      onMouseLeave={canInspect ? () => onHover(null) : undefined}
      onFocus={
        canInspect
          ? () => {
              onSelect(entity.id);
              onHover(entity.id);
            }
          : undefined
      }
      onBlur={canInspect ? () => onHover(null) : undefined}
    >
      {src ? (
        <span
          aria-hidden="true"
          className={styles.entitySprite}
          style={{
            width: (sprite?.w ?? entity.w * theme.sourceTile) * spriteScale,
            height: (sprite?.h ?? entity.h * theme.sourceTile) * spriteScale,
            backgroundImage: `url(${src})`,
            ['--frames' as string]: frames,
          }}
        />
      ) : null}
      {entity.kind === 'character' && entity.activity === 'blocked' ? (
        <span className={styles.alertBubble} aria-hidden="true" />
      ) : null}
      {canInspect ? (
        <span className={styles.entityTooltip} id={`world-entity-tip-${encodeURIComponent(entity.id)}`}>
          <strong>{entity.name}</strong>
          <span>{entity.concept}</span>
          <span>
            {entity.state}
            {entity.detail ? ` · ${entity.detail}` : ''}
          </span>
          <small>Click or press Enter to {entityActivateVerb(entity).toLowerCase()} · arrows move between places</small>
        </span>
      ) : null}
      {entity.kind === 'character' ? <VisuallyHidden>{entity.name}</VisuallyHidden> : null}
    </EntityControl>
  );
}

/** Interior furniture replaces outdoor landmark sprites (same domain keys). */
function interiorOverride(theme: WorldThemePack, key: string, src: string): string {
  const map: Record<string, string> = {
    'tool.terminal': 'desk-terminal',
    'knowledge.project': 'shelf-books',
    'files.project': 'desk-files',
    'memory.index': 'cabinet-memory',
    'tool.coding': 'tool-rack',
  };
  const interior = map[key];
  if (!interior) return src;
  const asset = theme.interior?.[interior];
  return asset?.kind === 'sprite' ? asset.src : src;
}

export interface WorldEntityListProps {
  entities: readonly LaidOutEntity[];
  selectedId: string | null;
  href: WorldHref;
  onSelect: (id: string) => void;
}

/** Structured list fallback — same inspect targets as the map (or — when none). */
export function WorldEntityList({ entities, selectedId, href, onSelect }: WorldEntityListProps): ReactNode {
  return (
    <Table>
      <thead>
        <tr>
          <th scope="col">Name</th>
          <th scope="col">Concept</th>
          <th scope="col">State</th>
          <th scope="col">Kind</th>
          <th scope="col">
            <VisuallyHidden>Open</VisuallyHidden>
          </th>
        </tr>
      </thead>
      <tbody>
        {entities.map((entity) => (
          <tr key={`list:${entity.id}`} data-selected={entity.id === selectedId ? 'true' : undefined}>
            <th scope="row">{entity.name}</th>
            <td>{entity.concept}</td>
            <td>
              <StatusBadge tone={toneForState(entity.state)} label={entity.state} />
            </td>
            <td>{entity.kind}</td>
            <td data-align="end">
              {entityHasInspector(entity) && entity.hrefPath ? (
                <Link
                  to={href(entity.hrefPath, entity.hrefExtra)}
                  aria-label={`${entityActivateVerb(entity)}: ${entity.name}`}
                  onClick={() => onSelect(entity.id)}
                  data-entity-inspect={entity.id}
                >
                  Open
                </Link>
              ) : (
                <span data-entity-inspect={entity.id} data-inactive="true">
                  —
                </span>
              )}
            </td>
          </tr>
        ))}
      </tbody>
    </Table>
  );
}
