// Session and API types

export interface Session {
  session_id: string;
  project_path: string;
  status: 'active' | 'detached' | 'ended';
  created_at: string;
  updated_at: string;
  output_tail: string;
}

export interface Command {
  command_id: string;
  session_id: string;
  content: string;
  status: 'pending' | 'sent' | 'failed';
  created_at: string;
  sent_at?: string;
  error?: string;
}

export interface SessionOutput {
  session_id: string;
  output: string;
  timestamp: string;
}

// WebSocket message types
export interface WSMessage {
  type: string;
  data: Record<string, unknown>;
}

export interface WSOutputMessage {
  type: 'session.output';
  data: {
    sessionId: string;
    content: string;
    timestamp: string;
    isDiff: boolean;
  };
}

export interface WSStatusMessage {
  type: 'session.status';
  data: {
    sessionId: string;
    status: string;
    timestamp: string;
  };
}

/**
 * Notification message from server
 * Triggered by Claude Code hooks (e.g., Stop hook)
 */
export interface WSNotificationMessage {
  type: 'notification';
  data: {
    notificationId: string;
    notificationType: 'task_complete' | 'task_error' | 'permission_required' | 'session_idle' | 'custom';
    message: string;
    sessionId?: string;
    priority: 'low' | 'normal' | 'high' | 'urgent';
    details?: Record<string, unknown>;
    sound: boolean;
    timestamp: string;
  };
}

export type WSIncomingMessage = WSOutputMessage | WSStatusMessage | WSNotificationMessage;

// Re-export auth types
export * from './auth';
