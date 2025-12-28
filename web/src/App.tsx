import { useEffect } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useAppStore } from './stores/appStore';
import { useAuthStore } from './stores/authStore';
import { SessionList } from './pages/SessionList';
import { SessionDetail } from './pages/SessionDetail';
import { PairingScreen } from './components/PairingScreen';
import { LoadingScreen } from './components/LoadingScreen';
import { notificationService } from './services/notification';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 2,
      staleTime: 5000,
    },
  },
});

function AppContent() {
  const currentSessionId = useAppStore((s) => s.currentSessionId);
  const { isAuthenticated, isLoading, initialize } = useAuthStore();

  // Initialize auth on mount
  useEffect(() => {
    initialize();
  }, [initialize]);

  // Initialize notification service (request permission)
  useEffect(() => {
    if (isAuthenticated) {
      notificationService.initialize().then((status) => {
        console.log('[App] Notification permission:', status);
      });
    }
  }, [isAuthenticated]);

  // Show loading screen while checking auth
  if (isLoading) {
    return <LoadingScreen />;
  }

  // Show pairing screen if not authenticated
  // DEV: Skip auth check for testing by adding ?dev=1 to URL
  const isDev = new URLSearchParams(window.location.search).get('dev') === '1';
  if (!isAuthenticated && !isDev) {
    return <PairingScreen />;
  }

  // Show main app
  if (currentSessionId) {
    return <SessionDetail />;
  }

  return <SessionList />;
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AppContent />
    </QueryClientProvider>
  );
}

export default App;
