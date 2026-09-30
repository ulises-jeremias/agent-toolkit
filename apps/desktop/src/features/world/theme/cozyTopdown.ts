import type { WorldThemePack } from './types';

/**
 * Default cozy top-down pack. Assets are original CSS pixel tiles (no
 * third-party game art). Features resolve semantic keys only.
 */
export const cozyTopdownTheme: WorldThemePack = {
  id: 'cozy-topdown',
  label: 'Cozy top-down (Paper Co.)',
  tileSize: 40,
  assets: {
    'workspace.grounds': { kind: 'css', className: 'tileGrounds', label: 'Workspace grounds' },
    'knowledge.workspace': { kind: 'css', className: 'tileKnowledge', label: 'Shared knowledge' },
    'knowledge.project': { kind: 'css', className: 'tileKnowledgeProject', label: 'Project knowledge' },
    'project.building': { kind: 'css', className: 'tileBuilding', label: 'Project building' },
    'tool.terminal': { kind: 'css', className: 'tileTerminal', label: 'Terminal' },
    'capability.shelf': { kind: 'css', className: 'tileShelf', label: 'Library' },
    'attention.inbox': { kind: 'css', className: 'tileInbox', label: 'Needs you' },
    'agent.working': { kind: 'css', className: 'tileAgentWorking', label: 'Working' },
    'agent.blocked': { kind: 'css', className: 'tileAgentBlocked', label: 'Blocked' },
    'agent.idle': { kind: 'css', className: 'tileAgentIdle', label: 'Idle' },
    'ops.lamp': { kind: 'css', className: 'tileLamp', label: 'Backend lamp' },
    'memory.entry': { kind: 'css', className: 'tileMemory', label: 'Memory' },
    'swarm.table': { kind: 'css', className: 'tileSwarm', label: 'Swarm' },
    'loop.clock': { kind: 'css', className: 'tileLoop', label: 'Loop' },
    'ops.crate': { kind: 'css', className: 'tileCrate', label: 'Install' },
  },
};

export { resolveThemeAsset } from './types';
export type { ThemeAsset, WorldThemePack } from './types';
