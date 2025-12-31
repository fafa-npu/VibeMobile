// WebSocket connection manager

import type { WSIncomingMessage, WSNotificationMessage } from '../types';
import { useAuthStore } from '../stores/authStore';
import { notificationService } from './notification';

type MessageHandler = (message: WSIncomingMessage) => void;
type StatusHandler = (status: 'connecting' | 'connected' | 'disconnected') => void;
type NotificationHandler = (notification: WSNotificationMessage['data']) => void;

// Determine WebSocket base URL
// In development, use empty string to leverage Vite's proxy (relative path /ws)
// In production or when VITE_WS_URL is set, use the provided URL
const getWsBase = (): string => {
  // If explicitly set, use it
  if (import.meta.env.VITE_WS_URL) {
    return import.meta.env.VITE_WS_URL;
  }

  // In development with Vite proxy, use relative path
  if (import.meta.env.DEV) {
    // Use relative WebSocket URL - browser will use current host
    // This works with Vite's proxy configuration
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    return `${protocol}//${window.location.host}`;
  }

  // Fallback for production without VITE_WS_URL
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  return `${protocol}//${window.location.host}`;
};

const WS_BASE = getWsBase();

class WebSocketManager {
  private ws: WebSocket | null = null;
  private messageHandlers: Set<MessageHandler> = new Set();
  private statusHandlers: Set<StatusHandler> = new Set();
  private notificationHandlers: Set<NotificationHandler> = new Set();
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

          // Handle notification messages specially
          if (message.type === 'notification') {
            this.handleNotification(message as WSNotificationMessage);
          }

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

  /**
   * Subscribe to notification events
   * @param handler Callback for notification data
   * @returns Unsubscribe function
   */
  onNotification(handler: NotificationHandler): () => void {
    this.notificationHandlers.add(handler);
    return () => this.notificationHandlers.delete(handler);
  }

  private notifyStatus(status: 'connecting' | 'connected' | 'disconnected'): void {
    this.statusHandlers.forEach((handler) => handler(status));
  }

  /**
   * Handle incoming notification messages
   * Shows browser notification and notifies subscribers
   */
  private handleNotification(message: WSNotificationMessage): void {
    const { notificationType, message: msg, priority, sound } = message.data;

    console.log('[WS] Notification received:', notificationType, msg);

    // Show browser notification based on type
    switch (notificationType) {
      case 'task_complete':
        notificationService.showTaskComplete(msg, { sound });
        break;
      case 'task_error':
        notificationService.showTaskError(msg, { sound });
        break;
      case 'permission_required':
        notificationService.showPermissionRequired(msg, { sound });
        break;
      default:
        notificationService.show({
          title: 'Claude Code',
          body: msg,
          type: notificationType,
          priority,
          sound,
        });
    }

    // Notify all registered handlers
    this.notificationHandlers.forEach((handler) => handler(message.data));
  }

  get isConnected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }
}

// Singleton instance
export const wsManager = new WebSocketManager();
