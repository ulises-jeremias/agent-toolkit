import { useCallback, useEffect, useMemo, useRef, useState, type KeyboardEvent, type ReactNode } from 'react';
import { Link } from 'react-router';
import { StatusBadge, Table, VisuallyHidden, type Tone } from '../../ui';
import { entityActivateLabel, entityHasInspector } from './inspectors';
import { paintInterior, paintTerrain, type DecorSprite, type LaidOutEntity } from './model';
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
  onSelect: (id: string) => void;
  onActivate: (entity: LaidOutEntity) => void;
}

/** Integer zoom steps (display px per 16px source tile). */
const ZOOMS = [32, 48, 64] as const;

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
  onSelect,
  onActivate,
}: WorldEntityMapProps): ReactNode {
  const regionRef = useRef<HTMLDivElement>(null);
  const [zoom, setZoom] = useState<number>(48);
  const [pan, setPan] = useState({ x: 0, y: 0 });
  const [fit, setFit] = useState(true);
  const drag = useRef<{ x: number; y: number; panX: number; panY: number } | null>(null);

  const sourceTile = theme.sourceTile;
  const worldW = cols * sourceTile;
  const worldH = rows * sourceTile;
  const scale = zoom / sourceTile;
  const viewW = worldW * scale;
  const viewH = worldH * scale;

  const plan = useMemo(
    () => (mode === 'grounds' ? paintTerrain(entities, cols, rows) : paintInterior(entities, cols, rows)),
    [mode, entities, cols, rows],
  );

  const fitZoom = useCallback(() => {
    const region = regionRef.current;
    if (!region) return 48;
    const pad = 24;
    const zx = Math.floor((region.clientWidth - pad) / worldW) * sourceTile;
    const zy = Math.floor((region.clientHeight - pad) / worldH) * sourceTile;
    const z = Math.min(zx, zy);
    return ZOOMS.reduce((best, step) => (step <= Math.max(16, z) ? step : best), 16);
  }, [worldW, worldH, sourceTile]);

  useEffect(() => {
    if (!fit) return;
    const z = fitZoom();
    setZoom(z);
    const region = regionRef.current;
    if (region) {
      setPan({
        x: Math.max(0, Math.floor((region.clientWidth - worldW * (z / sourceTile)) / 2)),
        y: Math.max(0, Math.floor((region.clientHeight - worldH * (z / sourceTile)) / 2)),
      });
    }
  }, [fit, fitZoom, worldW, worldH, sourceTile]);

  useEffect(() => {
    const region = regionRef.current;
    if (!region) return;
    const observer = new ResizeObserver(() => {
      if (fit) {
        const z = fitZoom();
        setZoom(z);
        setPan({
          x: Math.max(0, Math.floor((region.clientWidth - worldW * (z / sourceTile)) / 2)),
          y: Math.max(0, Math.floor((region.clientHeight - worldH * (z / sourceTile)) / 2)),
        });
      }
    });
    observer.observe(region);
    return () => observer.disconnect();
  }, [fit, fitZoom, worldW, worldH, sourceTile]);

  const clampPan = useCallback(
    (x: number, y: number) => {
      const region = regionRef.current;
      const maxX = 24;
      const maxY = 24;
      const minX = region ? Math.min(24, region.clientWidth - viewW - 24) : -viewW;
      const minY = region ? Math.min(24, region.clientHeight - viewH - 24) : -viewH;
      return { x: Math.min(maxX, Math.max(minX, x)), y: Math.min(maxY, Math.max(minY, y)) };
    },
    [viewW, viewH],
  );

  const onPointerDown = (event: React.PointerEvent<HTMLDivElement>) => {
    drag.current = { x: event.clientX, y: event.clientY, panX: pan.x, panY: pan.y };
    (event.target as HTMLElement).setPointerCapture?.(event.pointerId);
  };
  const onPointerMove = (event: React.PointerEvent<HTMLDivElement>) => {
    if (!drag.current) return;
    const { x, y, panX, panY } = drag.current;
    setFit(false);
    setPan(clampPan(panX + event.clientX - x, panY + event.clientY - y));
  };
  const onPointerUp = () => {
    drag.current = null;
  };

  const onKeyDown = (event: KeyboardEvent<HTMLElement>) => {
    const step = zoom;
    if (event.key === 'ArrowLeft') {
      setFit(false);
      setPan((p) => clampPan(p.x + step, p.y));
      event.preventDefault();
    } else if (event.key === 'ArrowRight') {
      setFit(false);
      setPan((p) => clampPan(p.x - step, p.y));
      event.preventDefault();
    } else if (event.key === 'ArrowUp') {
      setFit(false);
      setPan((p) => clampPan(p.x, p.y + step));
      event.preventDefault();
    } else if (event.key === 'ArrowDown') {
      setFit(false);
      setPan((p) => clampPan(p.x, p.y - step));
      event.preventDefault();
    } else if (event.key === 'Home') {
      setFit(true);
      event.preventDefault();
    }
  };

  const zoomIn = () => {
    setFit(false);
    setZoom((z) => ZOOMS.find((s) => s > z) ?? 64);
  };
  const zoomOut = () => {
    setFit(false);
    setZoom((z) => [...ZOOMS].reverse().find((s) => s < z) ?? 16);
  };

  return (
    <div
      ref={regionRef}
      className={styles.mapRegion}
      role="application"
      aria-label={ariaLabel}
      data-theme={theme.id}
      data-mode={mode}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerUp}
    >
      {/* Keyboard pan lives on a real button so the map region itself stays non-interactive. */}
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
        <TerrainCanvas theme={theme} cells={plan.cells} cols={cols} rows={rows} mode={mode} animate />
        {plan.decor
          .filter((d) => !d.over)
          .map((d) => (
            <DecorSpriteView key={d.id} decor={d} theme={theme} />
          ))}
        {entities.map((entity) => (
          <EntityTile
            key={entity.id}
            entity={entity}
            theme={theme}
            selectedId={selectedId}
            mode={mode}
            onSelect={onSelect}
            onActivate={onActivate}
          />
        ))}
        {plan.decor
          .filter((d) => d.over)
          .map((d) => (
            <DecorSpriteView key={d.id} decor={d} theme={theme} />
          ))}
      </div>
      <div className={styles.cameraHud} role="group" aria-label="Map view controls">
        <button type="button" className={styles.hudButton} onClick={zoomOut} aria-label="Zoom out">
          −
        </button>
        <button type="button" className={styles.hudButton} onClick={zoomIn} aria-label="Zoom in">
          +
        </button>
        <button type="button" className={styles.hudButton} onClick={() => setFit(true)} aria-label="Fit world">
          ⌂
        </button>
      </div>
    </div>
  );
}

function DecorSpriteView({ decor, theme }: { decor: DecorSprite; theme: WorldThemePack }) {
  const asset = theme.decor?.[decor.sprite] ?? theme.interior?.[decor.sprite];
  if (!asset || asset.kind !== 'sprite') return null;
  const scale = theme.tileSize / theme.sourceTile;
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
  onSelect,
  onActivate,
}: {
  entity: LaidOutEntity;
  theme: WorldThemePack;
  selectedId: string | null;
  mode: 'grounds' | 'interior';
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
  const frames = asset.kind === 'sprite' ? (asset.frames ?? 1) : 1;
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
        left: entity.x * theme.tileSize,
        top: entity.y * theme.tileSize,
        width: entity.w * theme.tileSize,
        height: entity.h * theme.tileSize,
        ...(src
          ? {
              backgroundImage: `url(${src})`,
              backgroundSize: `${frames * entity.w * theme.tileSize}px ${entity.h * theme.tileSize}px`,
              ['--frames' as string]: frames,
            }
          : {}),
      }}
      onClick={() => activateEntity(entity, onSelect, onActivate)}
      onKeyDown={onKeyDown}
      onFocus={() => onSelect(entity.id)}
    >
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
