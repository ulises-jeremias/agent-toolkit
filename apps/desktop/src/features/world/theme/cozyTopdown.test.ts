import { describe, expect, it } from 'vitest';
import { cozyTopdownTheme, resolveThemeAsset } from './cozyTopdown';

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
});
