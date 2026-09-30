import { Suspense, useState } from 'react';
import { HashRouter, Navigate, NavLink, Route, Routes, useLocation } from 'react-router';
import { useBackend, useHealth } from '../data/backend';
import { activeJobIds, useJobs } from '../data/jobs';
import { LiveProvider } from '../data/live';
import { TerminalsProvider, useTerminals } from '../data/terminals';
import { setThemePreference } from '../design/theme';
import { TerminalDock } from '../features/terminal/TerminalDock';
import { hasContext } from '../lib/context';
import { GOTO_INDEXES, shortcutKeys } from '../lib/shortcuts';
import { DestinationBoundary, LoadingState, ReceiptsProvider } from '../ui';
import { CommandPalette, type PaletteCommand } from './CommandPalette';
import { ContextBar, ContextDialog } from './ContextBar';
import { useShellContext } from './context';
import { DESTINATIONS } from './destinations';
import { LiveIndicator, StaleNotice } from './LiveIndicator';
import { ShortcutMap } from './ShortcutMap';
import { useGlobalShortcuts } from './useGlobalShortcuts';
import styles from './shell.module.css';

const TERMINAL_PATH = '/terminal';

function NavCount({ path }: { path: string }) {
  const jobs = useJobs();
  if (path !== '/operations') return null;
  const active = activeJobIds(jobs.data).length;
  if (active === 0) return null;
  return (
    <span className={styles.navCount} aria-label={`${active} running`}>
      {active}
    </span>
  );
}

function Sidebar() {
  const { backend } = useBackend();
  const health = useHealth();
  const { linkTo } = useShellContext();
  const version = health.data?.version ?? backend?.version ?? null;
  return (
    <nav className={styles.sidebar} aria-label="Destinations">
      <div className={styles.brand}>
        <span className={styles.brandMark} aria-hidden="true">
          A
        </span>
        <span>
          <span className={styles.brandName}>Agent Toolkit</span>
          <span className={styles.brandSub}>Desktop workstation</span>
        </span>
      </div>
      <ul className={styles.navList}>
        {DESTINATIONS.map((destination) => (
          <li key={destination.path}>
            <NavLink to={linkTo(destination.path)} className={styles.navLink} title={destination.question}>
              <span>{destination.label}</span>
              <NavCount path={destination.path} />
            </NavLink>
          </li>
        ))}
      </ul>
      <footer className={styles.sidebarFooter}>
        <LiveIndicator />
        <p className={styles.version}>{version ? `agent-toolkit ${version}` : 'agent-toolkit version unknown'}</p>
      </footer>
    </nav>
  );
}

/** After a keyboard navigation, focus the new page so screen readers announce it. */
function focusMain(): void {
  requestAnimationFrame(() => document.getElementById('main')?.focus());
}

