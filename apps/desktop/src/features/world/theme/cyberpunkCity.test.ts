import { describe, expect, it } from 'vitest';
import { cozyValleyTheme } from './cozyValley';
import { WORLD_THEME_PACKS, cyberpunkCityTheme, worldThemePack } from './cyberpunkCity';

const srcOf = (asset: { kind: string } | undefined): string | undefined =>
  asset && asset.kind === 'sprite' ? (asset as unknown as { src: string }).src : undefined;

describe('world theme packs', () => {
  it('offers genuinely distinct packs, not just palette variants', () => {
    expect(WORLD_THEME_PACKS.map((pack) => pack.id)).toEqual(['cozy-valley', 'cyberpunk-city']);
    const cozyHouse = srcOf(cozyValleyTheme.facades?.['house-cottage']);
    const cyberHouse = srcOf(cyberpunkCityTheme.facades?.['house-cottage']);
    expect(cyberHouse).toBe('/world/cyber-house-neon.png');
    expect(cyberHouse).not.toBe(cozyHouse);
    expect(srcOf(cyberpunkCityTheme.facades?.['landmark-workspace'])).toBe('/world/cyber-landmark-spire.png');
    expect(srcOf(cyberpunkCityTheme.decor?.['grass-0'])).toBe('/world/cyber-asphalt-0.png');
    expect(srcOf(cyberpunkCityTheme.decor?.water)).toBe('/world/cyber-canal.png');
    expect(srcOf(cyberpunkCityTheme.assets['agent.idle'])).toBe('/world/char-cyber-teal.png');
    expect(cyberpunkCityTheme.characterPrefix).toBe('char-cyber-');
    expect(cozyValleyTheme.characterPrefix).toBeUndefined();
  });

  it('falls back to Cozy Valley for unknown or empty ids', () => {
    expect(worldThemePack(null).id).toBe('cozy-valley');
    expect(worldThemePack('nope').id).toBe('cozy-valley');
    expect(worldThemePack('cyberpunk-city').id).toBe('cyberpunk-city');
  });
});
