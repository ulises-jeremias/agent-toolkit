import { describe, expect, it } from 'vitest';
import { cozyTopdownTheme, resolveEntityAsset, resolveThemeAsset } from './cozyTopdown';

describe('cozyTopdownTheme', () => {
  it('ships Paper Co. craft at readable tile scale with semantic CSS keys', () => {
    expect(cozyTopdownTheme.id).toBe('cozy-topdown');
    expect(cozyTopdownTheme.tileSize).toBe(48);
    expect(cozyTopdownTheme.tileSize % 1).toBe(0);

    const building = resolveThemeAsset(cozyTopdownTheme, 'project.building');
    expect(building).toMatchObject({ kind: 'css', className: 'tileBuilding' });

    const memory = resolveThemeAsset(cozyTopdownTheme, 'memory.index');
    expect(memory).toMatchObject({ kind: 'css', className: 'tileMemoryIndex' });

    const terminal = resolveThemeAsset(cozyTopdownTheme, 'tool.terminal');
    expect(terminal).toMatchObject({ kind: 'css', className: 'tileTerminal' });

    const missing = resolveThemeAsset(cozyTopdownTheme, 'agent.catalog');
    expect(missing).toMatchObject({ kind: 'css', className: 'worldTileFallback' });
  });

  it('maps landmark and house façades to production sprites under /world/', () => {
    expect(
      resolveEntityAsset(cozyTopdownTheme, { themeKey: 'project.building', facade: 'house-cottage' }),
    ).toMatchObject({
      kind: 'sprite',
      src: '/world/house-cottage.png',
    });
    expect(
      resolveEntityAsset(cozyTopdownTheme, { themeKey: 'capability.shelf', facade: 'landmark-library' }),
    ).toMatchObject({
      kind: 'sprite',
      src: '/world/landmark-library.png',
    });
    expect(resolveEntityAsset(cozyTopdownTheme, { themeKey: 'project.building' })).toMatchObject({
      kind: 'css',
      className: 'tileBuilding',
    });
  });
});
