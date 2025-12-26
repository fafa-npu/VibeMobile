// WebSocket connection manager

import type { WSIncomingMessage } from '../types';
import { useAuthStore } from '../stores/authStore';

type MessageHandler = (message: WSIncomingMessage) => void;
type StatusHandler = (status: 'connecting' | 'connected' | 'disconnected') => void;

const WS_BASE = import.meta.env.VITE_WS_URL || 'ws://localhost:8765';

class WebSocketManager {
  private ws: WebSocket | null = null;
  private messageHandlers: Set<MessageHandler> = new Set();
  private statusHandlers: Set<StatusHandler> = new Set();
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 10;
  private reconnectDelay = 1000;
  private subscribedSessions: Set<string> = new Set();
  private shouldReconnect = true;

  connect(): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      return;
    }

    this.notifyStatus('connecting');

    try {
      // Include access token in WebSocket URL for remote connections
      const { accessToken } = useAuthStore.getState();
      let wsUrl = `${WS_BASE}/ws`;

      // Add token as query parameter for remote connections
      if (accessToken) {
        wsUrl += `?token=${encodeURIComponent(accessToken)}`;
      }

      this.ws = new WebSocket(wsUrl);

      this.ws.onopen = () => {
        console.log('[WS] Connected');
        this.reconnectAttempts = 0;
        this.notifyStatus('connected');

        // Resubscribe to sessions
        if (this.subscribedSessions.size > 0) {
          this.subscribe([...this.subscribedSessions]);
        }
      };

      this.ws.onmessage = (event) => {
        try {
          const message = JSON.parse(event.data) as WSIncomingMessage;
          this.messageHandlers.forEach((handler) => handler(message));
        } catch (e) {
          console.error('[WS] Failed to parse message:', e);
        }
      };

      this.ws.onclose = (event) => {
        console.log('[WS] Disconnected', event.code, event.reason);
        this.notifyStatus('disconnected');

        // Check if it was an auth error
        if (event.code === 4001) {
          console.error('[WS] Authentication failed:', event.reason);
          // Try to refresh token and reconnect
          const authStore = useAuthStore.getState();
          if (authStore.isAuthenticated) {
            authStore.refreshAccessToken().then(() => {
              this.attemptReconnect();
            });
            return;
          }
        }

        this.attemptReconnect();
      };

      this.ws.onerror = (error) => {
        console.error('[WS] Error:', error);
      };
    } catch (e) {
      console.error('[WS] Connection failed:', e);
      this.attemptReconnect();
    }
  }

  disconnect(): void {
    this.shouldReconnect = false;
    this.ws?.close();
    this.ws = null;
  }

  private attemptReconnect(): void {
    if (!this.shouldReconnect) return;

    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.log('[WS] Max reconnect attempts reached');
      return;
    }

    this.reconnectAttempts++;
    const delay = this.reconnectDelay * Math.pow(1.5, this.reconnectAttempts - 1);

    console.log(`[WS] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);

    setTimeout(() => {
      this.connect();
    }, delay);
  }

  subscribe(sessionIds: string[]): void {
    sessionIds.forEach((id) => this.subscribedSessions.add(id));

    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({
        type: 'subscribe',
        sessionIds,
      }));
    }
  }

  unsubscribe(sessionIds: string[]): void {
    sessionIds.forEach((id) => this.subscribedSessions.delete(id));

    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify({
        type: 'unsubscribe',
        sessionIds,
      }));
    }
  }

  onMessage(handler: MessageHandler): () => void {
    this.messageHandlers.add(handler);
    return () => this.messageHandlers.delete(handler);
  }

  onStatusChange(handler: StatusHandler): () => void {
    this.statusHandlers.add(handler);
    return () => this.statusHandlers.delete(handler);
  }

  private notifyStatus(status: 'connecting' | 'connected' | 'disconnected'): void {
    this.statusHandlers.forEach((handler) => handler(status));
  }

  get isConnected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }
}

// Singleton instance
export const wsManager = new WebSocketManager();
