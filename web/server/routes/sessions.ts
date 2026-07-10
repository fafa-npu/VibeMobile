// Session management API routes
import { Router, type NextFunction, type Request, type Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import fs from 'fs';
import path from 'path';
import multer from 'multer';
import { tmuxManager } from '../services/tmux.js';
import { authService } from '../services/auth.js';
import { outputMonitor } from '../services/monitor.js';
import {
  authContextMiddleware,
  requireAuth,
  canPerform,
  isHighRiskKey,
  type RiskLevel,
} from '../middleware/auth.js';
import type { Session } from '../types.js';

const router = Router();
const UPLOAD_DIR = '/tmp/vibe-uploads';

// Convert session to snake_case for frontend compatibility
function toSnakeCase(session: Session) {
  return {
    session_id: session.sessionId,
    project_path: session.projectPath,
    status: session.status,
    created_at: session.createdAt instanceof Date ? session.createdAt.toISOString() : session.createdAt,
    updated_at: session.updatedAt instanceof Date ? session.updatedAt.toISOString() : session.updatedAt,
    output_tail: session.outputTail,
  };
}

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const sessionId = req.params.sessionId;
    const sessionDir = path.join(UPLOAD_DIR, sessionId);
    fs.mkdirSync(sessionDir, { recursive: true });
    cb(null, sessionDir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${uuidv4().replace(/-/g, '').slice(0, 32)}${ext}`);
  },
});

const upload = multer({
  storage,
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['image/png', 'image/jpeg', 'image/gif', 'image/webp'];
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error(`Invalid file type. Allowed: ${allowedTypes.join(', ')}`));
    }
  },
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB
  },
});

// Apply auth context middleware to all routes
router.use(authContextMiddleware);

function requireUploadAccess(req: Request, res: Response, next: NextFunction): void {
  const ctx = req.authContext!;
  const { sessionId } = req.params;

  if (!canPerform(ctx, 'medium')) {
    authService.logAudit({
      deviceId: ctx.device?.id,
      deviceName: ctx.device?.name,
      ip: ctx.ip,
      action: 'file_upload',
      sessionId,
      details: 'Blocked: insufficient permission',
      result: 'blocked',
    });
    res.status(403).json({ error: 'Insufficient permission to upload files' });
    return;
  }

  if (!tmuxManager.sessionExists(sessionId)) {
    res.status(404).json({ error: `Session '${sessionId}' not found` });
    return;
  }

  next();
}

// GET /api/sessions - List all sessions
router.get('/', requireAuth, (req, res) => {
  try {
    const sessions = tmuxManager.listSessions();
    res.json(sessions.map(toSnakeCase));
  } catch (e) {
    console.error('Error listing sessions:', e);
    res.status(500).json({ error: 'Failed to list sessions' });
  }
});

// GET /api/sessions/:sessionId - Get specific session
router.get('/:sessionId', requireAuth, (req, res) => {
  const { sessionId } = req.params;

  const session = tmuxManager.getSession(sessionId);
  if (!session) {
    res.status(404).json({ error: `Session '${sessionId}' not found` });
    return;
  }

  res.json(toSnakeCase(session));
});

// GET /api/sessions/:sessionId/output - Get session output
router.get('/:sessionId/output', requireAuth, (req, res) => {
  const { sessionId } = req.params;
  const withAnsi = req.query.with_ansi === 'true';

  if (!tmuxManager.sessionExists(sessionId)) {
    res.status(404).json({ error: `Session '${sessionId}' not found` });
    return;
  }

  const output = tmuxManager.captureOutput(sessionId, withAnsi);
  if (output === null) {
    res.status(500).json({ error: 'Failed to capture output' });
    return;
  }

  res.json({
    session_id: sessionId,
    output,
    timestamp: new Date().toISOString(),
  });
});

// POST /api/sessions/:sessionId/send - Send command to session
router.post('/:sessionId/send', requireAuth, (req, res) => {
  const { sessionId } = req.params;
  // Support both query params (frontend) and body (API)
  const content = (req.query.content as string) || req.body.content;
  const press_enter = req.query.press_enter !== undefined
    ? req.query.press_enter === 'true'
    : (req.body.press_enter ?? true);
  const ctx = req.authContext!;

  // Validate content
  if (!content) {
    res.status(400).json({ error: 'Content is required' });
    return;
  }

  // Check permission (MEDIUM risk)
  if (!canPerform(ctx, 'medium')) {
    authService.logAudit({
      deviceId: ctx.device?.id,
      deviceName: ctx.device?.name,
      ip: ctx.ip,
      action: 'send_message',
      sessionId,
      details: `Blocked: insufficient permission, content preview: ${(content || '').slice(0, 50)}`,
      result: 'blocked',
    });
    res.status(403).json({ error: 'Insufficient permission to send commands' });
    return;
  }

  if (!tmuxManager.sessionExists(sessionId)) {
    res.status(404).json({ error: `Session '${sessionId}' not found` });
    return;
  }

  const success = tmuxManager.sendKeys(sessionId, content, press_enter);

  if (success) {
    authService.logAudit({
      deviceId: ctx.device?.id,
      deviceName: ctx.device?.name,
      ip: ctx.ip,
      action: 'send_message',
      sessionId,
      details: `content preview: ${(content || '').slice(0, 100)}`,
      result: 'success',
    });

    res.json({
      sessionId,
      content,
      status: 'sent',
      sentAt: new Date().toISOString(),
    });
  } else {
    res.status(500).json({ error: 'Failed to send keys to tmux session' });
  }
});

// POST /api/sessions/:sessionId/key - Send special key
router.post('/:sessionId/key', requireAuth, (req, res) => {
  const { sessionId } = req.params;
  // Support both query params (frontend) and body (API)
  const key = (req.query.key as string) || req.body.key;
  const ctx = req.authContext!;

  // Validate key
  if (!key) {
    res.status(400).json({ error: 'Key is required' });
    return;
  }

  // Determine risk level based on key
  const riskLevel: RiskLevel = isHighRiskKey(key) ? 'high' : 'medium';

  if (!canPerform(ctx, riskLevel)) {
    authService.logAudit({
      deviceId: ctx.device?.id,
      deviceName: ctx.device?.name,
      ip: ctx.ip,
      action: 'send_key',
      sessionId,
      details: `Blocked: key=${key}, risk=${riskLevel}`,
      result: 'blocked',
    });
    res.status(403).json({
      error: `Insufficient permission for ${riskLevel === 'high' ? 'high-risk' : 'this'} key operation`,
    });
    return;
  }

  if (!tmuxManager.sessionExists(sessionId)) {
    res.status(404).json({ error: `Session '${sessionId}' not found` });
    return;
  }

  const success = tmuxManager.sendSpecialKey(sessionId, key);

  if (!success) {
    res.status(500).json({ error: 'Failed to send key' });
    return;
  }

  authService.logAudit({
    deviceId: ctx.device?.id,
    deviceName: ctx.device?.name,
    ip: ctx.ip,
    action: 'send_key',
    sessionId,
    details: `key=${key}, risk=${riskLevel}`,
    result: 'success',
  });

  res.json({ success: true, key, sessionId });
});

// POST /api/sessions - Create new session
router.post('/', requireAuth, (req, res) => {
  const { command = 'claude' } = req.body;
  const ctx = req.authContext!;

  // HIGH risk operation
  if (!canPerform(ctx, 'high')) {
    authService.logAudit({
      deviceId: ctx.device?.id,
      deviceName: ctx.device?.name,
      ip: ctx.ip,
      action: 'session_create',
      details: `Blocked: command=${command}`,
      result: 'blocked',
    });
    res.status(403).json({ error: 'Insufficient permission to create sessions' });
    return;
  }

  const sessionName = tmuxManager.createSession(command);

  if (!sessionName) {
    res.status(500).json({ error: 'Failed to create session' });
    return;
  }

  // Start monitoring the new session
  outputMonitor.startMonitoring(sessionName);

  const session = tmuxManager.getSession(sessionName);
  if (!session) {
    res.status(500).json({ error: 'Session created but not found' });
    return;
  }

  authService.logAudit({
    deviceId: ctx.device?.id,
    deviceName: ctx.device?.name,
    ip: ctx.ip,
    action: 'session_create',
    sessionId: sessionName,
    details: `command=${command}`,
    result: 'success',
  });

  res.status(201).json(toSnakeCase(session));
});

// DELETE /api/sessions/:sessionId - Kill session
router.delete('/:sessionId', requireAuth, (req, res) => {
  const { sessionId } = req.params;
  const ctx = req.authContext!;

  // HIGH risk operation
  if (!canPerform(ctx, 'high')) {
    authService.logAudit({
      deviceId: ctx.device?.id,
      deviceName: ctx.device?.name,
      ip: ctx.ip,
      action: 'session_kill',
      sessionId,
      details: 'Blocked: insufficient permission',
      result: 'blocked',
    });
    res.status(403).json({ error: 'Insufficient permission to kill sessions' });
    return;
  }

  if (!tmuxManager.sessionExists(sessionId)) {
    res.status(404).json({ error: `Session '${sessionId}' not found` });
    return;
  }

  // Stop monitoring
  outputMonitor.stopMonitoring(sessionId);

  const success = tmuxManager.killSession(sessionId);

  if (!success) {
    res.status(500).json({ error: 'Failed to kill session' });
    return;
  }

  authService.logAudit({
    deviceId: ctx.device?.id,
    deviceName: ctx.device?.name,
    ip: ctx.ip,
    action: 'session_kill',
    sessionId,
    result: 'success',
  });

  res.json({ success: true, sessionId });
});

// POST /api/sessions/:sessionId/upload - Upload file
router.post('/:sessionId/upload', requireAuth, requireUploadAccess, upload.single('file'), (req, res) => {
  const { sessionId } = req.params;
  const ctx = req.authContext!;

  if (!req.file) {
    res.status(400).json({ error: 'No file uploaded' });
    return;
  }

  const filePath = req.file.path;

  // First clear any existing input with Escape
  tmuxManager.sendSpecialKey(sessionId, 'Escape');

  // Send file path to Claude using @ syntax (without Enter)
  const success = tmuxManager.sendKeys(sessionId, `@${filePath}`, false);

  if (!success) {
    res.status(500).json({ error: 'Failed to send file path' });
    return;
  }

  authService.logAudit({
    deviceId: ctx.device?.id,
    deviceName: ctx.device?.name,
    ip: ctx.ip,
    action: 'file_upload',
    sessionId,
    details: `filename=${req.file.originalname}, path=${filePath}`,
    result: 'success',
  });

  res.json({
    success: true,
    sessionId,
    path: filePath,
    filename: req.file.originalname,
  });
});

export default router;
