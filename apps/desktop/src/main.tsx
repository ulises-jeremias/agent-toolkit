import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import { BackendProvider } from './backend';
import { AppErrorBoundary } from './components/ui';
import './design/tokens.css';

const rootElement = document.getElementById('root');
if (!rootElement) throw new Error('missing #root element');

ReactDOM.createRoot(rootElement).render(
  <React.StrictMode>
    <AppErrorBoundary>
      <BackendProvider>
        <App />
      </BackendProvider>
    </AppErrorBoundary>
  </React.StrictMode>,
);
