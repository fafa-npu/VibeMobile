// Custom hooks for sessions and WebSocket

export { useVoiceInput } from './useVoiceInput';
export type { UseVoiceInputOptions, UseVoiceInputReturn, VoiceInputState } from './useVoiceInput';

import { useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../services/api';
import { wsManager } from '../services/websocket';
import { useAppStore } from '../stores/appStore';
import type { WSIncomingMessage } from '../types';

// Hook for managing sessions list
export function useSessions() {
  const { setSessions } = useAppStore();

  const query = useQuery({
    queryKey: ['sessions'],
    queryFn: api.getSessions,
    refetchInterval: 5000, // Fallback polling
  });

  useEffect(() => {
    if (query.data) {
      setSessions(query.data);
    }
  }, [query.data, setSessions]);

  return query;
}

// Hook for single session
export function useSession(sessionId: string | null) {
  return useQuery({
    queryKey: ['session', sessionId],
    queryFn: () => (sessionId ? api.getSession(sessionId) : null),
    enabled: !!sessionId,
  });
}

// Hook for session output
export function useSessionOutput(sessionId: string | null) {
  const { setFullOutput, sessionOutputs } = useAppStore();

  const query = useQuery({
    queryKey: ['sessionOutput', sessionId],
    queryFn: async () => {
      if (!sessionId) return null;
      const result = await api.getSessionOutput(sessionId);
      setFullOutput(sessionId, result.output);
      return result;
    },
    enabled: !!sessionId,
  });

  return {
    ...query,
    output: sessionId ? sessionOutputs[sessionId] || '' : '',
  };
}

// Hook for sending commands
export function useSendCommand() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ sessionId, content }: { sessionId: string; content: string }) =>
      api.sendCommand(sessionId, content),
    onSuccess: (_, { sessionId }) => {
      // Refetch output after sending command
      queryClient.invalidateQueries({ queryKey: ['sessionOutput', sessionId] });
    },
  });
}

// Hook for WebSocket connection
export function useWebSocket() {
  const {
    setConnectionStatus,
    appendOutput,
    updateSession,
    currentSessionId,
  } = useAppStore();

  useEffect(() => {
    // Connect WebSocket
    wsManager.connect();

    // Handle status changes
    const unsubStatus = wsManager.onStatusChange((status) => {
      setConnectionStatus(status);
    });

    // Handle incoming messages
    const unsubMessage = wsManager.onMessage((message: WSIncomingMessage) => {
      if (message.type === 'session.output') {
        const { sessionId, content, isDiff } = message.data;
        if (isDiff) {
          appendOutput(sessionId, content);
        } else {
          setFullOutput(sessionId, content);
        }
      } else if (message.type === 'session.status') {
        const { sessionId, status } = message.data;
        updateSession(sessionId, { status: status as 'active' | 'detached' | 'ended' });
      }
    });

    return () => {
      unsubStatus();
      unsubMessage();
    };
  }, [setConnectionStatus, appendOutput, setFullOutput, updateSession]);

  // Subscribe to current session
  useEffect(() => {
    if (currentSessionId) {
      wsManager.subscribe([currentSessionId]);
      return () => wsManager.unsubscribe([currentSessionId]);
    }
  }, [currentSessionId]);

  return {
    isConnected: useAppStore((s) => s.connectionStatus === 'connected'),
    status: useAppStore((s) => s.connectionStatus),
  };
}

// Hook for time formatting
export function useTimeAgo(dateString: string): string {
  const date = new Date(dateString);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffSec = Math.floor(diffMs / 1000);
  const diffMin = Math.floor(diffSec / 60);
  const diffHour = Math.floor(diffMin / 60);
  const diffDay = Math.floor(diffHour / 24);

  if (diffSec < 10) return '刚刚';
  if (diffSec < 60) return `${diffSec} 秒前`;
  if (diffMin < 60) return `${diffMin} 分钟前`;
  if (diffHour < 24) return `${diffHour} 小时前`;
  return `${diffDay} 天前`;
}
