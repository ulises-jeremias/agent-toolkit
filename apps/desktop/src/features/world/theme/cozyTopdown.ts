import type { WorldThemePack } from './types';

/**
 * Default cozy top-down pack. Assets are original CSS pixel tiles (no
 * third-party game art). Features resolve semantic keys only.
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
};

export { resolveThemeAsset } from './types';
export type { ThemeAsset, WorldThemePack } from './types';
