import { create } from 'zustand';

export type Destination = 'office' | 'operations' | 'workspace' | 'library' | 'insights' | 'settings' | 'terminal';

/**
 * Genuinely shared client-only UI state: layout, navigation, ephemeral
 * workspace UI, command palette, user preferences. Never a mirror of backend
 * resources — server state lives in TanStack Query keyed by queryKeys.
 */
interface UiState {
  destination: Destination;
  sidebarCollapsed: boolean;
  paletteOpen: boolean;
  activeJobId: string | null;
  activeTerminalId: string | null;
  go: (destination: Destination) => void;
  toggleSidebar: () => void;
  setPaletteOpen: (open: boolean) => void;
  setActiveJobId: (id: string | null) => void;
  setActiveTerminalId: (id: string | null) => void;
}

export const useUiStore = create<UiState>()((set) => ({
  destination: 'office',
  sidebarCollapsed: false,
  paletteOpen: false,
  activeJobId: null,
  activeTerminalId: null,
  go: (destination) => set({ destination }),
  toggleSidebar: () => set((state) => ({ sidebarCollapsed: !state.sidebarCollapsed })),
  setPaletteOpen: (open) => set({ paletteOpen: open }),
  setActiveJobId: (id) => set({ activeJobId: id }),
  setActiveTerminalId: (id) => set({ activeTerminalId: id }),
}));
