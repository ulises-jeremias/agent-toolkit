import { describe, expect, it } from 'vitest';
import { WORLD_THEME_PACKS, horneroValleyTheme, worldThemePack } from './horneroValley';

const srcOf = (asset: { kind: string; src?: string } | undefined) => (asset?.kind === 'sprite' ? asset.src : undefined);

describe('horneroValleyTheme (Pixel Renaissance)', () => {
  it('is the only world pack; legacy ids fall back to it', () => {
    expect(WORLD_THEME_PACKS.map((pack) => pack.id)).toEqual(['hornero-valley']);
    expect(worldThemePack('hornero-valley')).toBe(horneroValleyTheme);
    expect(worldThemePack('cozy-valley')).toBe(horneroValleyTheme);
    expect(worldThemePack('cyberpunk-city')).toBe(horneroValleyTheme);
    expect(worldThemePack(null)).toBe(horneroValleyTheme);
  });

  it('maps semantic keys to the Renaissance sprites', () => {
    expect(srcOf(horneroValleyTheme.assets['project.building'])).toBe('/world/house-cottage.png');
    expect(srcOf(horneroValleyTheme.assets['capability.shelf'])).toBe('/world/landmark-library.png');
    expect(srcOf(horneroValleyTheme.assets['memory.index'])).toBe('/world/landmark-archive.png');
    expect(srcOf(horneroValleyTheme.facades?.['landmark-workspace'])).toBe('/world/landmark-workspace.png');
  });

  it('keeps houses and landmarks visually distinct', () => {
    const houses = ['house-cottage', 'house-studio', 'house-workshop', 'house-tower', 'house-cabin', 'house-brick'].map(
      (id) => srcOf(horneroValleyTheme.facades?.[id]),
    );
    expect(new Set(houses).size).toBe(houses.length);
    const landmarks = [
      'landmark-workspace',
      'landmark-archive',
      'landmark-library',
      'landmark-workshop',
      'landmark-operations',
      'landmark-terminal',
      'landmark-attention',
      'landmark-files',
      'landmark-settings',
    ].map((id) => srcOf(horneroValleyTheme.facades?.[id]));
    expect(new Set(landmarks).size).toBe(landmarks.length);
  });
});
