import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useAppStore } from './stores/appStore';
import { SessionList } from './pages/SessionList';
import { SessionDetail } from './pages/SessionDetail';

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
