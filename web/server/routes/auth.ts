// Authentication API routes
import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { authService } from '../services/auth.js';
import { wsManager } from '../services/ws.js';
import {
  authContextMiddleware,
  requireLocal,
  getClientIp,
  isSecureRequest,
  parseUserAgent,
} from '../middleware/auth.js';

const router = Router();
const pairingAttempts = new Map<string, number[]>();
const PAIRING_ATTEMPT_WINDOW_MS = 60_000;
const MAX_PAIRING_ATTEMPTS = 5;
let lastPairingAttemptCleanup = 0;

// Apply auth context middleware
router.use(authContextMiddleware);

// Helper to wait for approval
async function waitForApproval(approvalId: string, timeout: number = 60): Promise<boolean> {
  const startTime = Date.now();

  while (Date.now() - startTime < timeout * 1000) {
    const approval = authService.getPendingApproval(approvalId);
    if (approval) {
      if (approval.status === 'approved') return true;
      if (approval.status === 'rejected') return false;
    }
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  return false;
}

// POST /api/auth/pair/initiate - Initiate pairing (Desktop only)
router.post('/pair/initiate', requireLocal, (req, res) => {
  const pairingCode = authService.generatePairingCode();

  res.json({
    code: pairingCode.code,
    expires_in: 300, // 5 minutes
  });
});

// POST /api/auth/pair/complete - Complete pairing
router.post('/pair/complete', async (req, res) => {
  const { code, fingerprint } = req.body;
  const clientIp = getClientIp(req);
  const now = Date.now();
  if (now - lastPairingAttemptCleanup >= PAIRING_ATTEMPT_WINDOW_MS) {
    for (const [ip, attempts] of pairingAttempts) {
      const activeAttempts = attempts.filter(
        timestamp => now - timestamp < PAIRING_ATTEMPT_WINDOW_MS
      );
      if (activeAttempts.length === 0) {
        pairingAttempts.delete(ip);
      } else {
        pairingAttempts.set(ip, activeAttempts);
      }
    }
    lastPairingAttemptCleanup = now;
  }
  const recentAttempts = (pairingAttempts.get(clientIp) || [])
    .filter(timestamp => now - timestamp < PAIRING_ATTEMPT_WINDOW_MS);

  if (recentAttempts.length >= MAX_PAIRING_ATTEMPTS) {
    res.status(429).json({ error: 'Too many pairing attempts. Please try again later' });
    return;
  }
  recentAttempts.push(now);
  pairingAttempts.set(clientIp, recentAttempts);

  if (typeof code !== 'string' || typeof fingerprint !== 'string' || !fingerprint) {
    res.status(400).json({ error: 'Pairing code and device fingerprint are required' });
    return;
  }

  // Verify pairing code
  if (!authService.verifyPairingCode(code)) {
    authService.logAudit({
      ip: clientIp,
      action: 'auth_failed',
      details: 'Invalid or expired pairing code',
      result: 'failed',
    });
    res.status(401).json({ error: 'Invalid or expired pairing code' });
    return;
  }

  // Parse device info from User-Agent
  const userAgent = req.headers['user-agent'] || 'Unknown';
  const { deviceName, browser, os } = parseUserAgent(userAgent);

  // Create approval request for Desktop
  const approvalId = uuidv4();
  const approvalData = {
    type: 'pairing_request',
    approval_id: approvalId,
    fingerprint,
    device_name: deviceName,
    browser,
    os,
    ip: clientIp,
    user_agent: userAgent,
    timestamp: new Date().toISOString(),
  };

  authService.requestApproval(approvalId, approvalData);

  // Send to Desktop via WebSocket
  await wsManager.broadcastToDesktop({
    type: 'pairing_request',
    data: approvalData,
  });

  // Wait for Desktop approval (up to 60 seconds)
  const approved = await waitForApproval(approvalId, 60);

  if (!approved) {
    authService.logAudit({
      ip: clientIp,
      action: 'auth_failed',
      details: `Pairing rejected or timed out, device=${deviceName}`,
      result: 'blocked',
    });
    res.status(403).json({ error: 'Pairing request rejected or timed out' });
    return;
  }

  // Mark code as used
  authService.markCodeUsed(code);

  // Create device
  const device = authService.createDevice({
    fingerprint,
    name: deviceName,
    browser,
    os,
    ip: clientIp,
  });

  // Create refresh token
  const refreshToken = authService.createRefreshToken(device.id);

  // Log successful pairing
  authService.logAudit({
    deviceId: device.id,
    deviceName: device.name,
    ip: clientIp,
    action: 'device_paired',
    details: `browser=${browser}, os=${os}`,
    result: 'success',
  });

  // Set refresh token as HttpOnly cookie and return response
  res.cookie('refresh_token', refreshToken, {
    httpOnly: true,
    secure: isSecureRequest(req),
    sameSite: 'strict',
    maxAge: 30 * 24 * 3600 * 1000, // 30 days
    path: '/api/auth',
  });

  res.json({
    device_id: device.id,
    message: 'Device paired successfully',
  });
});

// POST /api/auth/refresh - Refresh access token
router.post('/refresh', (req, res) => {
  const refreshToken = req.cookies?.refresh_token;
  const clientIp = getClientIp(req);

  if (!refreshToken) {
    res.status(401).json({ error: 'No refresh token' });
    return;
  }

  // Verify refresh token
  const device = authService.verifyRefreshToken(refreshToken);
  if (!device) {
    res.status(401).json({ error: 'Invalid or expired refresh token' });
    return;
  }

  // Verify fingerprint if provided
  const fingerprint = req.headers['x-device-fingerprint'] as string | undefined;
  if (fingerprint && !authService.verifyFingerprint(device, fingerprint)) {
    authService.logAudit({
      deviceId: device.id,
      deviceName: device.name,
      ip: clientIp,
      action: 'auth_failed',
      details: 'Fingerprint mismatch',
      result: 'blocked',
    });
    res.status(401).json({ error: 'Device fingerprint mismatch' });
    return;
  }

  // Update device activity
  authService.updateDeviceActivity(device.id, clientIp);

  // Create new access token
  const { token: accessToken, expiresIn } = authService.createAccessToken(device.id);

  // Log token refresh
  authService.logAudit({
    deviceId: device.id,
    deviceName: device.name,
    ip: clientIp,
    action: 'token_refreshed',
    result: 'success',
  });

  res.json({
    access_token: accessToken,
    expires_in: expiresIn,
    device_id: device.id,
    trust_level: device.trustLevel,
  });
});

// POST /api/auth/logout - Logout
router.post('/logout', (req, res) => {
  const refreshToken = req.cookies?.refresh_token;
  const clientIp = getClientIp(req);

  if (refreshToken) {
    const device = authService.verifyRefreshToken(refreshToken);
    if (device) {
      // Revoke the device to invalidate the refresh token
      authService.revokeDevice(device.id);

      authService.logAudit({
        deviceId: device.id,
        deviceName: device.name,
        ip: clientIp,
        action: 'device_revoked',
        details: 'User logout',
        result: 'success',
      });
    }
  }

  // Clear cookie
  res.clearCookie('refresh_token', { path: '/api/auth' });
  res.json({ message: 'Logged out' });
});

// GET /api/auth/devices - List devices (Desktop only)
router.get('/devices', requireLocal, (req, res) => {
  const devices = authService.listDevices();
  res.json(devices);
});

// PUT /api/auth/devices/:deviceId/trust - Update device trust level (Desktop only)
router.put('/devices/:deviceId/trust', requireLocal, (req, res) => {
  const { deviceId } = req.params;
  const { trust_level } = req.body;

  if (!authService.updateDeviceTrustLevel(deviceId, trust_level)) {
    res.status(404).json({ error: 'Device not found' });
    return;
  }

  res.json({ message: 'Trust level updated', device_id: deviceId });
});

// DELETE /api/auth/devices/:deviceId - Revoke device (Desktop only)
router.delete('/devices/:deviceId', requireLocal, (req, res) => {
  const { deviceId } = req.params;
  const clientIp = getClientIp(req);

  const device = authService.getDevice(deviceId);
  if (!device) {
    res.status(404).json({ error: 'Device not found' });
    return;
  }

  authService.revokeDevice(deviceId);

  authService.logAudit({
    deviceId,
    deviceName: device.name,
    ip: clientIp,
    action: 'device_revoked',
    details: 'Manual revocation',
    result: 'success',
  });

  res.json({ message: 'Device revoked', device_id: deviceId });
});

// POST /api/auth/approve - Handle approval from Desktop
router.post('/approve', requireLocal, (req, res) => {
  const { approval_id, action } = req.body;

  const approval = authService.getPendingApproval(approval_id);
  if (!approval) {
    res.status(404).json({ error: 'Approval request not found' });
    return;
  }

  if (action === 'approve') {
    authService.approveRequest(approval_id);
    res.json({ message: 'Request approved' });
  } else if (action === 'reject') {
    authService.rejectRequest(approval_id);
    res.json({ message: 'Request rejected' });
  } else {
    res.status(400).json({ error: 'Invalid action' });
  }
});

// GET /api/auth/status - Check authentication status
router.get('/status', (req, res) => {
  const refreshToken = req.cookies?.refresh_token;

  if (!refreshToken) {
    res.json({ authenticated: false, reason: 'No refresh token' });
    return;
  }

  const device = authService.verifyRefreshToken(refreshToken);
  if (!device) {
    res.json({ authenticated: false, reason: 'Invalid refresh token' });
    return;
  }

  res.json({
    authenticated: true,
    device_id: device.id,
    device_name: device.name,
    trust_level: device.trustLevel,
  });
});

export default router;
