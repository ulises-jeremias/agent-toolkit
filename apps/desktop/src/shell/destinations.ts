import { lazy, type ComponentType, type LazyExoticComponent } from 'react';

export interface Destination {
  path: string;
  label: string;
  /** The question the destination answers (docs/desktop/UX_ARCHITECTURE.md). */
  question: string;
  component: LazyExoticComponent<ComponentType>;
}

export const DESTINATIONS: readonly Destination[] = [
  {
    path: '/world',
    label: 'World',
    question: 'Where am I in this toolkit, and what is real here?',
    component: lazy(() => import('../features/world/WorldView')),
  },
  {
    path: '/office',
    label: 'Office',
    question: 'What is happening and what needs me?',
    component: lazy(() => import('../features/office/Office')),
  },
  {
    path: '/operations',
    label: 'Operations',
    question: 'What work is running and how do I control it?',
    component: lazy(() => import('../features/operations/Operations')),
  },
  {
    path: '/workspace',
    label: 'Workspace',
    question: 'What is this workspace and what does it contain?',
    component: lazy(() => import('../features/workspace/WorkspaceView')),
  },
  {
    path: '/library',
    label: 'Library',
    question: 'What capabilities are installed and healthy?',
    component: lazy(() => import('../features/library/Library')),
  },
  {
    path: '/insights',
    label: 'Insights',
    question: 'How healthy is the toolkit and what changed?',
    component: lazy(() => import('../features/insights/Insights')),
  },
  {
    path: '/terminal',
    label: 'Terminal',
    question: 'Where do I work with agents directly?',
    component: lazy(() => import('../features/terminal/TerminalView')),
  },
  {
    path: '/settings',
    label: 'Settings',
    question: 'How is this Desktop configured?',
    component: lazy(() => import('../features/settings/Settings')),
  },
];
