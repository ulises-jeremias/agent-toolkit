import { lazy, Suspense } from 'react';
import { HashRouter, NavLink, Navigate, Route, Routes } from 'react-router';
import { useBackend } from './backend';
import { Loading } from './components/ui';
import styles from './App.module.css';

const Office = lazy(() => import('./features/office/Office'));
const Operations = lazy(() => import('./features/operations/Operations'));
const WorkspaceView = lazy(() => import('./features/workspace/WorkspaceView'));
const Library = lazy(() => import('./features/library/Library'));
const Insights = lazy(() => import('./features/insights/Insights'));
const Settings = lazy(() => import('./features/settings/Settings'));
const TerminalView = lazy(() => import('./features/terminal/TerminalView'));

const DESTINATIONS = [
  { to: '/office', label: 'Office' },
  { to: '/operations', label: 'Operations' },
  { to: '/workspace', label: 'Workspace' },
  { to: '/library', label: 'Library' },
  { to: '/insights', label: 'Insights' },
  { to: '/terminal', label: 'Terminal' },
  { to: '/settings', label: 'Settings' },
] as const;

function BackendBanner() {
  const { backend, restartBackend } = useBackend();
  if (!backend || backend.status === 'ready') return null;
  const copy: Record<string, string> = {
    starting: 'Starting the Agent Toolkit backend…',
    'version-mismatch': `Backend version ${backend.version ?? 'unknown'} does not match this Desktop build. Some actions may fail.`,
    crashed: `Backend crashed: ${backend.detail ?? 'unknown cause'}.`,
    failed: `Backend failed to start: ${backend.detail ?? 'unknown cause'}.`,
    stopped: 'Backend is stopped.',
  };
  return (
    <div className={styles.banner} role="alert">
      <span>{copy[backend.status] ?? backend.status}</span>
      {(backend.status === 'crashed' || backend.status === 'failed' || backend.status === 'stopped') && (
        <button type="button" className={styles.bannerButton} onClick={() => void restartBackend()}>
          Restart backend
        </button>
      )}
    </div>
  );
}

export default function App() {
  return (
    <HashRouter>
      <div className={styles.shell}>
        <a className={styles.skipLink} href="#main">
          Skip to content
        </a>
        <nav className={styles.sidebar} aria-label="Destinations">
          <p className={styles.brand}>Agent Toolkit</p>
          <ul className={styles.navList}>
            {DESTINATIONS.map((destination) => (
              <li key={destination.to}>
                <NavLink
                  to={destination.to}
                  className={({ isActive }) => (isActive ? styles.navActive : styles.navLink)}
                >
                  {destination.label}
                </NavLink>
              </li>
            ))}
          </ul>
        </nav>
        <div className={styles.main}>
          <BackendBanner />
          <main id="main" className={styles.content}>
            <Suspense fallback={<Loading label="Loading destination" />}>
              <Routes>
                <Route path="/" element={<Navigate to="/office" replace />} />
                <Route path="/office" element={<Office />} />
                <Route path="/operations" element={<Operations />} />
                <Route path="/workspace" element={<WorkspaceView />} />
                <Route path="/library" element={<Library />} />
                <Route path="/insights" element={<Insights />} />
                <Route path="/terminal" element={<TerminalView />} />
                <Route path="/settings" element={<Settings />} />
              </Routes>
            </Suspense>
          </main>
        </div>
      </div>
    </HashRouter>
  );
}
