"""Audit log model for tracking all operations."""

from datetime import datetime
from enum import Enum
from typing import Any, Optional

from pydantic import BaseModel, Field


class AuditAction(str, Enum):
    """Types of auditable actions."""

    # Authentication
    DEVICE_PAIRED = "device_paired"
    DEVICE_REVOKED = "device_revoked"
    TOKEN_REFRESHED = "token_refreshed"
    AUTH_FAILED = "auth_failed"

    # Session operations
    SESSION_VIEW = "session_view"
    SESSION_CREATE = "session_create"
    SESSION_DELETE = "session_delete"

    # Commands
    SEND_MESSAGE = "send_message"
    SEND_KEY = "send_key"
    SEND_SPECIAL_KEY = "send_special_key"

    # File operations
    FILE_UPLOAD = "file_upload"

    # High-risk operations
    OPERATION_REQUESTED = "operation_requested"
    OPERATION_APPROVED = "operation_approved"
    OPERATION_REJECTED = "operation_rejected"


class AuditResult(str, Enum):
    """Result of an audited action."""

    SUCCESS = "success"
    FAILED = "failed"
    BLOCKED = "blocked"
    PENDING = "pending"


class RiskLevel(str, Enum):
    """Risk level of an operation."""

    LOW = "low"  # Viewing operations
    MEDIUM = "medium"  # Normal commands
    HIGH = "high"  # Destructive/sensitive operations


class AuditLog(BaseModel):
    """Audit log entry."""

    id: str = Field(..., description="Unique log entry ID")
    timestamp: datetime = Field(default_factory=datetime.now)
    device_id: Optional[str] = Field(default=None, description="Device that performed action")
    device_name: Optional[str] = Field(default=None)
    ip: str = Field(..., description="IP address")
    action: AuditAction
    session_id: Optional[str] = Field(default=None)
    details: dict[str, Any] = Field(default_factory=dict)
    risk_level: RiskLevel = Field(default=RiskLevel.LOW)
    result: AuditResult = Field(default=AuditResult.SUCCESS)
    error_message: Optional[str] = Field(default=None)


class AuditLogCreate(BaseModel):
    """Data for creating an audit log entry."""

    device_id: Optional[str] = None
    device_name: Optional[str] = None
    ip: str
    action: AuditAction
    session_id: Optional[str] = None
    details: dict[str, Any] = Field(default_factory=dict)
    risk_level: RiskLevel = RiskLevel.LOW
    result: AuditResult = AuditResult.SUCCESS
    error_message: Optional[str] = None


# Define which operations are high-risk and need confirmation
HIGH_RISK_OPERATIONS = {
    AuditAction.SESSION_CREATE,
    AuditAction.SESSION_DELETE,
    AuditAction.FILE_UPLOAD,
}

# Special keys that are considered high-risk
HIGH_RISK_KEYS = {
    "C-c",  # Ctrl+C
    "C-d",  # Ctrl+D
    "C-z",  # Ctrl+Z
    "C-\\",  # Ctrl+\
}


def is_high_risk_key(key: str) -> bool:
    """Check if a key combination is high-risk."""
    return key in HIGH_RISK_KEYS
