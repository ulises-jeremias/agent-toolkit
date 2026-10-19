import { cozyValleyTheme } from './cozyValley';
import type { WorldThemePack } from './types';

const sprite = (name: string, label: string, frames = 1) => ({
  kind: 'sprite' as const,
  src: `/world/${name}.png`,
  label,
  frames,
});

/**
 * Cyberpunk City — a retrofuturistic neon district. Generated facades
 * (neon towers, capsule homes, HQ spire, transit station), neon asphalt
 * and canal tiles, holo flora and neon-coated characters replace the
 * valley assets wholesale; semantic keys and layout stay identical.
 */
export const cyberpunkCityTheme: WorldThemePack = {
  ...cozyValleyTheme,
  id: 'cyberpunk-city',
  label: 'Cyberpunk City',
  characterPrefix: 'char-cyber-',
  assets: {
    ...cozyValleyTheme.assets,
    'workspace.grounds': sprite('cyber-landmark-spire', 'HQ spire'),
    'files.workspace': sprite('cyber-house-neon', 'Data depot'),
    'files.project': sprite('cyber-house-neon', 'Project data'),
    'memory.index': sprite('cyber-landmark-spire', 'Memory core'),
    'tool.terminal': sprite('cyber-landmark-station', 'Transit terminal'),
    'capability.shelf': sprite('cyber-landmark-station', 'Capability arcade'),
    'agent.working': sprite('char-cyber-teal', 'Working', 2),
    'agent.blocked': sprite('char-cyber-teal', 'Blocked', 2),
    'agent.idle': sprite('char-cyber-teal', 'Idle', 2),
    'ops.crate': sprite('cyber-landmark-station', 'Operations deck'),
    'attention.inbox': sprite('cyber-landmark-spire', 'Signal spire'),
    'ops.lamp': sprite('cyber-landmark-spire', 'Control spire'),
  },
  facades: {
    ...cozyValleyTheme.facades,
    'house-cottage': sprite('cyber-house-neon', 'Neon tower home'),
    'house-studio': sprite('cyber-house-capsule', 'Capsule home'),
    'house-workshop': sprite('cyber-landmark-station', 'Transit workshop'),
    'house-tower': sprite('cyber-house-neon', 'Neon tower home'),
    'house-cabin': sprite('cyber-house-capsule', 'Capsule home'),
    'house-brick': sprite('cyber-house-neon', 'Neon tower home'),
    'landmark-workspace': sprite('cyber-landmark-spire', 'HQ spire'),
    'landmark-archive': sprite('cyber-landmark-spire', 'Memory core'),
    'landmark-library': sprite('cyber-landmark-station', 'Capability arcade'),
    'landmark-workshop': sprite('cyber-landmark-station', 'Transit workshop'),
    'landmark-files': sprite('cyber-house-neon', 'Data depot'),
    'landmark-operations': sprite('cyber-landmark-station', 'Operations deck'),
    'landmark-settings': sprite('cyber-landmark-spire', 'Control spire'),
    'landmark-terminal': sprite('cyber-landmark-station', 'Transit terminal'),
    'landmark-attention': sprite('cyber-landmark-spire', 'Signal spire'),
  },
  decor: {
    ...cozyValleyTheme.decor,
    'grass-0': sprite('cyber-asphalt-0', 'Neon asphalt'),
    'grass-1': sprite('cyber-asphalt-1', 'Neon asphalt'),
    'grass-2': sprite('cyber-asphalt-2', 'Neon asphalt'),
    'grass-3': sprite('cyber-asphalt-3', 'Neon asphalt'),
    'grass-4': sprite('cyber-asphalt-0', 'Neon asphalt'),
    'grass-5': sprite('cyber-asphalt-1', 'Neon asphalt'),
    'grass-6': sprite('cyber-asphalt-2', 'Neon asphalt'),
    'grass-7': sprite('cyber-asphalt-3', 'Neon asphalt'),
    'grass-8': sprite('cyber-asphalt-0', 'Neon asphalt'),
    'grass-9': sprite('cyber-asphalt-1', 'Neon asphalt'),
    'grass-10': sprite('cyber-asphalt-2', 'Neon asphalt'),
    'grass-11': sprite('cyber-asphalt-3', 'Neon asphalt'),
    'grass-12': sprite('cyber-asphalt-0', 'Neon asphalt'),
    'grass-13': sprite('cyber-asphalt-1', 'Neon asphalt'),
    'grass-14': sprite('cyber-asphalt-2', 'Neon asphalt'),
    'grass-15': sprite('cyber-asphalt-3', 'Neon asphalt'),
    'grass-16': sprite('cyber-asphalt-0', 'Neon asphalt'),
    'grass-17': sprite('cyber-asphalt-1', 'Neon asphalt'),
    'grass-18': sprite('cyber-asphalt-2', 'Neon asphalt'),
    'grass-19': sprite('cyber-asphalt-3', 'Neon asphalt'),
    'grass-20': sprite('cyber-asphalt-0', 'Neon asphalt'),
    'grass-21': sprite('cyber-asphalt-1', 'Neon asphalt'),
    'grass-22': sprite('cyber-asphalt-2', 'Neon asphalt'),
    'grass-23': sprite('cyber-asphalt-3', 'Neon asphalt'),
    dirt: sprite('cyber-asphalt-1', 'Service lane'),
    plaza: sprite('cyber-asphalt-2', 'Neon plaza'),
    'plaza-b': sprite('cyber-asphalt-3', 'Neon plaza'),
    water: sprite('cyber-canal', 'Neon canal', 2),
    'tree-round': sprite('cyber-tree', 'Neon tree'),
    'tree-blossom': sprite('cyber-tree', 'Neon tree'),
    'tree-amber': sprite('cyber-tree', 'Neon tree'),
    'tree-rune': sprite('cyber-tree', 'Holo tree'),
    'tree-pine': sprite('cyber-tree', 'Neon tree'),
    'tree-willow': sprite('cyber-tree', 'Neon tree'),
    bush: sprite('cyber-bush', 'Holo bush'),
    'flowers-poppy': sprite('cyber-flower', 'Neon blooms'),
    'flowers-daisy': sprite('cyber-flower', 'Neon blooms'),
    'flowers-lavender': sprite('cyber-flower', 'Neon blooms'),
    'flowers-gold': sprite('cyber-flower', 'Neon blooms'),
  },
};

export const WORLD_THEME_PACKS: readonly WorldThemePack[] = [cozyValleyTheme, cyberpunkCityTheme];

export function worldThemePack(id: string | null): WorldThemePack {
  return WORLD_THEME_PACKS.find((pack) => pack.id === id) ?? cozyValleyTheme;
}
