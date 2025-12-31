// Authentication state store using Zustand

import { create } from 'zustand';
import type { AuthState, TrustLevel } from '../types/auth';
import { authApi, generateFingerprint } from '../services/auth';

interface AuthStore extends AuthState {
  // Device fingerprint (generated once)
  fingerprint: string | null;

  // Actions
  initialize: () => Promise<void>;
  startPairing: (code: string) => Promise<void>;
  refreshAccessToken: () => Promise<void>;
  logout: () => Promise<void>;
  clearError: () => void;

  // Internal
  setAuthenticated: (
    deviceId: string,
    deviceName: string,
    trustLevel: TrustLevel,
    accessToken: string,
    expiresIn: number
  ) => void;
}

// Token refresh margin (refresh 1 minute before expiry)
const TOKEN_REFRESH_MARGIN = 60 * 1000;

// Refresh timer
let refreshTimer: ReturnType<typeof setTimeout> | null = null;

export const useAuthStore = create<AuthStore>((set, get) => ({
  // Initial state
  isAuthenticated: false,
  isLoading: true,
  isPairing: false,
  error: null,
  deviceId: null,
  deviceName: null,
  trustLevel: null,
  accessToken: null,
  accessTokenExpiry: null,
  fingerprint: null,

  // Initialize auth on app start
  initialize: async () => {
    set({ isLoading: true, error: null });

    try {
      // Generate fingerprint
      const fingerprint = await generateFingerprint();
      set({ fingerprint });

      // Check if we have a valid refresh token
      const status = await authApi.getStatus();

      if (status.authenticated && status.device_id) {
        // Try to get a new access token
        try {
          const tokenResponse = await authApi.refreshToken(fingerprint);
          get().setAuthenticated(
            tokenResponse.device_id,
            status.device_name || 'Unknown',
            tokenResponse.trust_level,
            tokenResponse.access_token,
            tokenResponse.expires_in
          );
        } catch {
          // Refresh token invalid, user needs to re-pair
          set({ isAuthenticated: false, isLoading: false });
        }
      } else {
        set({ isAuthenticated: false, isLoading: false });
      }
    } catch (error) {
      console.error('Auth initialization failed:', error);
      set({
        isLoading: false,
        error: error instanceof Error ? error.message : 'Initialization failed',
      });
    }
  },

  // Start pairing process
  startPairing: async (code: string) => {
    const { fingerprint } = get();
    if (!fingerprint) {
      set({ error: 'Fingerprint not generated' });
      return;
    }

    set({ isPairing: true, error: null });

    try {
      const result = await authApi.completePairing(code, fingerprint);

      // After pairing, get access token
      const tokenResponse = await authApi.refreshToken(fingerprint);

      get().setAuthenticated(
        result.device_id,
        tokenResponse.device_id, // Will get proper name from next status check
        tokenResponse.trust_level,
        tokenResponse.access_token,
        tokenResponse.expires_in
      );

      set({ isPairing: false });
    } catch (error) {
      set({
        isPairing: false,
        error: error instanceof Error ? error.message : 'Pairing failed',
      });
    }
  },

  // Refresh access token
  refreshAccessToken: async () => {
    const { fingerprint, isAuthenticated } = get();
    if (!fingerprint || !isAuthenticated) return;

    try {
      const tokenResponse = await authApi.refreshToken(fingerprint);
      get().setAuthenticated(
        tokenResponse.device_id,
        get().deviceName || 'Unknown',
        tokenResponse.trust_level,
        tokenResponse.access_token,
        tokenResponse.expires_in
      );
    } catch (error) {
      console.error('Token refresh failed:', error);
      // Token refresh failed, user needs to re-authenticate
      set({
        isAuthenticated: false,
        accessToken: null,
        accessTokenExpiry: null,
        error: 'Session expired. Please re-authenticate.',
      });

      if (refreshTimer) {
        clearTimeout(refreshTimer);
        refreshTimer = null;
      }
    }
  },

  // Logout
  logout: async () => {
    try {
      await authApi.logout();
    } catch {
      // Ignore logout errors
    }

    if (refreshTimer) {
      clearTimeout(refreshTimer);
      refreshTimer = null;
    }

    set({
      isAuthenticated: false,
      deviceId: null,
      deviceName: null,
      trustLevel: null,
      accessToken: null,
      accessTokenExpiry: null,
      error: null,
    });
  },

  clearError: () => set({ error: null }),

  // Set authenticated state and schedule token refresh
  setAuthenticated: (deviceId, deviceName, trustLevel, accessToken, expiresIn) => {
    const expiry = Date.now() + expiresIn * 1000;

    set({
      isAuthenticated: true,
      isLoading: false,
      deviceId,
      deviceName,
      trustLevel,
      accessToken,
      accessTokenExpiry: expiry,
    });

    // Schedule token refresh before expiry
    if (refreshTimer) {
      clearTimeout(refreshTimer);
    }

    const refreshDelay = Math.max(expiresIn * 1000 - TOKEN_REFRESH_MARGIN, 0);
    refreshTimer = setTimeout(() => {
      get().refreshAccessToken();
    }, refreshDelay);

    console.log(`[Auth] Authenticated as ${deviceName}, token expires in ${expiresIn}s`);
  },
}));
