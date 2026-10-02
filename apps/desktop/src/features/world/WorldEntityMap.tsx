import { useCallback, useEffect, useMemo, useRef, useState, type KeyboardEvent, type ReactNode } from 'react';
import { Link } from 'react-router';
import { StatusBadge, Table, VisuallyHidden, type Tone } from '../../ui';
import { clampCamera, fitCamera, WORLD_ZOOMS, zoomCamera } from './camera';
import { entityActivateLabel, entityHasInspector } from './inspectors';
import { paintInterior, paintTerrain, type DecorSprite, type LaidOutEntity } from './model';
import spriteManifest from '../../../public/world/manifest.json';
import { TerrainCanvas } from './TerrainRenderer';
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
function characterSprite(id: string, themeKey: string): string {
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
  /** Hidden inspector panel — pause terrain/CSS animation, keep manual zoom. */
  suspended?: boolean;
  onSelect: (id: string) => void;
  onActivate: (entity: LaidOutEntity) => void;
}

/** Integer zoom steps (display px per 16px source tile). */
const ZOOMS = WORLD_ZOOMS;

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
  suspended = false,
  onSelect,
  onActivate,
}: WorldEntityMapProps): ReactNode {
  const regionRef = useRef<HTMLDivElement>(null);
  const [zoom, setZoom] = useState<number>(48);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [cameraMode, setCameraMode] = useState<'frame' | 'fit' | 'manual'>('frame');
  const drag = useRef<{ x: number; y: number; panX: number; panY: number; moved: boolean } | null>(null);
  const suppressClick = useRef(false);
  const [tabVisible, setTabVisible] = useState(() => document.visibilityState !== 'hidden');

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

  const fitWorld = useCallback(() => {
    const region = regionRef.current;
    if (!region) return;
    // Start at a legible game scale so the world remains the main interface.
    // Home gives the full valley overview; projects can also be reached by search.
    const minimumZoom = mode === 'grounds' ? (region.clientWidth >= 1400 ? 48 : 32) : 16;
    const camera = fitCamera({ x: region.clientWidth, y: region.clientHeight }, { x: cols, y: rows }, minimumZoom);
    setZoom(camera.zoom);
    setPan(
      clampCamera(
        camera.pan,
        { x: region.clientWidth, y: region.clientHeight },
        { x: cols * camera.zoom, y: rows * camera.zoom },
      ),
    );
  }, [cols, rows, mode]);

  useEffect(() => {
    if (cameraMode === 'manual') return;
    fitWorld();
  }, [cameraMode, fitWorld]);

  useEffect(() => {
    const region = regionRef.current;
    if (!region) return;
    const observer = new ResizeObserver(() => {
      if (cameraMode !== 'manual') {
        fitWorld();
      } else {
        setPan((p) => clampCamera(p, { x: region.clientWidth, y: region.clientHeight }, { x: viewW, y: viewH }));
      }
    });
    observer.observe(region);
    return () => observer.disconnect();
  }, [cameraMode, fitWorld, viewW, viewH]);

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
    setCameraMode('manual');
    setPan(clampPan(panX + event.clientX - x, panY + event.clientY - y));
  };
  const onPointerUp = (event: React.PointerEvent<HTMLDivElement>) => {
    if (event.currentTarget.hasPointerCapture?.(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
    drag.current = null;
  };

  const onKeyDown = (event: KeyboardEvent<HTMLElement>) => {
    const step = zoom;
    if (event.key === 'ArrowLeft') {
      setCameraMode('manual');
      setPan((p) => clampPan(p.x + step, p.y));
      event.preventDefault();
    } else if (event.key === 'ArrowRight') {
      setCameraMode('manual');
      setPan((p) => clampPan(p.x - step, p.y));
      event.preventDefault();
    } else if (event.key === 'ArrowUp') {
      setCameraMode('manual');
      setPan((p) => clampPan(p.x, p.y + step));
      event.preventDefault();
    } else if (event.key === 'ArrowDown') {
      setCameraMode('manual');
      setPan((p) => clampPan(p.x, p.y - step));
      event.preventDefault();
    } else if (event.key === 'Home') {
      setCameraMode('fit');
      event.preventDefault();
    }
  };

  const changeZoom = (next: number) => {
    const region = regionRef.current;
    setCameraMode('manual');
    if (region) {
      setPan(zoomCamera(pan, zoom, next, { x: region.clientWidth, y: region.clientHeight }, { x: cols, y: rows }));
    }
    setZoom(next);
  };
  const zoomIn = () => changeZoom(ZOOMS.find((s) => s > zoom) ?? 64);
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
        type="button"
        className={styles.panFocus}
        aria-label="Pan map with arrow keys; Home fits the world"
        onKeyDown={onKeyDown}
      />
      <div
        className={styles.mapWorld}
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
          />
        ))}
        {plan.decor
          .filter((d) => d.over)
          .map((d) => (
            <DecorSpriteView key={d.id} decor={d} theme={theme} scale={scale} />
          ))}
      </div>
      <div className={styles.cameraHud} role="group" aria-label="Map view controls">
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
}: {
  entity: LaidOutEntity;
  theme: WorldThemePack;
  selectedId: string | null;
  mode: 'grounds' | 'interior';
  tileSize: number;
  onSelect: (id: string) => void;
  onActivate: (entity: LaidOutEntity) => void;
}) {
  const asset = resolveEntityAsset(theme, entity);
  const isCharacter = entity.kind === 'character';
  const spriteName = isCharacter ? characterSprite(entity.id, entity.themeKey) : null;
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
  const onKeyDown = (event: KeyboardEvent<HTMLButtonElement>) => {
    if (event.key !== 'Enter' && event.key !== ' ') return;
    event.preventDefault();
    activateEntity(entity, onSelect, onActivate);
  };
  return (
    <button
      type="button"
      className={styles.entity}
      data-kind={entity.kind}
      data-theme-key={entity.themeKey}
      data-entity-id={entity.id}
      data-activity={entity.activity ?? 'calm'}
      data-activates={canInspect ? 'true' : 'false'}
      data-selected={entity.id === selectedId ? 'true' : undefined}
      title={entityActivateLabel(entity)}
      aria-label={entityActivateLabel(entity)}
      style={{
        left: entity.x * tileSize,
        top: entity.y * tileSize,
        width: entity.w * tileSize,
        height: entity.h * tileSize,
      }}
      onClick={() => activateEntity(entity, onSelect, onActivate)}
      onKeyDown={onKeyDown}
      onFocus={() => onSelect(entity.id)}
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
      {entity.kind !== 'character' ? <span className={styles.entityLabel}>{entity.name}</span> : null}
      {entity.kind === 'character' ? <VisuallyHidden>{entity.name}</VisuallyHidden> : null}
    </button>
  );
}

/** Interior furniture replaces outdoor landmark sprites (same domain keys). */
function interiorOverride(theme: WorldThemePack, key: string, src: string): string {
  const map: Record<string, string> = {
    'tool.terminal': 'desk-terminal',
    'knowledge.project': 'shelf-books',
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
                  onClick={() => onSelect(entity.id)}
                  data-entity-inspect={entity.id}
                >
                  Inspect
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
