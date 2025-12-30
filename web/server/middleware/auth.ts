// Authentication middleware and helpers
import type { Request, Response, NextFunction } from 'express';
import { authService } from '../services/auth.js';
import type { Device, TrustLevel } from '../types.js';

// Extend Express Request type using module augmentation
declare module 'express-serve-static-core' {
  interface Request {
    device?: Device;
    authContext?: AuthContext;
  }
}

export interface AuthContext {
  device: Device | null;
  ip: string;
  isLocal: boolean;
  isAuthenticated: boolean;
  trustLevel: TrustLevel;
}

export type RiskLevel = 'low' | 'medium' | 'high';

const HIGH_RISK_KEYS = ['C-c', 'C-d', 'C-z', 'C-\\'];

export function isHighRiskKey(key: string): boolean {
  return HIGH_RISK_KEYS.includes(key);
}

export function getClientIp(req: Request): string {
  const forwarded = req.headers['x-forwarded-for'];
  if (forwarded) {
    const ip = Array.isArray(forwarded) ? forwarded[0] : forwarded.split(',')[0];
    return ip.trim();
  }

  const cfIp = req.headers['cf-connecting-ip'];
  if (cfIp) {
    return Array.isArray(cfIp) ? cfIp[0] : cfIp;
  }

  return req.socket.remoteAddress || 'unknown';
}

export function isLocalRequest(req: Request): boolean {
  const ip = getClientIp(req);
  return ip === '127.0.0.1' || ip === 'localhost' || ip === '::1' || ip === '::ffff:127.0.0.1';
}

export function getDeviceFromToken(req: Request): Device | null {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return null;
  }

  const token = authHeader.slice(7);
  const payload = authService.verifyAccessToken(token);
  if (!payload) {
    return null;
  }

  const device = authService.getDevice(payload.sub);
  if (!device || !device.isActive) {
    return null;
  }

  // Verify fingerprint if provided
  const fingerprint = req.headers['x-device-fingerprint'] as string | undefined;
  if (fingerprint && !authService.verifyFingerprint(device, fingerprint)) {
    console.warn(`Fingerprint mismatch for device ${device.id}`);
    return null;
  }

  return device;
}

export function getAuthContext(req: Request): AuthContext {
  const device = getDeviceFromToken(req);
  const ip = getClientIp(req);
  const isLocal = isLocalRequest(req);

  let trustLevel: TrustLevel = 'view_only';
  if (device) {
    trustLevel = device.trustLevel;
  } else if (isLocal) {
    trustLevel = 'full';
  }

  return {
    device,
    ip,
    isLocal,
    isAuthenticated: device !== null,
    trustLevel,
  };
}

export function canPerform(ctx: AuthContext, riskLevel: RiskLevel): boolean {
  if (ctx.isLocal) return true;
  if (!ctx.device) return false;

  switch (riskLevel) {
    case 'low':
      return true;
    case 'medium':
      return ctx.device.trustLevel === 'partial' || ctx.device.trustLevel === 'full';
    case 'high':
      return ctx.device.trustLevel === 'full';
    default:
      return false;
  }
}

// Middleware to attach auth context
export function authContextMiddleware(req: Request, res: Response, next: NextFunction): void {
  req.authContext = getAuthContext(req);
  req.device = req.authContext.device || undefined;
  next();
}

// Middleware to require authentication
export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const ctx = req.authContext || getAuthContext(req);

  if (!ctx.isAuthenticated && !ctx.isLocal) {
    authService.logAudit({
      ip: ctx.ip,
      action: 'auth_failed',
      details: 'Missing or invalid token',
      result: 'blocked',
    });
    res.status(401).json({ error: 'Not authenticated' });
    return;
  }

  next();
}

// Middleware to require local access only
export function requireLocal(req: Request, res: Response, next: NextFunction): void {
  const ctx = req.authContext || getAuthContext(req);

  if (!ctx.isLocal) {
    authService.logAudit({
      ip: ctx.ip,
      action: 'auth_failed',
      details: 'Non-local access attempt to local-only endpoint',
      result: 'blocked',
    });
    res.status(403).json({ error: 'Only accessible locally' });
    return;
  }

  next();
}

// User-Agent parsing
export function parseUserAgent(userAgent: string): { deviceName: string; browser: string; os: string } {
  let browser = 'Unknown';
  let os = 'Unknown';
  let deviceName = 'Unknown Device';

  // Detect browser
  if (userAgent.includes('Chrome') && userAgent.includes('Safari')) {
    const match = userAgent.match(/Chrome\/(\d+)/);
    browser = match ? `Chrome ${match[1]}` : 'Chrome';
  } else if (userAgent.includes('Safari') && !userAgent.includes('Chrome')) {
    browser = 'Safari';
  } else if (userAgent.includes('Firefox')) {
    browser = 'Firefox';
  } else if (userAgent.includes('Edge')) {
    browser = 'Edge';
  }

  // Detect OS
  if (userAgent.includes('iPhone')) {
    os = 'iOS';
    deviceName = 'iPhone';
  } else if (userAgent.includes('iPad')) {
    os = 'iPadOS';
    deviceName = 'iPad';
  } else if (userAgent.includes('Android')) {
    os = 'Android';
    deviceName = 'Android Device';
  } else if (userAgent.includes('Mac OS X') || userAgent.includes('Macintosh')) {
    os = 'macOS';
    deviceName = 'Mac';
  } else if (userAgent.includes('Windows')) {
    os = 'Windows';
    deviceName = 'Windows PC';
  } else if (userAgent.includes('Linux')) {
    os = 'Linux';
    deviceName = 'Linux PC';
  }

  deviceName = `${deviceName} (${browser})`;

  return { deviceName, browser, os };
}
