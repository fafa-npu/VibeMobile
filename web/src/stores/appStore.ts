// Global state store using Zustand

import { create } from 'zustand';
import type { Session } from '../types';

interface AppState {
  // Connection status
  connectionStatus: 'connecting' | 'connected' | 'disconnected';
  setConnectionStatus: (status: 'connecting' | 'connected' | 'disconnected') => void;

  // Sessions
  sessions: Session[];
  setSessions: (sessions: Session[]) => void;
  updateSession: (sessionId: string, updates: Partial<Session>) => void;

  // Session outputs (accumulated)
  sessionOutputs: Record<string, string>;
  appendOutput: (sessionId: string, content: string) => void;
  setFullOutput: (sessionId: string, content: string) => void;
  clearOutput: (sessionId: string) => void;

  // Current view
  currentSessionId: string | null;
  setCurrentSessionId: (id: string | null) => void;
}

export const useAppStore = create<AppState>((set) => ({
  // Connection status
  connectionStatus: 'disconnected',
  setConnectionStatus: (status) => set({ connectionStatus: status }),

  // Sessions
  sessions: [],
  setSessions: (sessions) => set({ sessions }),
  updateSession: (sessionId, updates) =>
    set((state) => ({
      sessions: state.sessions.map((s) =>
        s.session_id === sessionId ? { ...s, ...updates } : s
      ),
    })),

  // Session outputs
  sessionOutputs: {},
  appendOutput: (sessionId, content) =>
    set((state) => ({
      sessionOutputs: {
        ...state.sessionOutputs,
        [sessionId]: (state.sessionOutputs[sessionId] || '') + content,
      },
    })),
  setFullOutput: (sessionId, content) =>
    set((state) => ({
      sessionOutputs: {
        ...state.sessionOutputs,
        [sessionId]: content,
      },
    })),
  clearOutput: (sessionId) =>
    set((state) => {
      // eslint-disable-next-line @typescript-eslint/no-unused-vars
      const { [sessionId]: _removed, ...rest } = state.sessionOutputs;
      return { sessionOutputs: rest };
    }),

  // Current view
  currentSessionId: null,
  setCurrentSessionId: (id) => set({ currentSessionId: id }),
}));
