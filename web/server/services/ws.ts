// WebSocket connection management
import type { WebSocket } from 'ws';
import type { SessionOutput, WSMessage, WSOutputMessage, WSStatusMessage, WSNotificationMessage } from '../types.js';

class ConnectionManager {
  private activeConnections: Map<string, WebSocket> = new Map();
  private subscriptions: Map<string, Set<string>> = new Map(); // sessionId -> connectionIds
  private desktopConnections: Set<string> = new Set();
  private localConnections: Set<string> = new Set();

  connect(websocket: WebSocket, connectionId: string, isLocal: boolean): void {
    this.activeConnections.set(connectionId, websocket);
    if (isLocal) {
      this.localConnections.add(connectionId);
    }
    console.log(`WebSocket connected: ${connectionId}`);
  }

  disconnect(connectionId: string): void {
    this.activeConnections.delete(connectionId);
    this.desktopConnections.delete(connectionId);
    this.localConnections.delete(connectionId);

    // Remove from all subscriptions
    for (const [sessionId, connections] of this.subscriptions) {
      connections.delete(connectionId);
      if (connections.size === 0) {
        this.subscriptions.delete(sessionId);
      }
    }

    console.log(`WebSocket disconnected: ${connectionId}`);
  }

  registerDesktop(connectionId: string): void {
    this.desktopConnections.add(connectionId);
    console.log(`Desktop connection registered: ${connectionId}`);
  }

  unregisterDesktop(connectionId: string): void {
    this.desktopConnections.delete(connectionId);
  }

  subscribe(connectionId: string, sessionIds: string[]): void {
    for (const sessionId of sessionIds) {
      if (!this.subscriptions.has(sessionId)) {
        this.subscriptions.set(sessionId, new Set());
      }
      this.subscriptions.get(sessionId)!.add(connectionId);
    }
    console.log(`Connection ${connectionId} subscribed to: ${sessionIds.join(', ')}`);
  }

  unsubscribe(connectionId: string, sessionIds?: string[]): void {
    if (!sessionIds) {
      // Unsubscribe from all
      for (const connections of this.subscriptions.values()) {
        connections.delete(connectionId);
      }
    } else {
      for (const sessionId of sessionIds) {
        this.subscriptions.get(sessionId)?.delete(connectionId);
      }
    }
  }

  async sendPersonal(connectionId: string, message: unknown): Promise<boolean> {
    const websocket = this.activeConnections.get(connectionId);
    if (websocket && websocket.readyState === 1) { // WebSocket.OPEN = 1
      try {
        websocket.send(JSON.stringify(message));
        return true;
      } catch (e) {
        console.error(`Error sending to ${connectionId}:`, e);
        this.disconnect(connectionId);
      }
    }
    return false;
  }

  async broadcastToSession(sessionId: string, message: unknown): Promise<void> {
    const connectionIds = this.subscriptions.get(sessionId);
    if (!connectionIds) return;

    for (const connectionId of connectionIds) {
      await this.sendPersonal(connectionId, message);
    }
  }

  async broadcastOutput(output: SessionOutput): Promise<void> {
    const message: WSOutputMessage = {
      type: 'session.output',
      data: {
        sessionId: output.sessionId,
        content: output.content,
        timestamp: output.timestamp.toISOString(),
        isDiff: output.isDiff,
      },
    };
    await this.broadcastToSession(output.sessionId, message);
  }

  async broadcastStatus(sessionId: string, status: string): Promise<void> {
    const message: WSStatusMessage = {
      type: 'session.status',
      data: {
        sessionId,
        status,
        timestamp: new Date().toISOString(),
      },
    };
    await this.broadcastToSession(sessionId, message);
  }

  async broadcastAll(message: unknown): Promise<void> {
    for (const connectionId of this.activeConnections.keys()) {
      await this.sendPersonal(connectionId, message);
    }
  }

  async broadcastToDesktop(message: unknown): Promise<void> {
    for (const connectionId of this.desktopConnections) {
      await this.sendPersonal(connectionId, message);
    }
  }

  async broadcastNotification(notification: WSNotificationMessage['data']): Promise<void> {
    const message: WSNotificationMessage = {
      type: 'notification',
      data: notification,
    };
    await this.broadcastAll(message);
  }

  async handleMessage(connectionId: string, data: WSMessage): Promise<void> {
    const msgType = data.type;

    switch (msgType) {
      case 'subscribe': {
        const sessionIds = (data.data as { sessionIds?: string[] })?.sessionIds || [];
        this.subscribe(connectionId, sessionIds);
        await this.sendPersonal(connectionId, {
          type: 'subscribed',
          data: { sessionIds },
        });
        break;
      }

      case 'unsubscribe': {
        const sessionIds = (data.data as { sessionIds?: string[] })?.sessionIds;
        this.unsubscribe(connectionId, sessionIds);
        await this.sendPersonal(connectionId, {
          type: 'unsubscribed',
          data: { sessionIds },
        });
        break;
      }

      case 'ping': {
        await this.sendPersonal(connectionId, {
          type: 'pong',
          data: { timestamp: new Date().toISOString() },
        });
        break;
      }

      case 'register_desktop': {
        if (!this.localConnections.has(connectionId)) {
          await this.sendPersonal(connectionId, {
            type: 'error',
            data: { message: 'Desktop registration is only available locally' },
          });
          break;
        }
        this.registerDesktop(connectionId);
        await this.sendPersonal(connectionId, {
          type: 'desktop_registered',
          data: { connectionId },
        });
        break;
      }

      default:
        console.warn(`Unknown message type: ${msgType}`);
    }
  }

  getConnectionCount(): number {
    return this.activeConnections.size;
  }

  getDesktopConnectionCount(): number {
    return this.desktopConnections.size;
  }
}

// Singleton instance
export const wsManager = new ConnectionManager();
