import { Suspense, useCallback, useEffect, useState } from 'react';
import { HashRouter, Link, Navigate, Route, Routes, useLocation } from 'react-router';
import { useBackend, useHealth } from '../data/backend';
import { FocusProvider, useFocusProviders, useFocusThreads } from '../data/focus';
import { activeJobIds, useJobs } from '../data/jobs';
import { LiveProvider } from '../data/live';
import { TerminalProvider } from '../data/terminal';
import { Onboarding } from '../features/onboarding/Onboarding';
import { REPLAY_ONBOARDING_EVENT, shouldRunOnboarding } from '../features/onboarding/complete';
import { useAttention } from '../features/office/useAttention';
import { displayLocationName } from './sessionContext';
import { DestinationBoundary, Kbd, LoadingState, PixelIcon, ReceiptsProvider } from '../ui';
import { CommandPalette, openCommandPalette } from './CommandPalette';
import { DESTINATIONS, railOwner, sectionTabs, type Destination } from './destinations';
import { HOME_PATH } from './home';
import { NavigationContinuity } from './NavigationContinuity';
import { LiveIndicator, StaleNotice } from './LiveIndicator';
import { TerminalDock } from './TerminalDock';
import { useSessionContext } from './useSessionContext';
import styles from './shell.module.css';

/** A small count beside a rail entry: only real, current things are counted. */
function RailCount({ path }: { path: string }) {
  const jobs = useJobs();
  const { items } = useAttention();
  const { threads } = useFocusThreads();
  if (path === '/focus') {
    const waiting = threads.filter((thread) => thread.status === 'awaiting-approval').length;
    const working = threads.filter((thread) => thread.status === 'running').length;
    if (waiting > 0) {
      return (
        <span className={styles.railCount} data-tone="attention" aria-label={`${waiting} waiting for your answer`}>
          {waiting}
        </span>
      );
    }
    if (working > 0) return <span className={styles.railLamp} role="img" aria-label={`${working} working`} />;
    return null;
  }
  if (path !== '/operations') return null;
  const active = activeJobIds(jobs.data).length;
  if (items.length > 0) {
    return (
      <span className={styles.railCount} data-tone="attention" aria-label={`${items.length} need you`}>
        {items.length}
      </span>
    );
  }
  if (active === 0) return null;
  return (
    <span className={styles.railCount} aria-label={`${active} running`}>
      {active}
    </span>
  );
}

function RailLink({ destination }: { destination: Destination }) {
  const location = useLocation();
  const { href } = useSessionContext();
  const owner = railOwner(location.pathname);
  const here = location.pathname === destination.path;
  return (
    <li>
      <Link
        to={href(destination.path)}
        className={styles.railLink}
        data-active={owner === destination.path || undefined}
        title={destination.question}
        aria-current={here ? 'page' : undefined}
      >
        <PixelIcon name={destination.icon} size={24} />
        <span className={styles.railLabel}>{destination.label}</span>
        <RailCount path={destination.path} />
      </Link>
    </li>
  );
}

function Rail() {
  const { backend } = useBackend();
  const health = useHealth();
  const version = health.data?.version ?? backend?.version ?? null;
  return (
    <nav className={styles.rail} aria-label="Destinations">
      <div className={styles.brand}>
        <span className={styles.brandMark} aria-hidden="true">
          A
        </span>
        <span className={styles.brandName}>Agent Toolkit</span>
      </div>
      <ul className={styles.railList}>
        {DESTINATIONS.filter((destination) => destination.rail === 'main').map((destination) => (
          <RailLink key={destination.path} destination={destination} />
        ))}
      </ul>
      <ul className={styles.railList} data-slot="footer">
        {DESTINATIONS.filter((destination) => destination.rail === 'footer').map((destination) => (
          <RailLink key={destination.path} destination={destination} />
        ))}
      </ul>
      <p className={styles.version}>{version ? `Version ${version}` : 'Version unknown'}</p>
    </nav>
  );
}

