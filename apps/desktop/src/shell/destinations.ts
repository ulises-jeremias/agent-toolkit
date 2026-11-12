import { lazy, type ComponentType, type LazyExoticComponent } from 'react';
import type { PixelIconName } from '../ui';

export type DestinationPath =
  | '/world'
  | '/focus'
  | '/workspace'
  | '/people'
  | '/library'
  | '/operations'
  | '/office'
  | '/terminal'
  | '/insights'
  | '/settings';

export interface Destination {
  path: DestinationPath;
  label: string;
  /** What the user comes here to do. Shown as the link's tooltip. */
  question: string;
  icon: PixelIconName;
  /** Where the link sits in the rail. Pages without a slot are tabs of `parent`. */
  rail: 'main' | 'footer' | null;
  parent?: DestinationPath;
  /** Label inside the parent's tab strip. */
  tab?: string;
  component: LazyExoticComponent<ComponentType>;
}

/**
 * Six places plus Settings. Everything else is a tab of one of them, so the
 * rail answers "where do I go to…" without knowing how the toolkit is built.
 */
export const DESTINATIONS: readonly Destination[] = [
  {
    path: '/world',
    label: 'World',
    question: 'See the whole workspace and who is working in it',
    icon: 'world',
    rail: 'main',
    component: lazy(() => import('../features/valley/ValleyView')),
  },
  {
    path: '/focus',
    label: 'Focus',
    question: 'Work with a coding agent on one project',
    icon: 'focus',
    rail: 'main',
    component: lazy(() => import('../features/focus/FocusView')),
  },
  {
    path: '/workspace',
    label: 'Projects',
    question: 'Link repositories and review their files and changes',
    icon: 'projects',
    rail: 'main',
    component: lazy(() => import('../features/workspace/WorkspaceView')),
  },
  {
    path: '/people',
    label: 'People',
    question: 'Set up the collaborators you start sessions with',
    icon: 'people',
    rail: 'main',
    component: lazy(() => import('../features/people/People')),
  },
  {
    path: '/library',
    label: 'Library',
    question: 'Find and install skills, agents and tool connections',
    icon: 'library',
    rail: 'main',
    component: lazy(() => import('../features/library/Library')),
  },
  {
    path: '/operations',
    label: 'Operations',
    question: 'Run and watch jobs, loops and swarms',
    icon: 'operations',
    rail: 'main',
    tab: 'Jobs and loops',
    component: lazy(() => import('../features/operations/Operations')),
  },
  {
    path: '/office',
    label: 'Attention',
    question: 'See what is waiting for you',
    icon: 'lamp',
    rail: null,
    parent: '/operations',
    tab: 'Needs you',
    component: lazy(() => import('../features/office/Office')),
  },
  {
    path: '/terminal',
    label: 'Terminal',
    question: 'Open and manage terminals',
    icon: 'terminal',
    rail: null,
    parent: '/operations',
    tab: 'Terminals',
    component: lazy(() => import('../features/terminal/TerminalView')),
  },
  {
    path: '/insights',
    label: 'Insights',
    question: 'Check the health of this installation',
    icon: 'check',
    rail: null,
    parent: '/operations',
    tab: 'Health',
    component: lazy(() => import('../features/insights/Insights')),
  },
  {
    path: '/settings',
    label: 'Settings',
    question: 'Change appearance, workspace and updates',
    icon: 'settings',
    rail: 'footer',
    component: lazy(() => import('../features/settings/Settings')),
  },
];

/** The rail entry that owns `path` (itself, or its parent for tab pages). */
export function railOwner(path: string): DestinationPath | null {
  const destination = DESTINATIONS.find((entry) => entry.path === path);
  if (!destination) return null;
  return destination.parent ?? destination.path;
}

/** Tab strip for a section: the owner first, then its child pages. Empty when the section has no tabs. */
export function sectionTabs(path: string): readonly Destination[] {
  const owner = railOwner(path);
  if (!owner) return [];
  const tabs = DESTINATIONS.filter((entry) => entry.path === owner || entry.parent === owner);
  return tabs.length > 1 ? tabs : [];
}
