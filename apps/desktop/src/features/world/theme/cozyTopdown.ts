import type { WorldThemePack } from './types';

/**
 * Default cozy top-down pack. Semantic keys keep CSS fallbacks; façades map to
 * original Paper Co. sprites under `/world/` (not cropped concept sheets).
 */
export const cozyTopdownTheme: WorldThemePack = {
  id: 'cozy-topdown',
  label: 'Cozy top-down (Paper Co.)',
  /** Integer pixel scale — large enough for readable cottage silhouettes. */
  tileSize: 48,
  assets: {
    'workspace.grounds': { kind: 'css', className: 'tileGrounds', label: 'Workspace grounds' },
    'knowledge.workspace': { kind: 'css', className: 'tileKnowledge', label: 'Shared knowledge' },
    'knowledge.project': { kind: 'css', className: 'tileKnowledgeProject', label: 'Project knowledge' },
    'project.building': { kind: 'css', className: 'tileBuilding', label: 'Project building' },
    'tool.terminal': { kind: 'css', className: 'tileTerminal', label: 'Terminal' },
    'tool.coding': { kind: 'css', className: 'tileTool', label: 'Coding tool' },
    'capability.shelf': { kind: 'css', className: 'tileShelf', label: 'Library' },
    'attention.inbox': { kind: 'css', className: 'tileInbox', label: 'Needs you' },
    'agent.working': { kind: 'css', className: 'tileAgentWorking', label: 'Working' },
    'agent.blocked': { kind: 'css', className: 'tileAgentBlocked', label: 'Blocked' },
    'agent.idle': { kind: 'css', className: 'tileAgentIdle', label: 'Idle' },
    'ops.lamp': { kind: 'css', className: 'tileLamp', label: 'Backend lamp' },
    'memory.entry': { kind: 'css', className: 'tileMemory', label: 'Memory record' },
    'memory.index': { kind: 'css', className: 'tileMemoryIndex', label: 'Memory archive' },
    'swarm.table': { kind: 'css', className: 'tileSwarm', label: 'Swarm' },
    'loop.clock': { kind: 'css', className: 'tileLoop', label: 'Loop' },
    'ops.crate': { kind: 'css', className: 'tileCrate', label: 'Install' },
  },
  facades: {
    'house-cottage': { kind: 'sprite', src: '/world/house-cottage.png', label: 'Cottage' },
    'house-studio': { kind: 'sprite', src: '/world/house-studio.png', label: 'Studio' },
    'house-workshop': { kind: 'sprite', src: '/world/house-workshop.png', label: 'Workshop' },
    'house-lab': { kind: 'sprite', src: '/world/house-lab.png', label: 'Lab' },
    'landmark-workspace': { kind: 'sprite', src: '/world/landmark-workspace.png', label: 'Workspace lot' },
    'landmark-archive': { kind: 'sprite', src: '/world/landmark-archive.png', label: 'Memory archive' },
    'landmark-library': { kind: 'sprite', src: '/world/landmark-library.png', label: 'Library' },
    'landmark-files': { kind: 'sprite', src: '/world/landmark-files.png', label: 'Files' },
    'landmark-operations': { kind: 'sprite', src: '/world/landmark-operations.png', label: 'Operations' },
    'landmark-settings': { kind: 'sprite', src: '/world/landmark-settings.png', label: 'Settings' },
    'landmark-terminal': { kind: 'sprite', src: '/world/landmark-terminal.png', label: 'Terminal hub' },
    'landmark-attention': { kind: 'sprite', src: '/world/landmark-attention.png', label: 'Needs you' },
  },
};

export { resolveEntityAsset, resolveThemeAsset } from './types';
export type { ThemeAsset, WorldThemePack } from './types';
