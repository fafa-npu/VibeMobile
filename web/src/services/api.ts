// API client for VibeMobile backend

import type { Session, Command, SessionOutput } from '../types';
import { useAuthStore } from '../stores/authStore';

const API_BASE = import.meta.env.VITE_API_URL || '';

// Get auth headers for API requests
function getAuthHeaders(): Record<string, string> {
  const { accessToken, fingerprint } = useAuthStore.getState();
  const headers: Record<string, string> = {};

  if (accessToken) {
    headers['Authorization'] = `Bearer ${accessToken}`;
  }

  if (fingerprint) {
    headers['X-Device-Fingerprint'] = fingerprint;
  }

  return headers;
}

async function fetchJSON<T>(url: string, options?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE}${url}`, {
    ...options,
    credentials: 'include',
    headers: {
      'Content-Type': 'application/json',
      ...getAuthHeaders(),
      ...options?.headers,
    },
  });

  if (!response.ok) {
    // Handle auth errors
    if (response.status === 401) {
      // Try to refresh token
      const authStore = useAuthStore.getState();
      if (authStore.isAuthenticated) {
        try {
          await authStore.refreshAccessToken();
          // Retry the request with new token
          return fetchJSON(url, options);
        } catch {
          // Refresh failed, will show auth error
        }
      }
    }

    const error = await response.text();
    throw new Error(error || `HTTP ${response.status}`);
  }

  return response.json();
}

export const api = {
  // Sessions
  async getSessions(): Promise<Session[]> {
    return fetchJSON('/api/sessions');
  },

  async getSession(sessionId: string): Promise<Session> {
    return fetchJSON(`/api/sessions/${sessionId}`);
  },

  async getSessionOutput(sessionId: string): Promise<SessionOutput> {
    return fetchJSON(`/api/sessions/${sessionId}/output`);
  },

  async sendCommand(
    sessionId: string,
    content: string,
    pressEnter = true
  ): Promise<Command> {
    const params = new URLSearchParams({
      content,
      press_enter: String(pressEnter),
    });
    return fetchJSON(`/api/sessions/${sessionId}/send?${params}`, {
      method: 'POST',
    });
  },

  async sendSpecialKey(sessionId: string, key: string): Promise<{ success: boolean }> {
    const params = new URLSearchParams({ key });
    return fetchJSON(`/api/sessions/${sessionId}/key?${params}`, {
      method: 'POST',
    });
  },

  async createSession(command = 'claude'): Promise<Session> {
    const params = new URLSearchParams({ command });
    return fetchJSON(`/api/sessions?${params}`, {
      method: 'POST',
    });
  },

  async killSession(sessionId: string): Promise<{ success: boolean }> {
    return fetchJSON(`/api/sessions/${sessionId}`, {
      method: 'DELETE',
    });
  },

  async uploadFile(sessionId: string, file: File): Promise<{ success: boolean; path: string }> {
    const formData = new FormData();
    formData.append('file', file);

    const response = await fetch(`${API_BASE}/api/sessions/${sessionId}/upload`, {
      method: 'POST',
      credentials: 'include',
      headers: {
        ...getAuthHeaders(),
      },
      body: formData,
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(error || `HTTP ${response.status}`);
    }

    return response.json();
  },
};
