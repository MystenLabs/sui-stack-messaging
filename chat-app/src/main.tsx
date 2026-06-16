import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { DAppKitProvider } from '@mysten/dapp-kit-react';
import { dAppKit } from './lib/dapp-kit';
import { MessagingClientProvider } from './contexts/MessagingClientContext';
import { ErrorBoundary } from './components/ErrorBoundary';
import App from './App';
import './index.css';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <DAppKitProvider dAppKit={dAppKit}>
      <MessagingClientProvider>
        <ErrorBoundary>
          <App />
        </ErrorBoundary>
      </MessagingClientProvider>
    </DAppKitProvider>
  </StrictMode>,
);
