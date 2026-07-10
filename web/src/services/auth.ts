// Authentication API service

import type {
  AuthStatus,
  TokenRefreshResponse,
} from '../types/auth';

const API_BASE = import.meta.env.VITE_API_URL || '';

// Generate device fingerprint
export async function generateFingerprint(): Promise<string> {
  const components = [
    navigator.userAgent,
    navigator.language,
    screen.width,
    screen.height,
    screen.colorDepth,
    new Date().getTimezoneOffset(),
    navigator.hardwareConcurrency || 'unknown',
    // @ts-expect-error - deviceMemory is not in all browsers
    navigator.deviceMemory || 'unknown',
  ];

  const data = components.join('|');

  // Hash the fingerprint
  const encoder = new TextEncoder();
  const dataBuffer = encoder.encode(data);
  const hashBuffer = await crypto.subtle.digest('SHA-256', dataBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');
}

export const authApi = {
  // Check authentication status
  async getStatus(): Promise<AuthStatus> {
    const response = await fetch(`${API_BASE}/api/auth/status`, {
      credentials: 'include', // Include cookies
    });
    return response.json();
  },

  // Complete device pairing (called after user enters code on Desktop)
  async completePairing(
    code: string,
    fingerprint: string
  ): Promise<{ device_id: string; message: string }> {
    const response = await fetch(`${API_BASE}/api/auth/pair/complete`, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        'X-Device-Fingerprint': fingerprint,
      },
      body: JSON.stringify({ code, fingerprint }),
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || error.detail || `HTTP ${response.status}`);
    }

    return response.json();
  },

  // Refresh access token using refresh token (in HttpOnly cookie)
  async refreshToken(fingerprint: string): Promise<TokenRefreshResponse> {
    const response = await fetch(`${API_BASE}/api/auth/refresh`, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'X-Device-Fingerprint': fingerprint,
      },
    });

    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || error.detail || `HTTP ${response.status}`);
    }

    return response.json();
  },

  // Logout
  async logout(): Promise<void> {
    await fetch(`${API_BASE}/api/auth/logout`, {
      method: 'POST',
      credentials: 'include',
    });
  },
};
