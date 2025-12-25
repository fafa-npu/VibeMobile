// API client for VibeMobile backend

import type { Session, Command, SessionOutput } from '../types';

const API_BASE = import.meta.env.VITE_API_URL || '';

async function fetchJSON<T>(url: string, options?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE}${url}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options?.headers,
    },
  });

  if (!response.ok) {
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
      body: formData,
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(error || `HTTP ${response.status}`);
    }

    return response.json();
  },
};
