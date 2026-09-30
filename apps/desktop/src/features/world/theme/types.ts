import type { SemanticKey } from '../model';

export type ThemeAsset =
  { kind: 'css'; className: string; label: string } | { kind: 'sprite'; src: string; label: string };

export interface WorldThemePack {
  id: string;
  label: string;
  tileSize: number;
  assets: Readonly<Partial<Record<SemanticKey, ThemeAsset>>>;
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