/** Which coding agents can start a session right now. Read from each agent's own CLI. */
function AgentLamps() {
  const providers = useFocusProviders();
  const { href } = useSessionContext();
  const list = (providers.data ?? []).filter((provider) => provider.installed);
  if (list.length === 0) return null;
  return (
    <Link to={href('/focus')} className={styles.agents} aria-label="Coding agents on this machine">
      {list.map((provider) => {
        const ready = provider.auth === 'ready' && provider.capabilities.sessions;
        const state = ready ? 'ready' : provider.auth === 'signed-out' ? 'signed-out' : 'limited';
        return (
          <span
            key={provider.id}
            className={styles.agent}
            data-state={state}
            title={`${provider.label}: ${provider.authDetail}${provider.capabilities.sessions ? '' : '. Sessions in Focus are not available for it yet'}`}
          >
            <span className={styles.agentDot} aria-hidden="true" />
            {provider.label}
            <span className={styles.srOnly}>
              {ready ? ', ready' : provider.auth === 'signed-out' ? ', signed out' : ', detected'}
            </span>
          </span>
        );
      })}
    </Link>
  );
}

function TopBar() {
  const { backend } = useBackend();
  const { href } = useSessionContext();
  const harness = backend?.harness ?? null;
  return (
    <header className={styles.topBar}>
      <Link
        to={href('/settings')}
        className={styles.workspace}
        title={harness ? `Workspace: ${harness.path}. Change it in Settings.` : 'Workspace'}
      >
        <span className={styles.workspaceName}>{harness ? displayLocationName(harness.path) : 'Workspace'}</span>
      </Link>
      <button type="button" className={styles.search} onClick={openCommandPalette} aria-haspopup="dialog">
        <PixelIcon name="search" size={12} />
        <span className={styles.searchText}>Search or run a command</span>
        <Kbd keys={['Ctrl', 'K']} />
      </button>
      <div className={styles.topStatus}>
        <AgentLamps />
        <LiveIndicator />
      </div>
    </header>
  );
}

function SectionTabs() {
  const location = useLocation();
  const { href } = useSessionContext();
  const tabs = sectionTabs(location.pathname);
  if (tabs.length === 0) return null;
  return (
    <nav className={styles.sectionTabs} aria-label="Section">
      {tabs.map((tab) => (
        <Link
          key={tab.path}
          to={href(tab.path)}
          className={styles.sectionTab}
          aria-current={location.pathname === tab.path ? 'page' : undefined}
        >
          {tab.tab ?? tab.label}
        </Link>
      ))}
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
      <a
        className={styles.skipLink}
        href="#main"
        onClick={(event) => {
          // HashRouter owns location.hash, so the default anchor jump would
          // be parsed as a route change instead of moving focus. Focus the
          // landmark explicitly (it carries tabIndex={-1} for this purpose).
          event.preventDefault();
          const main = document.getElementById('main');
          main?.focus();
          main?.scrollIntoView();
        }}
      >
        Skip to content
      </a>
      <Rail />
      <div className={styles.column}>
        <TopBar />
        <StaleNotice />
        <SectionTabs />
        <main id="main" className={styles.content} tabIndex={-1}>
          <Routes>
            <Route path="/" element={null} />
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
            <Route path="*" element={<RedirectTo path={HOME_PATH} />} />
          </Routes>
        </main>
        <TerminalDock />
      </div>
      <CommandPalette />
    </div>
  );
}

function useOnboardingGate() {
  const [active, setActive] = useState(shouldRunOnboarding);
  useEffect(() => {
    const replay = () => setActive(true);
    window.addEventListener(REPLAY_ONBOARDING_EVENT, replay);
    return () => window.removeEventListener(REPLAY_ONBOARDING_EVENT, replay);
  }, []);
  const complete = useCallback(() => setActive(false), []);
  return { active, complete };
}

function ShellRoot() {
  const { active, complete } = useOnboardingGate();
  if (active) return <Onboarding onComplete={complete} />;
  return (
    <NavigationContinuity>
      <ShellFrame />
    </NavigationContinuity>
  );
}

export default function Shell() {
  return (
    <HashRouter>
      <ReceiptsProvider>
        <LiveProvider>
          <FocusProvider>
            <TerminalProvider>
              <ShellRoot />
            </TerminalProvider>
          </FocusProvider>
        </LiveProvider>
      </ReceiptsProvider>
    </HashRouter>
  );
}
