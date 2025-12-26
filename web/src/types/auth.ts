// Authentication types

export interface Device {
  id: string;
  name: string;
  browser: string;
  os: string;
  ip: string;
  trust_level: TrustLevel;
  is_active: boolean;
  created_at: string;
  last_active_at: string;
}

export type TrustLevel = 'full' | 'partial' | 'view_only';

export interface AuthStatus {
  authenticated: boolean;
  device_id?: string;
  device_name?: string;
  trust_level?: TrustLevel;
  reason?: string;
}

export interface PairingInitResponse {
  code: string;
  expires_in: number;
}

export interface TokenRefreshResponse {
  access_token: string;
  expires_in: number;
  device_id: string;
  trust_level: TrustLevel;
}

export interface AuthState {
  // Current state
  isAuthenticated: boolean;
  isLoading: boolean;
  isPairing: boolean;
  error: string | null;

  // Device info
  deviceId: string | null;
  deviceName: string | null;
  trustLevel: TrustLevel | null;

  // Access token (stored in memory only)
  accessToken: string | null;
  accessTokenExpiry: number | null;
}
