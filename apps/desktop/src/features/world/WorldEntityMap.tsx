import type { KeyboardEvent, ReactNode } from 'react';
import { Link } from 'react-router';
import { StatusBadge, Table, VisuallyHidden, type Tone } from '../../ui';
import { entityActivateLabel, entityHasInspector } from './inspectors';
import type { LaidOutEntity } from './model';
import { resolveEntityAsset, type WorldThemePack } from './theme/cozyTopdown';
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

/** Spatial tiles. Enter/Space matches click; no navigation when hrefPath is absent. */
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
  const tile = theme.tileSize;

  const onKeyDown = (event: KeyboardEvent<HTMLButtonElement>, entity: LaidOutEntity) => {
    if (event.key !== 'Enter' && event.key !== ' ') return;
    event.preventDefault();
    activateEntity(entity, onSelect, onActivate);
  };

  return (
    <div className={styles.mapRegion} role="application" aria-label={ariaLabel} data-theme={theme.id} data-mode={mode}>
      <div
        className={styles.map}
        style={{
          width: cols * tile,
          height: rows * tile,
        }}
      >
        {entities.map((entity) => {
          const asset = resolveEntityAsset(theme, entity);
          const cssClass =
            asset.kind === 'css' && asset.className in styles
              ? styles[asset.className as keyof typeof styles]
              : asset.kind === 'sprite'
                ? styles.tileSprite
                : styles.worldTileFallback;
          const className = `${styles.entity} ${cssClass}`;
          const canInspect = entityHasInspector(entity);
          return (
            <button
              key={entity.id}
              type="button"
              className={className}
              data-kind={entity.kind}
              data-theme-key={entity.themeKey}
              data-entity-id={entity.id}
              data-facade={entity.facade ?? undefined}
              data-activity={entity.activity ?? 'calm'}
              data-activates={canInspect ? 'true' : 'false'}
              data-selected={entity.id === selectedId ? 'true' : undefined}
              title={entityActivateLabel(entity)}
              aria-label={entityActivateLabel(entity)}
              style={{
                left: entity.x * tile,
                top: entity.y * tile,
                width: entity.w * tile,
                height: entity.h * tile,
                ...(asset.kind === 'sprite'
                  ? {
                      backgroundImage: `url(${asset.src})`,
                      backgroundSize: 'contain',
                      backgroundRepeat: 'no-repeat',
                      backgroundPosition: 'center bottom',
                    }
                  : {}),
              }}
              onClick={() => activateEntity(entity, onSelect, onActivate)}
              onKeyDown={(event) => onKeyDown(event, entity)}
              onFocus={() => onSelect(entity.id)}
            >
              <span className={styles.entityState} data-tone={toneForState(entity.state)} aria-hidden="true" />
              <span className={styles.entityLabel}>{entity.name}</span>
            </button>
          );
        })}
        <span className={styles.hornero} aria-hidden="true" title="Hornero" />
      </div>
    </div>
  );
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
