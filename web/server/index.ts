// VibeMobile Node.js Server
// Unified backend for session management and real-time updates
import express from 'express';
import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import { WebSocketServer, WebSocket } from 'ws';
import { v4 as uuidv4 } from 'uuid';

import { config } from './config.js';
import { wsManager } from './services/ws.js';
import { outputMonitor } from './services/monitor.js';
// tmuxManager is used by routes, exported here for potential direct access
import './services/tmux.js';
import { authService } from './services/auth.js';

import sessionsRouter from './routes/sessions.js';
import authRouter from './routes/auth.js';
import notificationsRouter from './routes/notifications.js';
import filesRouter from './routes/files.js';

// Get current directory - works in both ESM and CJS
const getCurrentDir = (): string => {
  // Try ESM approach first
  try {
    const __filename = fileURLToPath(import.meta.url);
    return dirname(__filename);
  } catch {
    // Fallback for CJS (bundled)
    return typeof __dirname !== 'undefined' ? __dirname : process.cwd();
  }
};

const currentDir = getCurrentDir();

// Determine dist path based on environment
// In ESM (dev): currentDir = /path/to/web/server, distPath = ../dist
// In CJS (prod): currentDir = /path/to/web (cwd), distPath = ./dist
const getDistPath = (): string => {
  // Check if running from bundled CJS (dist/server.cjs)
  const cwdDist = path.join(process.cwd(), 'dist');
  if (fs.existsSync(cwdDist) && fs.existsSync(path.join(cwdDist, 'index.html'))) {
    return cwdDist;
  }
  // Fallback for ESM dev mode
  return path.join(currentDir, '../dist');
};

// Create Express app
const app = express();

// Middleware
app.use(cors({
  origin: true,
  credentials: true,
}));
app.use(express.json());
app.use(cookieParser());

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    version: '1.0.0',
    uptime: process.uptime(),
  });
});

// API routes
app.use('/api/sessions', sessionsRouter);
app.use('/api/sessions', filesRouter);  // File browser routes
app.use('/api/auth', authRouter);
app.use('/api/notifications', notificationsRouter);

// Serve static files in production
const distPath = getDistPath();
if (fs.existsSync(distPath)) {
  app.use(express.static(distPath));
  app.get('*', (req, res) => {
    res.sendFile(path.join(distPath, 'index.html'));
  });
}

// Create HTTP server (Cloudflare Tunnel handles HTTPS termination)
const server = http.createServer(app);

// WebSocket server
const wss = new WebSocketServer({ server, path: '/ws' });

// eslint-disable-next-line @typescript-eslint/no-unused-vars
wss.on('connection', (ws: WebSocket, _req) => {
  const connectionId = uuidv4();

  // Register connection
  wsManager.connect(ws, connectionId);

  ws.on('message', async (data) => {
    try {
      const message = JSON.parse(data.toString());
      await wsManager.handleMessage(connectionId, message);
    } catch (e) {
      console.error('Error handling WebSocket message:', e);
    }
  });

  ws.on('close', () => {
    wsManager.disconnect(connectionId);
  });

  ws.on('error', (error) => {
    console.error(`WebSocket error for ${connectionId}:`, error);
    wsManager.disconnect(connectionId);
  });

  // Send initial connection message
  ws.send(JSON.stringify({
    type: 'connected',
    data: {
      connectionId,
      timestamp: new Date().toISOString(),
    },
  }));
});

// Start monitoring existing sessions
async function startMonitoring() {
  await outputMonitor.startAll();
  console.log('Started monitoring existing sessions');

  // Periodically refresh sessions
  setInterval(() => {
    outputMonitor.refreshSessions();
  }, 5000);
}

// Cleanup on shutdown
function cleanup() {
  console.log('Shutting down...');
  outputMonitor.stopAll();
  authService.cleanupApprovals();

  wss.close(() => {
    server.close(() => {
      console.log('Server stopped');
      process.exit(0);
    });
  });
}

process.on('SIGINT', cleanup);
process.on('SIGTERM', cleanup);

// Start server
server.listen(config.port, config.host, () => {
  console.log(`VibeMobile server running on http://${config.host}:${config.port}`);
  startMonitoring();
});

export { app, server, wss };
