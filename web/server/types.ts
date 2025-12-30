// Server types for VibeMobile

export interface Session {
  sessionId: string;
  projectPath: string;
  status: 'active' | 'ended';
  createdAt: Date;
  updatedAt: Date;
  outputTail: string;
}

export interface SessionOutput {
  sessionId: string;
  content: string;
  timestamp: Date;
  isDiff: boolean;
}

export interface Device {
  id: string;
  fingerprintHash: string;
  name: string;
  browser: string;
  os: string;
  ip: string;
  location?: string;
  trustLevel: TrustLevel;
  isActive: boolean;
  refreshTokenHash?: string;
  createdAt: Date;
  lastActive: Date;
}

export interface DeviceCreate {
  fingerprint: string;
  name: string;
  browser: string;
  os: string;
  ip: string;
  location?: string;
}

export interface DeviceInfo {
  id: string;
  name: string;
  browser: string;
  os: string;
  ip: string;
  location?: string;
  trustLevel: TrustLevel;
  createdAt: Date;
  lastActive: Date;
}

export type TrustLevel = 'full' | 'partial' | 'view_only';

export interface PairingCode {
  code: string;
  createdAt: Date;
  expiresAt: Date;
  used: boolean;
}

export interface WSMessage {
  type: string;
  data?: unknown;
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

export interface WSNotificationMessage {
  type: 'notification';
  data: {
    notificationType: string;
    message: string;
    priority: 'high' | 'normal' | 'low';
    sound?: boolean;
    sessionId?: string;
  };
}

export interface ServerConfig {
  host: string;
  port: number;
  tmuxSessionPrefix: string;
  tmuxCaptureHistory: number;
  monitorInterval: number;
  wsHeartbeatInterval: number;
}
