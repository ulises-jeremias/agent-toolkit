import { Suspense } from 'react';
import { HashRouter, Navigate, NavLink, Route, Routes, useLocation } from 'react-router';
import { useBackend, useHealth } from '../data/backend';
import { activeJobIds, useJobs } from '../data/jobs';
import { LiveProvider } from '../data/live';
import { TerminalProvider } from '../data/terminal';
import { DestinationBoundary, LoadingState, ReceiptsProvider } from '../ui';
import { CommandPalette } from './CommandPalette';
import { ContextBar } from './ContextBar';
import { DESTINATIONS } from './destinations';
import { LiveIndicator, StaleNotice } from './LiveIndicator';
import { TerminalDock } from './TerminalDock';
import { useSessionContext } from './useSessionContext';
import styles from './shell.module.css';

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
  const { href } = useSessionContext();
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
            <NavLink to={href(destination.path)} className={styles.navLink} title={destination.question} end>
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

function RedirectTo({ path }: { path: string }) {
  const { href } = useSessionContext();
  return <Navigate to={href(path)} replace />;
}

function ShellFrame() {
  const location = useLocation();
  return (
    <div className={styles.shell} data-destination={location.pathname}>
      <a className={styles.skipLink} href="#main">
        Skip to content
      </a>
      <Sidebar />
      <div className={styles.main}>
        <ContextBar />
        <StaleNotice />
        <main id="main" className={styles.content} tabIndex={-1}>
          <Routes>
            <Route path="/" element={<RedirectTo path="/office" />} />
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
            <Route path="*" element={<RedirectTo path="/office" />} />
          </Routes>
        </main>
        <TerminalDock />
      </div>
      <CommandPalette />
    </div>
  );
}

export default function Shell() {
  return (
    <HashRouter>
      <ReceiptsProvider>
        <LiveProvider>
          <TerminalProvider>
            <ShellFrame />
          </TerminalProvider>
        </LiveProvider>
      </ReceiptsProvider>
    </HashRouter>
  );
}
