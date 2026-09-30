import type { SemanticEntity, SemanticKey } from '../model/types';

export type ThemeAsset =
  { kind: 'css'; className: string; label: string } | { kind: 'sprite'; src: string; label: string };

export interface WorldThemePack {
  id: string;
  label: string;
  tileSize: number;
  assets: Readonly<Partial<Record<SemanticKey, ThemeAsset>>>;
  /** Optional façade overrides (project house variants, landmark silhouettes). */
  facades?: Readonly<Partial<Record<string, ThemeAsset>>>;
}

export function resolveThemeAsset(pack: WorldThemePack, key: SemanticKey): ThemeAsset {
  return (
    pack.assets[key] ?? {
      kind: 'css',
      className: 'worldTileFallback',
      label: key,
    }
  );
}

/** Prefer façade sprite/CSS when the entity carries a theme façade id. */
export function resolveEntityAsset(
  pack: WorldThemePack,
  entity: Pick<SemanticEntity, 'themeKey' | 'facade'>,
): ThemeAsset {
  if (entity.facade) {
    const facadeAsset = pack.facades?.[entity.facade];
    if (facadeAsset) return facadeAsset;
  }
  return resolveThemeAsset(pack, entity.themeKey);
}
