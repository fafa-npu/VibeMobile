"""Device model for authentication and device management."""

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class TrustLevel(str, Enum):
    """Device trust level for operation permissions."""

    FULL = "full"  # All operations without confirmation
    PARTIAL = "partial"  # High-risk operations need Desktop confirmation
    VIEW_ONLY = "view_only"  # Only viewing, all actions need confirmation


class Device(BaseModel):
    """Registered device information."""

    id: str = Field(..., description="Unique device identifier")
    fingerprint_hash: str = Field(..., description="Hashed device fingerprint")
    name: str = Field(..., description="Device name (from User-Agent)")
    browser: str = Field(default="Unknown", description="Browser name")
    os: str = Field(default="Unknown", description="Operating system")
    ip: str = Field(..., description="Last known IP address")
    location: str = Field(default="Unknown", description="IP geolocation")
    trust_level: TrustLevel = Field(
        default=TrustLevel.PARTIAL, description="Trust level for operations"
    )
    created_at: datetime = Field(default_factory=datetime.now)
    last_active: datetime = Field(default_factory=datetime.now)
    refresh_token_hash: Optional[str] = Field(
        default=None, description="Hashed refresh token for validation"
    )
    is_active: bool = Field(default=True, description="Whether device is active")

    class Config:
        use_enum_values = True


class DeviceCreate(BaseModel):
    """Data for creating a new device."""

    fingerprint: str
    name: str
    browser: str = "Unknown"
    os: str = "Unknown"
    ip: str
    location: str = "Unknown"


class DeviceInfo(BaseModel):
    """Device info for display (without sensitive data)."""

    id: str
    name: str
    browser: str
    os: str
    ip: str
    location: str
    trust_level: TrustLevel
    created_at: datetime
    last_active: datetime
    is_current: bool = False


class PairingCode(BaseModel):
    """Temporary pairing code for device registration."""

    code: str = Field(..., description="6-digit pairing code")
    created_at: datetime = Field(default_factory=datetime.now)
    expires_at: datetime
    used: bool = Field(default=False)


class PairingRequest(BaseModel):
    """Request from mobile device to complete pairing."""

    code: str
    fingerprint: str
    user_agent: str
