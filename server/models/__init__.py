"""Data models for VibeMobile."""

from datetime import datetime
from typing import Literal, Optional
from pydantic import BaseModel, Field
import uuid

from .device import (
    Device,
    DeviceCreate,
    DeviceInfo,
    PairingCode,
    PairingRequest,
    TrustLevel,
)
from .audit import (
    AuditAction,
    AuditLog,
    AuditLogCreate,
    AuditResult,
    RiskLevel,
    HIGH_RISK_OPERATIONS,
    HIGH_RISK_KEYS,
    is_high_risk_key,
)


class Session(BaseModel):
    """Represents a tmux session running Claude."""

    session_id: str = Field(..., description="tmux session name (e.g., 'vibe-1')")
    project_path: str = Field(default="", description="Working directory")
    status: Literal["active", "detached", "ended"] = Field(
        default="active", description="Session status"
    )
    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: datetime = Field(default_factory=datetime.now)
    output_tail: str = Field(default="", description="Recent output lines")

    class Config:
        json_encoders = {datetime: lambda v: v.isoformat()}


class Command(BaseModel):
    """Represents a command sent to a session."""

    command_id: str = Field(
        default_factory=lambda: str(uuid.uuid4()), description="Unique command ID"
    )
    session_id: str = Field(..., description="Target session ID")
    content: str = Field(..., description="Command content")
    status: Literal["pending", "sent", "failed"] = Field(
        default="pending", description="Command status"
    )
    created_at: datetime = Field(default_factory=datetime.now)
    sent_at: Optional[datetime] = None
    error: Optional[str] = None

    class Config:
        json_encoders = {datetime: lambda v: v.isoformat()}


class SessionOutput(BaseModel):
    """Output from a session."""

    session_id: str
    content: str
    timestamp: datetime = Field(default_factory=datetime.now)
    is_diff: bool = Field(
        default=False, description="Whether this is a diff or full output"
    )


class WSMessage(BaseModel):
    """WebSocket message format."""

    type: str
    data: dict
