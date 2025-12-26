"""Authentication service for device management and token handling."""

import hashlib
import json
import logging
import os
import random
import secrets
import string
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional

from jose import JWTError, jwt
from passlib.context import CryptContext

from ..config import settings
from ..models.device import Device, DeviceCreate, DeviceInfo, PairingCode, TrustLevel
from ..models.audit import AuditAction, AuditLog, AuditLogCreate, AuditResult, RiskLevel

logger = logging.getLogger(__name__)

# Password hashing context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# JWT settings
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 15
REFRESH_TOKEN_EXPIRE_DAYS = 30

# Storage paths
DATA_DIR = Path.home() / ".vibemobile"
DEVICES_FILE = DATA_DIR / "devices.json"
AUDIT_LOG_FILE = DATA_DIR / "audit.log"


class AuthService:
    """Service for authentication, device management, and audit logging."""

    def __init__(self):
        self._ensure_data_dir()
        self._secret_key = self._get_or_create_secret_key()
        self._devices: dict[str, Device] = {}
        self._pairing_codes: dict[str, PairingCode] = {}
        self._pending_approvals: dict[str, dict] = {}  # For Desktop confirmation
        self._load_devices()

    def _ensure_data_dir(self):
        """Create data directory if it doesn't exist."""
        DATA_DIR.mkdir(parents=True, exist_ok=True)

    def _get_or_create_secret_key(self) -> str:
        """Get or create JWT secret key."""
        key_file = DATA_DIR / ".secret_key"
        if key_file.exists():
            return key_file.read_text().strip()

        # Generate new secret key
        secret_key = secrets.token_urlsafe(32)
        key_file.write_text(secret_key)
        key_file.chmod(0o600)  # Restrict permissions
        return secret_key

    def _load_devices(self):
        """Load devices from storage."""
        if DEVICES_FILE.exists():
            try:
                data = json.loads(DEVICES_FILE.read_text())
                for device_data in data:
                    device = Device(**device_data)
                    self._devices[device.id] = device
                logger.info(f"Loaded {len(self._devices)} devices")
            except Exception as e:
                logger.error(f"Failed to load devices: {e}")
                self._devices = {}

    def _save_devices(self):
        """Save devices to storage."""
        try:
            data = [device.model_dump() for device in self._devices.values()]
            # Convert datetime objects to strings
            for item in data:
                for key, value in item.items():
                    if isinstance(value, datetime):
                        item[key] = value.isoformat()
            DEVICES_FILE.write_text(json.dumps(data, indent=2))
            DEVICES_FILE.chmod(0o600)
        except Exception as e:
            logger.error(f"Failed to save devices: {e}")

    # ==================== Fingerprint Handling ====================

    def hash_fingerprint(self, fingerprint: str) -> str:
        """Hash a device fingerprint for storage."""
        return hashlib.sha256(fingerprint.encode()).hexdigest()

    def verify_fingerprint(self, device: Device, fingerprint: str) -> bool:
        """Verify if fingerprint matches device."""
        return device.fingerprint_hash == self.hash_fingerprint(fingerprint)

    # ==================== Pairing Code Management ====================

    def generate_pairing_code(self) -> PairingCode:
        """Generate a 6-digit pairing code valid for 5 minutes."""
        # Clean up expired codes
        self._cleanup_expired_codes()

        code = "".join(random.choices(string.digits, k=6))
        pairing_code = PairingCode(
            code=code,
            created_at=datetime.now(),
            expires_at=datetime.now() + timedelta(minutes=5),
        )
        self._pairing_codes[code] = pairing_code
        logger.info(f"Generated pairing code: {code}")
        return pairing_code

    def verify_pairing_code(self, code: str) -> bool:
        """Verify if a pairing code is valid."""
        pairing_code = self._pairing_codes.get(code)
        if not pairing_code:
            return False
        if pairing_code.used:
            return False
        if datetime.now() > pairing_code.expires_at:
            return False
        return True

    def mark_code_used(self, code: str):
        """Mark a pairing code as used."""
        if code in self._pairing_codes:
            self._pairing_codes[code].used = True

    def _cleanup_expired_codes(self):
        """Remove expired pairing codes."""
        now = datetime.now()
        expired = [
            code
            for code, pc in self._pairing_codes.items()
            if now > pc.expires_at or pc.used
        ]
        for code in expired:
            del self._pairing_codes[code]

    # ==================== Device Management ====================

    def create_device(self, data: DeviceCreate) -> Device:
        """Create and register a new device."""
        device_id = str(uuid.uuid4())
        device = Device(
            id=device_id,
            fingerprint_hash=self.hash_fingerprint(data.fingerprint),
            name=data.name,
            browser=data.browser,
            os=data.os,
            ip=data.ip,
            location=data.location,
            trust_level=TrustLevel.PARTIAL,  # Default to partial trust
            created_at=datetime.now(),
            last_active=datetime.now(),
        )
        self._devices[device_id] = device
        self._save_devices()
        logger.info(f"Created device: {device_id} ({device.name})")
        return device

    def get_device(self, device_id: str) -> Optional[Device]:
        """Get device by ID."""
        return self._devices.get(device_id)

    def get_device_by_fingerprint(self, fingerprint: str) -> Optional[Device]:
        """Get device by fingerprint hash."""
        fp_hash = self.hash_fingerprint(fingerprint)
        for device in self._devices.values():
            if device.fingerprint_hash == fp_hash and device.is_active:
                return device
        return None

    def list_devices(self) -> list[DeviceInfo]:
        """List all registered devices."""
        return [
            DeviceInfo(
                id=d.id,
                name=d.name,
                browser=d.browser,
                os=d.os,
                ip=d.ip,
                location=d.location,
                trust_level=d.trust_level,
                created_at=d.created_at,
                last_active=d.last_active,
            )
            for d in self._devices.values()
            if d.is_active
        ]

    def update_device_activity(self, device_id: str, ip: str):
        """Update device's last activity timestamp and IP."""
        device = self._devices.get(device_id)
        if device:
            device.last_active = datetime.now()
            device.ip = ip
            self._save_devices()

    def update_device_trust_level(self, device_id: str, trust_level: TrustLevel) -> bool:
        """Update device's trust level."""
        device = self._devices.get(device_id)
        if device:
            device.trust_level = trust_level
            self._save_devices()
            logger.info(f"Updated device {device_id} trust level to {trust_level}")
            return True
        return False

    def revoke_device(self, device_id: str) -> bool:
        """Revoke a device's access."""
        device = self._devices.get(device_id)
        if device:
            device.is_active = False
            device.refresh_token_hash = None
            self._save_devices()
            logger.info(f"Revoked device: {device_id}")
            return True
        return False

    # ==================== Token Management ====================

    def create_access_token(self, device_id: str) -> tuple[str, int]:
        """Create a short-lived access token."""
        expires_delta = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        expire = datetime.utcnow() + expires_delta

        device = self.get_device(device_id)
        if not device:
            raise ValueError("Device not found")

        payload = {
            "sub": device_id,
            "type": "access",
            "trust_level": device.trust_level,
            "exp": expire,
            "iat": datetime.utcnow(),
        }
        token = jwt.encode(payload, self._secret_key, algorithm=ALGORITHM)
        return token, ACCESS_TOKEN_EXPIRE_MINUTES * 60

    def create_refresh_token(self, device_id: str) -> str:
        """Create a long-lived refresh token."""
        expires_delta = timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
        expire = datetime.utcnow() + expires_delta

        # Generate unique token ID
        token_id = secrets.token_urlsafe(16)

        payload = {
            "sub": device_id,
            "type": "refresh",
            "jti": token_id,
            "exp": expire,
            "iat": datetime.utcnow(),
        }
        token = jwt.encode(payload, self._secret_key, algorithm=ALGORITHM)

        # Store token hash in device record
        device = self._devices.get(device_id)
        if device:
            device.refresh_token_hash = hashlib.sha256(token.encode()).hexdigest()
            self._save_devices()

        return token

    def verify_access_token(self, token: str) -> Optional[dict]:
        """Verify an access token and return payload."""
        try:
            payload = jwt.decode(token, self._secret_key, algorithms=[ALGORITHM])
            if payload.get("type") != "access":
                return None
            return payload
        except JWTError as e:
            logger.debug(f"Access token verification failed: {e}")
            return None

    def verify_refresh_token(self, token: str) -> Optional[Device]:
        """Verify a refresh token and return associated device."""
        try:
            payload = jwt.decode(token, self._secret_key, algorithms=[ALGORITHM])
            if payload.get("type") != "refresh":
                return None

            device_id = payload.get("sub")
            device = self.get_device(device_id)

            if not device or not device.is_active:
                return None

            # Verify token hash matches
            token_hash = hashlib.sha256(token.encode()).hexdigest()
            if device.refresh_token_hash != token_hash:
                logger.warning(f"Refresh token hash mismatch for device {device_id}")
                return None

            return device
        except JWTError as e:
            logger.debug(f"Refresh token verification failed: {e}")
            return None

    # ==================== Desktop Approval ====================

    def request_approval(self, approval_id: str, data: dict) -> str:
        """Store a pending approval request for Desktop confirmation."""
        self._pending_approvals[approval_id] = {
            "data": data,
            "created_at": datetime.now(),
            "status": "pending",
        }
        return approval_id

    def get_pending_approval(self, approval_id: str) -> Optional[dict]:
        """Get a pending approval request."""
        return self._pending_approvals.get(approval_id)

    def approve_request(self, approval_id: str) -> bool:
        """Approve a pending request."""
        if approval_id in self._pending_approvals:
            self._pending_approvals[approval_id]["status"] = "approved"
            return True
        return False

    def reject_request(self, approval_id: str) -> bool:
        """Reject a pending request."""
        if approval_id in self._pending_approvals:
            self._pending_approvals[approval_id]["status"] = "rejected"
            return True
        return False

    def cleanup_approvals(self):
        """Clean up old approval requests."""
        now = datetime.now()
        expired = [
            aid
            for aid, data in self._pending_approvals.items()
            if now - data["created_at"] > timedelta(minutes=5)
        ]
        for aid in expired:
            del self._pending_approvals[aid]

    # ==================== Audit Logging ====================

    def log_audit(self, entry: AuditLogCreate):
        """Log an audit entry."""
        log_entry = AuditLog(
            id=str(uuid.uuid4()),
            timestamp=datetime.now(),
            **entry.model_dump(),
        )

        # Write to log file
        try:
            with open(AUDIT_LOG_FILE, "a") as f:
                log_line = (
                    f"[{log_entry.timestamp.isoformat()}] "
                    f"[{log_entry.result.upper()}] "
                    f"device={log_entry.device_name or 'unknown'} "
                    f"ip={log_entry.ip} "
                    f"action={log_entry.action} "
                )
                if log_entry.session_id:
                    log_line += f"session={log_entry.session_id} "
                if log_entry.details:
                    # Truncate long details
                    details_str = str(log_entry.details)
                    if len(details_str) > 100:
                        details_str = details_str[:100] + "..."
                    log_line += f"details={details_str}"
                f.write(log_line.strip() + "\n")
        except Exception as e:
            logger.error(f"Failed to write audit log: {e}")

        return log_entry

    def get_recent_audit_logs(self, limit: int = 100) -> list[str]:
        """Get recent audit log entries."""
        if not AUDIT_LOG_FILE.exists():
            return []

        try:
            with open(AUDIT_LOG_FILE, "r") as f:
                lines = f.readlines()
                return lines[-limit:]
        except Exception as e:
            logger.error(f"Failed to read audit log: {e}")
            return []


# Global auth service instance
auth_service = AuthService()
