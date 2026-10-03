import { lazy, type ComponentType, type LazyExoticComponent } from 'react';

export interface Destination {
  path: DestinationPath;
  label: string;
  /** The question the destination answers (docs/desktop/UX_ARCHITECTURE.md). */
  question: string;
  component: LazyExoticComponent<ComponentType>;
}

export type DestinationPath =
  | '/world'
  | '/office'
  | '/operations'
  | '/workspace'
  | '/library'
  | '/people'
  | '/insights'
  | '/terminal'
  | '/settings';

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
    question: 'What needs attention now?',
    component: lazy(() => import('../features/office/Office')),
  },
  {
    path: '/operations',
    label: 'Operations',
    question: 'How do I inspect and control this job, loop, swarm or doctor check?',
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
    question: 'What knowledge sits on these shelves?',
    component: lazy(() => import('../features/library/Library')),
  },
  {
    path: '/people',
    label: 'People',
    question: 'Which durable collaborators are configured in this workspace?',
    component: lazy(() => import('../features/people/People')),
  },
  {
    path: '/insights',
    label: 'Insights',
    question: 'What happened over time?',
    component: lazy(() => import('../features/insights/Insights')),
  },
  {
    path: '/terminal',
    label: 'Terminal',
    question: 'Where is the workstation for this agent, run and harness?',
    component: lazy(() => import('../features/terminal/TerminalView')),
  },
  {
    path: '/settings',
    label: 'Settings',
    question: 'How is this Desktop configured?',
    component: lazy(() => import('../features/settings/Settings')),
  },
];
