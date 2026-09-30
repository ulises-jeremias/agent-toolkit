import { Suspense } from 'react';
import { HashRouter, Navigate, NavLink, Route, Routes } from 'react-router';
import { useBackend, useHealth } from '../data/backend';
import { activeJobIds, useJobs } from '../data/jobs';
import { LiveProvider } from '../data/live';
import { DestinationBoundary, LoadingState, ReceiptsProvider } from '../ui';
import { DESTINATIONS } from './destinations';
import { LiveIndicator, StaleNotice } from './LiveIndicator';
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
            <NavLink to={destination.path} className={styles.navLink} title={destination.question}>
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

export default function Shell() {
  return (
    <HashRouter>
      <ReceiptsProvider>
        <LiveProvider>
          <div className={styles.shell}>
            <a className={styles.skipLink} href="#main">
              Skip to content
            </a>
            <Sidebar />
            <div className={styles.main}>
              <StaleNotice />
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
            </div>
          </div>
        </LiveProvider>
      </ReceiptsProvider>
    </HashRouter>
  );
}
