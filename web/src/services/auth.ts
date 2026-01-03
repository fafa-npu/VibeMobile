// Authentication API service

import type {
  AuthStatus,
  TokenRefreshResponse,
} from '../types/auth';

const API_BASE = import.meta.env.VITE_API_URL || '';

// Simple hash function for non-secure contexts (fallback when crypto.subtle unavailable)
function simpleHash(str: string): string {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    const char = str.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32bit integer
  }
  // Convert to hex and pad to ensure consistent length
  const hex = Math.abs(hash).toString(16);
  // Create a longer hash by hashing different portions
  let result = '';
  for (let i = 0; i < 4; i++) {
    let subHash = 0;
    for (let j = 0; j < str.length; j++) {
      const char = str.charCodeAt(j);
      subHash = ((subHash << 5) - subHash + i) + char;
      subHash = subHash & subHash;
    }
    result += Math.abs(subHash).toString(16).padStart(8, '0');
  }
  return result + hex.padStart(8, '0');
}

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

  // Use crypto.subtle if available (requires secure context: HTTPS or localhost)
  // Otherwise fall back to simple hash for HTTP connections
  if (typeof crypto !== 'undefined' && crypto.subtle) {
    try {
      const encoder = new TextEncoder();
      const dataBuffer = encoder.encode(data);
      const hashBuffer = await crypto.subtle.digest('SHA-256', dataBuffer);
      const hashArray = Array.from(new Uint8Array(hashBuffer));
      return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');
    } catch (error) {
      console.warn('crypto.subtle failed, using fallback hash:', error);
    }
  }

  // Fallback for non-secure contexts (HTTP)
  console.warn('crypto.subtle not available (non-HTTPS context), using fallback fingerprint');
  return simpleHash(data);
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
      throw new Error(error.detail || `HTTP ${response.status}`);
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
      throw new Error(error.detail || `HTTP ${response.status}`);
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
