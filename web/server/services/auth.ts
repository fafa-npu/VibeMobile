// Authentication service for device management and token handling
import jwt from 'jsonwebtoken';
import { v4 as uuidv4 } from 'uuid';
import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import os from 'os';
import type { Device, DeviceCreate, DeviceInfo, PairingCode, TrustLevel } from '../types.js';

// JWT settings
const ALGORITHM = 'HS256';
const ACCESS_TOKEN_EXPIRE_MINUTES = 15;
const REFRESH_TOKEN_EXPIRE_DAYS = 30;

// Storage paths
const DATA_DIR = path.join(os.homedir(), '.vibemobile');
const DEVICES_FILE = path.join(DATA_DIR, 'devices.json');
const AUDIT_LOG_FILE = path.join(DATA_DIR, 'audit.log');

class AuthService {
  private secretKey: string;
  private devices: Map<string, Device> = new Map();
  private pairingCodes: Map<string, PairingCode> = new Map();
  private pendingApprovals: Map<string, { data: unknown; createdAt: Date; status: string }> = new Map();

  constructor() {
    this.ensureDataDir();
    this.secretKey = this.getOrCreateSecretKey();
    this.loadDevices();
  }

  private ensureDataDir(): void {
    if (!fs.existsSync(DATA_DIR)) {
      fs.mkdirSync(DATA_DIR, { recursive: true });
    }
  }

  private getOrCreateSecretKey(): string {
    const keyFile = path.join(DATA_DIR, '.secret_key');
    if (fs.existsSync(keyFile)) {
      return fs.readFileSync(keyFile, 'utf-8').trim();
    }

    // Generate new secret key
    const secretKey = crypto.randomBytes(32).toString('base64url');
    fs.writeFileSync(keyFile, secretKey, { mode: 0o600 });
    return secretKey;
  }

  private loadDevices(): void {
    if (fs.existsSync(DEVICES_FILE)) {
      try {
        const data = JSON.parse(fs.readFileSync(DEVICES_FILE, 'utf-8'));
        for (const deviceData of data) {
          // Convert date strings back to Date objects
          deviceData.createdAt = new Date(deviceData.createdAt);
          deviceData.lastActive = new Date(deviceData.lastActive);
          this.devices.set(deviceData.id, deviceData);
        }
        console.log(`Loaded ${this.devices.size} devices`);
      } catch (e) {
        console.error('Failed to load devices:', e);
        this.devices = new Map();
      }
    }
  }

  private saveDevices(): void {
    try {
      const data = Array.from(this.devices.values());
      fs.writeFileSync(DEVICES_FILE, JSON.stringify(data, null, 2), { mode: 0o600 });
    } catch (e) {
      console.error('Failed to save devices:', e);
    }
  }

  // ==================== Fingerprint Handling ====================

  hashFingerprint(fingerprint: string): string {
    return crypto.createHash('sha256').update(fingerprint).digest('hex');
  }

  verifyFingerprint(device: Device, fingerprint: string): boolean {
    return device.fingerprintHash === this.hashFingerprint(fingerprint);
  }

  // ==================== Pairing Code Management ====================

