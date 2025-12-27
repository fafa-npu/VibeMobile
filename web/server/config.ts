// Server configuration
import type { ServerConfig } from './types.js';

export const config: ServerConfig = {
  host: process.env.HOST || '0.0.0.0',
  port: parseInt(process.env.PORT || '8765', 10),
  sslCertFile: process.env.SSL_CERT,
  sslKeyFile: process.env.SSL_KEY,
  tmuxSessionPrefix: process.env.TMUX_PREFIX || 'vibe',
  tmuxCaptureHistory: parseInt(process.env.TMUX_HISTORY || '500', 10),
  monitorInterval: parseInt(process.env.MONITOR_INTERVAL || '200', 10),
  wsHeartbeatInterval: parseInt(process.env.WS_HEARTBEAT || '30000', 10),
};
