import React from 'react';
import ReactDOM from 'react-dom/client';
import { BackendProvider } from './data/backend';
import './design/fonts';
import { initAppearance } from './design/theme';
import './design/tokens.css';
import Shell from './shell/Shell';
import { AppErrorBoundary } from './ui';

initAppearance();

const rootElement = document.getElementById('root');
if (!rootElement) throw new Error('missing #root element');

ReactDOM.createRoot(rootElement).render(
  <React.StrictMode>
    <AppErrorBoundary>
      <BackendProvider>
        <Shell />
      </BackendProvider>
    </AppErrorBoundary>
  </React.StrictMode>,
);