  generatePairingCode(): PairingCode {
    // Clean up expired codes
    this.cleanupExpiredCodes();

    const code = String(Math.floor(100000 + Math.random() * 900000));
    const pairingCode: PairingCode = {
      code,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 5 * 60 * 1000),
      used: false,
    };
    this.pairingCodes.set(code, pairingCode);
    console.log(`Generated pairing code: ${code}`);
    return pairingCode;
  }

  verifyPairingCode(code: string): boolean {
    const pairingCode = this.pairingCodes.get(code);
    if (!pairingCode) return false;
    if (pairingCode.used) return false;
    if (new Date() > pairingCode.expiresAt) return false;
    return true;
  }

  markCodeUsed(code: string): void {
    const pairingCode = this.pairingCodes.get(code);
    if (pairingCode) {
      pairingCode.used = true;
    }
  }

  private cleanupExpiredCodes(): void {
    const now = new Date();
    for (const [code, pc] of this.pairingCodes) {
      if (now > pc.expiresAt || pc.used) {
        this.pairingCodes.delete(code);
      }
    }
  }

  // ==================== Device Management ====================

  createDevice(data: DeviceCreate): Device {
    const deviceId = uuidv4();
    const device: Device = {
      id: deviceId,
      fingerprintHash: this.hashFingerprint(data.fingerprint),
      name: data.name,
      browser: data.browser,
      os: data.os,
      ip: data.ip,
      location: data.location,
      trustLevel: 'partial',
      isActive: true,
      createdAt: new Date(),
      lastActive: new Date(),
    };
    this.devices.set(deviceId, device);
    this.saveDevices();
    console.log(`Created device: ${deviceId} (${device.name})`);
    return device;
  }

  getDevice(deviceId: string): Device | undefined {
    return this.devices.get(deviceId);
  }

  getDeviceByFingerprint(fingerprint: string): Device | undefined {
    const fpHash = this.hashFingerprint(fingerprint);
    for (const device of this.devices.values()) {
      if (device.fingerprintHash === fpHash && device.isActive) {
        return device;
      }
    }
    return undefined;
  }

  listDevices(): DeviceInfo[] {
    return Array.from(this.devices.values())
      .filter(d => d.isActive)
      .map(d => ({
        id: d.id,
        name: d.name,
        browser: d.browser,
        os: d.os,
        ip: d.ip,
        location: d.location,
        trustLevel: d.trustLevel,
        createdAt: d.createdAt,
        lastActive: d.lastActive,
      }));
  }

  updateDeviceActivity(deviceId: string, ip: string): void {
    const device = this.devices.get(deviceId);
    if (device) {
      device.lastActive = new Date();
      device.ip = ip;
      this.saveDevices();
    }
  }

  updateDeviceTrustLevel(deviceId: string, trustLevel: TrustLevel): boolean {
    const device = this.devices.get(deviceId);
    if (device) {
      device.trustLevel = trustLevel;
      this.saveDevices();
      console.log(`Updated device ${deviceId} trust level to ${trustLevel}`);
      return true;
    }
    return false;
  }

  revokeDevice(deviceId: string): boolean {
    const device = this.devices.get(deviceId);
    if (device) {
      device.isActive = false;
      device.refreshTokenHash = undefined;
      this.saveDevices();
      console.log(`Revoked device: ${deviceId}`);
      return true;
    }
    return false;
  }

  // ==================== Token Management ====================

  createAccessToken(deviceId: string): { token: string; expiresIn: number } {
    const device = this.getDevice(deviceId);
    if (!device) {
      throw new Error('Device not found');
    }

    const payload = {
      sub: deviceId,
      type: 'access',
      trust_level: device.trustLevel,
    };

    const token = jwt.sign(payload, this.secretKey, {
      algorithm: ALGORITHM,
      expiresIn: `${ACCESS_TOKEN_EXPIRE_MINUTES}m`,
    });

    return { token, expiresIn: ACCESS_TOKEN_EXPIRE_MINUTES * 60 };
  }

  createRefreshToken(deviceId: string): string {
    const tokenId = crypto.randomBytes(16).toString('base64url');

    const payload = {
      sub: deviceId,
      type: 'refresh',
      jti: tokenId,
    };

    const token = jwt.sign(payload, this.secretKey, {
      algorithm: ALGORITHM,
      expiresIn: `${REFRESH_TOKEN_EXPIRE_DAYS}d`,
    });

    // Store token hash in device record
    const device = this.devices.get(deviceId);
    if (device) {
      device.refreshTokenHash = crypto.createHash('sha256').update(token).digest('hex');
      this.saveDevices();
    }

    return token;
  }

  verifyAccessToken(token: string): { sub: string; type: string; trust_level: TrustLevel } | null {
    try {
      const payload = jwt.verify(token, this.secretKey) as {
        sub: string;
        type: string;
        trust_level: TrustLevel;
      };
      if (payload.type !== 'access') return null;
      return payload;
    } catch {
      return null;
    }
  }

  verifyRefreshToken(token: string): Device | null {
    try {
      const payload = jwt.verify(token, this.secretKey) as {
        sub: string;
        type: string;
        jti: string;
      };
      if (payload.type !== 'refresh') return null;

      const device = this.getDevice(payload.sub);
      if (!device || !device.isActive) return null;

      // Verify token hash matches
      const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
      if (device.refreshTokenHash !== tokenHash) {
        console.warn(`Refresh token hash mismatch for device ${payload.sub}`);
        return null;
      }

      return device;
    } catch {
      return null;
    }
  }

  // ==================== Desktop Approval ====================

  requestApproval(approvalId: string, data: unknown): string {
    this.pendingApprovals.set(approvalId, {
      data,
      createdAt: new Date(),
      status: 'pending',
    });
    return approvalId;
  }

  getPendingApproval(approvalId: string): { data: unknown; status: string } | undefined {
    return this.pendingApprovals.get(approvalId);
  }

  approveRequest(approvalId: string): boolean {
    const approval = this.pendingApprovals.get(approvalId);
    if (approval) {
      approval.status = 'approved';
      return true;
    }
    return false;
  }

  rejectRequest(approvalId: string): boolean {
    const approval = this.pendingApprovals.get(approvalId);
    if (approval) {
      approval.status = 'rejected';
      return true;
    }
    return false;
  }

  cleanupApprovals(): void {
    const now = new Date();
    const fiveMinutes = 5 * 60 * 1000;
    for (const [aid, data] of this.pendingApprovals) {
      if (now.getTime() - data.createdAt.getTime() > fiveMinutes) {
        this.pendingApprovals.delete(aid);
      }
    }
  }

  // ==================== Audit Logging ====================

  logAudit(entry: {
    deviceId?: string;
    deviceName?: string;
    ip: string;
    action: string;
    sessionId?: string;
    details?: string;
    result: string;
  }): void {
    try {
      const timestamp = new Date().toISOString();
      let logLine = `[${timestamp}] [${entry.result.toUpperCase()}] `;
      logLine += `device=${entry.deviceName || 'unknown'} `;
      logLine += `ip=${entry.ip} `;
      logLine += `action=${entry.action} `;
      if (entry.sessionId) {
        logLine += `session=${entry.sessionId} `;
      }
      if (entry.details) {
        const details = entry.details.length > 100
          ? entry.details.slice(0, 100) + '...'
          : entry.details;
        logLine += `details=${details}`;
      }

      fs.appendFileSync(AUDIT_LOG_FILE, logLine.trim() + '\n');
    } catch (e) {
      console.error('Failed to write audit log:', e);
    }
  }

  getRecentAuditLogs(limit = 100): string[] {
    if (!fs.existsSync(AUDIT_LOG_FILE)) return [];

    try {
      const content = fs.readFileSync(AUDIT_LOG_FILE, 'utf-8');
      const lines = content.trim().split('\n');
      return lines.slice(-limit);
    } catch (e) {
      console.error('Failed to read audit log:', e);
      return [];
    }
  }
}

// Singleton instance
export const authService = new AuthService();