function Frame() {
  const { pathname } = useLocation();
  const context = useShellContext();
  const terminals = useTerminals();
  const { restartBackend } = useBackend();
  const [paletteOpen, setPaletteOpen] = useState(false);
  const [shortcutsOpen, setShortcutsOpen] = useState(false);
  const [contextOpen, setContextOpen] = useState(false);
  const full = pathname === TERMINAL_PATH;
  const { goTo } = context;

  const go = (path: string) => {
    goTo(path);
    if (path !== TERMINAL_PATH) focusMain();
  };

  const toggleDock = () => {
    if (!terminals.available || full) return;
    terminals.setDockOpen(!terminals.dockOpen);
  };

  const noTerminal = terminals.available ? undefined : 'Needs the Desktop app';

  const commands: PaletteCommand[] = [
    ...DESTINATIONS.map((destination, index) => {
      const slot = GOTO_INDEXES[index];
      return {
        id: `goto:${destination.path}`,
        label: `Go to ${destination.label}`,
        group: 'Navigate',
        keywords: [destination.question],
        keys: slot ? shortcutKeys(`goto${slot}`) : undefined,
        run: () => go(destination.path),
      };
    }),
    {
      id: 'terminal:new',
      label: 'New terminal session',
      group: 'Terminal',
      keywords: ['shell', 'pty', 'agent'],
      disabledReason: noTerminal,
      run: () => terminals.setNewSessionOpen(true),
    },
    {
      id: 'terminal:dock',
      label: terminals.dockOpen ? 'Hide terminal dock' : 'Show terminal dock',
      group: 'Terminal',
      keywords: ['toggle', 'panel'],
      keys: shortcutKeys('toggleDock'),
      disabledReason: noTerminal ?? (full ? 'Already on Terminal' : undefined),
      run: toggleDock,
    },
    {
      id: 'jobs:start',
      label: 'Start a job',
      group: 'Operations',
      keywords: ['run', 'command', 'background'],
      run: () => goTo('/operations', { start: '1' }),
    },
    {
      id: 'context:edit',
      label: 'Edit context',
      group: 'Context',
      keywords: ['workspace', 'agent', 'run'],
      run: () => setContextOpen(true),
    },
    {
      id: 'context:clear',
      label: 'Clear context',
      group: 'Context',
      disabledReason: hasContext(context) ? undefined : 'No context set',
      run: () => context.setContext({ ws: null, agent: null, run: null }),
    },
    {
      id: 'theme:paper',
      label: 'Use Paper theme',
      group: 'Appearance',
      keywords: ['light'],
      run: () => setThemePreference('paper'),
    },
    {
      id: 'theme:ink',
      label: 'Use Ink theme',
      group: 'Appearance',
      keywords: ['dark'],
      run: () => setThemePreference('ink'),
    },
    {
      id: 'theme:system',
      label: 'Use system theme',
      group: 'Appearance',
      keywords: ['auto'],
      run: () => setThemePreference('system'),
    },
    {
      id: 'backend:restart',
      label: 'Restart backend',
      group: 'Backend',
      keywords: ['serve', 'reconnect'],
      run: () => void restartBackend(),
    },
    {
      id: 'help:shortcuts',
      label: 'Show keyboard shortcuts',
      group: 'Help',
      keys: shortcutKeys('shortcuts'),
      run: () => setShortcutsOpen(true),
    },
  ];

  useGlobalShortcuts({
    palette: () => setPaletteOpen(true),
    paletteAlt: () => setPaletteOpen(true),
    shortcuts: () => setShortcutsOpen(true),
    toggleDock,
    ...Object.fromEntries(
      GOTO_INDEXES.map((slot) => {
        const destination = DESTINATIONS[slot - 1];
        return [`goto${slot}`, destination ? () => go(destination.path) : undefined];
      }),
    ),
  });

  return (
    <div className={styles.shell}>
      <a className={styles.skipLink} href="#main">
        Skip to content
      </a>
      <Sidebar />
      <div className={styles.main} data-terminal={full ? 'full' : undefined}>
        <StaleNotice />
        <ContextBar onEdit={() => setContextOpen(true)} />
        <main id="main" className={styles.content} tabIndex={-1}>
          <Routes>
            <Route path="/" element={<Navigate to="/office" replace />} />
            {DESTINATIONS.map(({ path, label, component: Destination }) => (
              <Route
                key={path}
                path={path}
                element={
                  <DestinationBoundary name={label}>
                    <Suspense fallback={<LoadingState label={`Opening ${label}`} />}>
                      <Destination />
                    </Suspense>
                  </DestinationBoundary>
                }
              />
            ))}
            <Route path="*" element={<Navigate to="/office" replace />} />
          </Routes>
        </main>
        <DestinationBoundary name="Terminal dock">
          <TerminalDock full={full} />
        </DestinationBoundary>
      </div>
      <CommandPalette open={paletteOpen} onClose={() => setPaletteOpen(false)} commands={commands} />
      <ShortcutMap open={shortcutsOpen} onClose={() => setShortcutsOpen(false)} />
      <ContextDialog open={contextOpen} onClose={() => setContextOpen(false)} />
    </div>
  );
}

export default function Shell() {
  return (
    <HashRouter>
      <ReceiptsProvider>
        <LiveProvider>
          <TerminalsProvider>
            <Frame />
          </TerminalsProvider>
        </LiveProvider>
      </ReceiptsProvider>
    </HashRouter>
  );
}
